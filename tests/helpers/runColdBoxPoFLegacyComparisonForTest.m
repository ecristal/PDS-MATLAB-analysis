function [results, barData] = runColdBoxPoFLegacyComparisonForTest( ...
        repositoryRoot, coefficientPath, outputDirectory)
%RUNCOLDBOXPOFLEGACYCOMPARISONFORTEST Compare PoF configurations.
%   Applies the frozen legacy shaping and Gaussian-fit contract to every
%   available M3/M6 channel. M3 uses the 2 MHz low-pass; M6 does not.

    sampleCount = 1024;
    recordCount = 30000;
    sampleRateHz = 62.5e6;
    pedestalSampleCount = 100;
    quantileLimits = [0.15, 0.85];
    scoreHalfWidth = 1;
    scoreScale = 2;
    fitComponentCount = 6;
    binWidths = 0.02:0.01:0.05;
    lowPassOrder = 3;
    lowPassCutoffHz = 2e6;

    contractId = "coldbox-september2026-pof-shaping-v1";

    cases = buildCases();
    coefficients = loadLegacyCoefficients(coefficientPath);
    [lowPassNumerator, lowPassDenominator] = butter( ...
        lowPassOrder, lowPassCutoffHz / (sampleRateHz / 2), 'low');
    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end

    rows = cell(height(cases), 40);
    fitDiagnostics = cell(height(cases), 1);
    poFRoot = fullfile(repositoryRoot, 'data', 'DAPHNE', 'ColdBox', ...
        'September2026', 'PoF_data');

    for caseIndex = 1:height(cases)
        configuration = cases.Configuration(caseIndex);
        module = cases.Module(caseIndex);
        logicalChannel = cases.LogicalChannel(caseIndex);
        daphneChannel = cases.DaphneChannel(caseIndex);
        moduleDirectory = fullfile(poFRoot, configuration, ...
            'VGAIN_SCAN', "M" + module);
        archivePath = fullfile(moduleDirectory, ...
            "channel_" + daphneChannel + ".7z");
        archiveMember = "channel_" + daphneChannel + ".dat";
        configPath = fullfile(moduleDirectory, 'config.txt');
        acquisition = readAcquisitionConfiguration(configPath, ...
            daphneChannel);
        archiveSha256 = sha256File(archivePath);

        data = readColdBoxArchive(archivePath, archiveMember, ...
            sampleCount, recordCount);
        rmsValues = rms(data, 2);
        rmsLimits = quantile(rmsValues, quantileLimits);
        rmsMask = rmsValues >= rmsLimits(1) & rmsValues <= rmsLimits(2);
        data = data(rmsMask, :);

        pedestal = pds.preprocess.estimatePedestal(data, ...
            SampleIndices=1:pedestalSampleCount, Method="mean");
        pedestalLimits = quantile(pedestal, quantileLimits);
        pedestalMask = pedestal >= pedestalLimits(1) & ...
            pedestal <= pedestalLimits(2);
        data = data(pedestalMask, :);
        pedestal = pedestal(pedestalMask);
        corrected = pds.preprocess.subtractPedestal(data, pedestal);
        clear data;

        applyLowPass = module == 3;
        if applyLowPass
            shaped = filter(lowPassNumerator, lowPassDenominator, ...
                corrected, [], 2);
            configuredCutoffHz = lowPassCutoffHz;
            configuredOrder = lowPassOrder;
        else
            shaped = corrected;
            configuredCutoffHz = 0;
            configuredOrder = 0;
        end
        clear corrected;
        shaped = filter(coefficients.integratorNumerator, ...
            coefficients.integratorDenominator, shaped, [], 2);
        shaped = filter(coefficients.movingMeanNumerator, ...
            coefficients.movingMeanDenominator, shaped, [], 2);

        meanShaped = mean(shaped, 1);
        [normalizationScale, peakIndex] = max(meanShaped);
        if peakIndex <= scoreHalfWidth || ...
                peakIndex > sampleCount - scoreHalfWidth
            error('PDS:test:ColdBoxPoFPeakAtBoundary', ...
                '%s M%d CH%d cannot support the score window.', ...
                configuration, module, logicalChannel);
        end
        scoreIndices = (peakIndex - scoreHalfWidth): ...
            (peakIndex + scoreHalfWidth);
        scores = scoreScale * mean(shaped(:, scoreIndices), 2) / ...
            normalizationScale;
        clear shaped;

        fitResult = fitLegacyHistogram(scores, binWidths, ...
            fitComponentCount);
        globalFitValid = fitResult.completed && ...
            fitResult.delta > 0.5 && fitResult.delta < 1.5 && ...
            fitResult.sigma0 > 0 && fitResult.sigma0 < 0.75 && ...
            fitResult.rSquare > 0.95;
        localFit = fitColdBoxLegacyLocalPeaksForTest( ...
            fitResult.scores, fitResult.normalizedBinWidth);
        if globalFitValid
            fitMethod = "multi-gaussian";
            finalMu0 = fitResult.mu0;
            finalSigma0 = fitResult.sigma0;
            finalMu1 = fitResult.mu1;
            finalSigma1 = fitResult.sigma1;
            finalDelta = fitResult.delta;
            finalSnr = fitResult.snr;
            finalRSquare = fitResult.rSquare;
            fitValid = true;
        elseif localFit.valid
            fitMethod = "local-gaussian";
            finalMu0 = localFit.mu0;
            finalSigma0 = localFit.sigma0;
            finalMu1 = localFit.mu1;
            finalSigma1 = localFit.sigma1;
            finalDelta = localFit.delta;
            finalSnr = localFit.snr;
            finalRSquare = localFit.rSquare;
            fitValid = true;
        else
            fitMethod = "failed";
            finalMu0 = fitResult.mu0;
            finalSigma0 = fitResult.sigma0;
            finalMu1 = fitResult.mu1;
            finalSigma1 = fitResult.sigma1;
            finalDelta = fitResult.delta;
            finalSnr = NaN;
            finalRSquare = fitResult.rSquare;
            fitValid = false;
        end
        if fitValid
            measurementSnr = finalSnr;
            nominalSnr = finalSnr;
        else
            measurementSnr = NaN;
            nominalSnr = fitResult.snr;
        end
        nominalPeStructure = isfinite(nominalSnr) && ...
            isfinite(finalDelta) && finalDelta > 0.5 && finalDelta < 1.5 && ...
            isfinite(finalSigma0) && finalSigma0 > 0 && ...
            finalSigma0 < 0.75 && nominalSnr >= 3;
        if fitValid && finalSnr >= 3
            separationAssessment = "clear";
        elseif nominalPeStructure
            separationAssessment = "fit-failed";
        elseif fitResult.completed
            separationAssessment = "ambiguous";
        else
            separationAssessment = "unresolved";
        end

        baseName = sprintf('%s_M%d_CH%d_channel_%d', ...
            configuration, module, logicalChannel, daphneChannel);
        histogramPath = fullfile(outputDirectory, ...
            baseName + "_histogram.png");
        titleLine = sprintf(['VBIAS=%d - VGAIN %d - ', ...
            'Module M%d CH%d'], acquisition.biasRequested, ...
            acquisition.vgainRequested, module, logicalChannel);
        configurationSuffix = extractAfter(configuration, "PoF_");
        configurationTitle = "PoF_{" + configurationSuffix + "}";
        histogramTitle = "Histogram - COLDBOX SEPT 2026\\n" + ...
            string(titleLine) + "\\n" + configurationTitle;
        finalFit = struct('mu0', finalMu0, 'sigma0', finalSigma0, ...
            'mu1', finalMu1, 'sigma1', finalSigma1, ...
            'delta', finalDelta, 'snr', finalSnr, ...
            'rSquare', finalRSquare);
        createHistogramPlot(fitResult, localFit, finalFit, fitValid, ...
            fitMethod, separationAssessment, histogramPath, titleLine, ...
            configurationTitle);

        fitDiagnostics{caseIndex} = struct( ...
            'globalFit', fitResult, 'localFit', localFit);
        rows(caseIndex, :) = { ...
            configuration, module, logicalChannel, daphneChannel, ...
            acquisition.afe, acquisition.biasRequested, ...
            acquisition.vgainRequested, acquisition.timestampUtc, ...
            contractId, string(archivePath), string(archiveSha256), ...
            recordCount, numel(scores), sampleCount, sampleRateHz, ...
            pedestalSampleCount, "mean", applyLowPass, configuredOrder, ...
            configuredCutoffHz, peakIndex, fitResult.rawBinWidth, ...
            fitResult.normalizationPeak, finalMu0, finalSigma0, ...
            finalMu1, finalSigma1, finalDelta, nominalSnr, ...
            measurementSnr, finalRSquare, fitValid, fitMethod, ...
            fitResult.snr, fitResult.rSquare, localFit.rSquare0, ...
            localFit.rSquare1, separationAssessment, histogramTitle, ...
            string(histogramPath)};
    end

    variableNames = {'Configuration', 'Module', 'LogicalChannel', ...
        'DaphneChannel', 'Afe', 'BiasRequested', 'VgainRequested', ...
        'TimestampUtc', 'ContractId', 'ArchivePath', 'ArchiveSha256', ...
        'RecordCount', 'SelectedCount', 'SampleCount', 'SampleRateHz', ...
        'PedestalSampleCount', 'PedestalMethod', 'LowPassApplied', ...
        'LowPassOrder', 'LowPassCutoffHz', 'PeakIndex', ...
        'SelectedRawBinWidth', 'NormalizationPeak', 'Mu0', 'Sigma0', ...
        'Mu1', 'Sigma1', 'Delta', 'NominalSNR', 'SNR', 'FitRSquare', ...
        'FitValid', 'FitMethod', 'GlobalNominalSNR', ...
        'GlobalFitRSquare', 'LocalFitRSquare0', 'LocalFitRSquare1', ...
        'SeparationAssessment', 'HistogramTitle', ...
        'HistogramPlotPath'};
    results = cell2table(rows, 'VariableNames', variableNames);
    barData = buildBarData(results);
    moduleSummary = buildModuleSummary(barData);

    writetable(results, fullfile(outputDirectory, 'summary.csv'));
    writetable(barData, fullfile(outputDirectory, ...
        'snr_by_configuration.csv'));
    writetable(moduleSummary, fullfile(outputDirectory, ...
        'module_summary.csv'));
    save(fullfile(outputDirectory, 'summary.mat'), 'results', ...
        'barData', 'moduleSummary', 'fitDiagnostics', 'binWidths');
    writeMarkdownSynthesis(results, moduleSummary, ...
        fullfile(outputDirectory, 'summary.md'));
    createBarChart(barData, fullfile(outputDirectory, 'snr_bar_chart.png'));
    createMontage(results.HistogramPlotPath, ...
        fullfile(outputDirectory, 'histograms_montage.png'));
end

function cases = buildCases()
    configuration = [repmat("PoF_OFF", 2, 1); repmat("PoF_OLD", 4, 1); ...
        repmat("PoF_NEW", 4, 1); repmat("PoF_ALL", 4, 1)];
    module = [repmat(3, 2, 1); repelem([3; 6], 2); ...
        repelem([3; 6], 2); repelem([3; 6], 2)];
    logicalChannel = repmat([1; 2], 7, 1);
    daphneChannel = zeros(size(module));
    daphneChannel(module == 3 & logicalChannel == 1) = 8;
    daphneChannel(module == 3 & logicalChannel == 2) = 9;
    daphneChannel(module == 6 & logicalChannel == 1) = 20;
    daphneChannel(module == 6 & logicalChannel == 2) = 21;
    cases = table(configuration, module, logicalChannel, daphneChannel, ...
        'VariableNames', {'Configuration', 'Module', 'LogicalChannel', ...
        'DaphneChannel'});
end

function fitResult = fitLegacyHistogram(scores, binWidths, componentCount)
    trialSnr = NaN(size(binWidths));
    trialCenters = cell(size(binWidths));
    for index = 1:numel(binWidths)
        figureHandle = figure('Visible', 'off');
        cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
        try
            [~, ~, ~, ~, ~, snr, ~, ~, ~, centers] = ...
                gaussian_fit_SNR(scores, binWidths(index), 0.8, -0.5, ...
                -0.25, 4, -0.5, 0.5, 0.3, componentCount, 45);
            if isfinite(snr) && numel(centers) >= 2 && centers(2) ~= 0
                trialSnr(index) = snr;
                trialCenters{index} = centers;
            end
        catch
            % A failed trial cannot be selected.
        end
        clear cleanupFigure;
    end

    validTrials = find(isfinite(trialSnr));
    if isempty(validTrials)
        fitResult = emptyFitResult(scores, binWidths(1));
        return;
    end
    [~, relativeBestIndex] = max(trialSnr(validTrials));
    bestIndex = validTrials(relativeBestIndex);
    selectedCenters = trialCenters{bestIndex};
    normalizationPeak = selectedCenters(2);
    normalizedScores = scores / normalizationPeak;
    normalizedBinWidth = binWidths(bestIndex) / normalizationPeak;

    figureHandle = figure('Visible', 'off');
    cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
    try
        [mu0, sigma0, mu1, sigma1, delta, snr, evaluationAxis, ...
            fittedCurve, rSquare, finalCenters] = gaussian_fit_SNR( ...
            normalizedScores, normalizedBinWidth, ...
            0.8 / normalizationPeak, -0.5, ...
            -0.25 / normalizationPeak, 4 / normalizationPeak, ...
            -0.5, 0.5, 0.3, componentCount, 45);
        completed = all(isfinite([mu0, sigma0, mu1, sigma1, delta, ...
            snr, rSquare]));
    catch
        mu0 = NaN;
        sigma0 = NaN;
        mu1 = NaN;
        sigma1 = NaN;
        delta = NaN;
        snr = NaN;
        rSquare = NaN;
        evaluationAxis = [];
        fittedCurve = [];
        finalCenters = [];
        completed = false;
    end
    clear cleanupFigure;

    fitResult = struct( ...
        'completed', completed, 'scores', normalizedScores, ...
        'rawBinWidth', binWidths(bestIndex), ...
        'normalizedBinWidth', normalizedBinWidth, ...
        'normalizationPeak', normalizationPeak, 'mu0', mu0, ...
        'sigma0', sigma0, 'mu1', mu1, 'sigma1', sigma1, ...
        'delta', delta, 'snr', snr, 'rSquare', rSquare, ...
        'evaluationAxis', evaluationAxis, 'fittedCurve', fittedCurve, ...
        'finalCenters', finalCenters, 'trialSnr', trialSnr, ...
        'trialCenters', {trialCenters});
end

function result = emptyFitResult(scores, binWidth)
    result = struct( ...
        'completed', false, 'scores', scores, 'rawBinWidth', binWidth, ...
        'normalizedBinWidth', binWidth, 'normalizationPeak', NaN, ...
        'mu0', NaN, 'sigma0', NaN, 'mu1', NaN, 'sigma1', NaN, ...
        'delta', NaN, 'snr', NaN, 'rSquare', NaN, ...
        'evaluationAxis', [], 'fittedCurve', [], 'finalCenters', [], ...
        'trialSnr', NaN, 'trialCenters', {{}});
end

function createHistogramPlot(fitResult, localFit, finalFit, fitValid, ...
        fitMethod, assessment, outputPath, titleLine, configurationTitle)
    figureHandle = figure('Visible', 'off', ...
        'Position', [100, 100, 1100, 700]);
    cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
    histogram(fitResult.scores, 'BinWidth', fitResult.normalizedBinWidth, ...
        'DisplayStyle', 'stairs', 'LineWidth', 2, ...
        'EdgeColor', [0, 0.4470, 0.7410]);
    hold on;
    if fitResult.completed
        if fitMethod == "multi-gaussian"
            plot(fitResult.evaluationAxis, fitResult.fittedCurve, ...
                'r', 'LineWidth', 1.25);
        else
            plot(fitResult.evaluationAxis, fitResult.fittedCurve, ...
                'Color', [0.85, 0.45, 0.45], 'LineStyle', '--', ...
                'LineWidth', 1);
        end
    end
    if fitMethod == "local-gaussian"
        plot(localFit.pedestalX, localFit.pedestalCurve, ...
            'g', 'LineWidth', 1.8);
        plot(localFit.firstPeX, localFit.firstPeCurve, ...
            'm', 'LineWidth', 1.8);
    end
    if fitValid
        xline(finalFit.mu0, 'r--');
        xline(finalFit.mu0 - finalFit.sigma0, 'b--');
        xline(finalFit.mu0 + finalFit.sigma0, 'b--');
        xline(finalFit.mu1, 'r--');
    end
    grid on;
    xlabel('Normalized amplitude [PE]');
    ylabel('Entries');
    title({'{\bf Histogram - COLDBOX SEPT 2026}', titleLine, ...
        char(configurationTitle)}, 'Interpreter', 'tex');
    xlim([-0.5, 4.5]);
    if fitValid
        annotationText = sprintf(['\\Delta = %.4f\n\\sigma_0 = %.5f\n', ...
            'SNR = %.4f\nR^2 = %.4f\n%s\n%s'], finalFit.delta, ...
            finalFit.sigma0, finalFit.snr, finalFit.rSquare, assessment, ...
            fitMethod);
    elseif fitResult.completed
        annotationText = sprintf(['FIT NO VALIDO\nSNR nominal = %.4f\n', ...
            'R^2 = %.4f\n%s'], fitResult.snr, fitResult.rSquare, assessment);
    else
        annotationText = sprintf('FIT NO DISPONIBLE\n%s', assessment);
    end
    annotation('textbox', [0.67, 0.63, 0.2, 0.24], ...
        'Interpreter', 'tex', 'String', annotationText, ...
        'FitBoxToText', 'on');
    overwriteExport(figureHandle, outputPath);
end

function barData = buildBarData(results)
    configurations = ["PoF_OFF"; "PoF_OLD"; "PoF_NEW"; "PoF_ALL"];
    modules = [3; 3; 6; 6];
    logicalChannels = [1; 2; 1; 2];
    daphneChannels = [8; 9; 20; 21];
    rowCount = numel(configurations) * numel(modules);
    configurationColumn = strings(rowCount, 1);
    moduleColumn = zeros(rowCount, 1);
    logicalColumn = zeros(rowCount, 1);
    daphneColumn = zeros(rowCount, 1);
    dataAvailable = false(rowCount, 1);
    fitValid = false(rowCount, 1);
    snr = NaN(rowCount, 1);
    nominalSnr = NaN(rowCount, 1);
    row = 0;
    for configIndex = 1:numel(configurations)
        for seriesIndex = 1:numel(modules)
            row = row + 1;
            configurationColumn(row) = configurations(configIndex);
            moduleColumn(row) = modules(seriesIndex);
            logicalColumn(row) = logicalChannels(seriesIndex);
            daphneColumn(row) = daphneChannels(seriesIndex);
            match = results.Configuration == configurations(configIndex) & ...
                results.Module == modules(seriesIndex) & ...
                results.LogicalChannel == logicalChannels(seriesIndex);
            if any(match)
                dataAvailable(row) = true;
                fitValid(row) = results.FitValid(match);
                snr(row) = results.SNR(match);
                nominalSnr(row) = results.NominalSNR(match);
            end
        end
    end
    barData = table(configurationColumn, moduleColumn, logicalColumn, ...
        daphneColumn, dataAvailable, fitValid, snr, nominalSnr, ...
        'VariableNames', {'Configuration', 'Module', 'LogicalChannel', ...
        'DaphneChannel', 'DataAvailable', 'FitValid', 'SNR', 'NominalSNR'});
end

function moduleSummary = buildModuleSummary(barData)
    configurations = ["PoF_OFF"; "PoF_OLD"; "PoF_NEW"; "PoF_ALL"];
    modules = [3; 6];
    rowCount = numel(configurations) * numel(modules);
    rows = cell(rowCount, 10);
    row = 0;
    for configIndex = 1:numel(configurations)
        for moduleIndex = 1:numel(modules)
            row = row + 1;
            configuration = configurations(configIndex);
            module = modules(moduleIndex);
            selected = barData.Configuration == configuration & ...
                barData.Module == module;
            availableCount = sum(barData.DataAvailable(selected));
            validValues = barData.SNR(selected & barData.FitValid);
            validValues = validValues(isfinite(validValues));
            if isempty(validValues)
                meanSnr = NaN;
                minimumSnr = NaN;
                maximumSnr = NaN;
            else
                meanSnr = mean(validValues);
                minimumSnr = min(validValues);
                maximumSnr = max(validValues);
            end
            if module == 3
                referenceConfiguration = "PoF_OFF";
            else
                referenceConfiguration = "PoF_OLD";
            end
            referenceRows = barData.Configuration == referenceConfiguration & ...
                barData.Module == module & barData.FitValid;
            referenceValues = barData.SNR(referenceRows);
            referenceValues = referenceValues(isfinite(referenceValues));
            if isempty(referenceValues) || ~isfinite(meanSnr)
                delta = NaN;
                relativePercent = NaN;
            else
                referenceMean = mean(referenceValues);
                delta = meanSnr - referenceMean;
                relativePercent = 100 * delta / referenceMean;
            end
            rows(row, :) = {configuration, module, availableCount, ...
                numel(validValues), meanSnr, minimumSnr, maximumSnr, ...
                referenceConfiguration, delta, relativePercent};
        end
    end
    moduleSummary = cell2table(rows, 'VariableNames', ...
        {'Configuration', 'Module', 'AvailableChannelCount', ...
        'ValidFitCount', 'MeanSNR', 'MinimumSNR', 'MaximumSNR', ...
        'ReferenceConfiguration', 'DeltaFromReference', ...
        'RelativeChangePercent'});
end

function createBarChart(barData, outputPath)
    configurations = ["PoF_OFF", "PoF_OLD", "PoF_NEW", "PoF_ALL"];
    matrix = NaN(4, 4);
    for configIndex = 1:4
        selected = barData.Configuration == configurations(configIndex);
        matrix(configIndex, :) = barData.SNR(selected).';
    end
    figureHandle = figure('Visible', 'off', ...
        'Position', [100, 100, 1300, 760]);
    cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
    barHandles = bar(matrix, 'grouped');
    colors = lines(4);
    for seriesIndex = 1:4
        barHandles(seriesIndex).FaceColor = colors(seriesIndex, :);
        x = barHandles(seriesIndex).XEndPoints;
        y = barHandles(seriesIndex).YEndPoints;
        finiteMask = isfinite(y);
        text(x(finiteMask), y(finiteMask), ...
            compose('%.3f', y(finiteMask)), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
    grid on;
    xticks(1:4);
    xticklabels({'$\mathrm{PoF}_{\mathrm{OFF}}$', ...
        '$\mathrm{PoF}_{\mathrm{OLD}}$', ...
        '$\mathrm{PoF}_{\mathrm{NEW}}$', ...
        '$\mathrm{PoF}_{\mathrm{ALL}}$'});
    set(gca, 'TickLabelInterpreter', 'latex');
    ylabel('$\mathrm{SNR}=(\mu_1-\mu_0)/\sigma_0$', ...
        'Interpreter', 'latex');
    xlabel('PoF configuration');
    title({'{\bf SNR by PoF Configuration - COLDBOX SEPT 2026}', ...
        'M3 and M6 channel comparison; unavailable data are omitted'}, ...
        'Interpreter', 'tex');
    legend({'M3 CH1', 'M3 CH2', 'M6 CH1', 'M6 CH2'}, ...
        'Location', 'bestoutside');
    finiteValues = matrix(isfinite(matrix));
    if ~isempty(finiteValues)
        ylim([0, 1.18 * max(finiteValues)]);
    end
    annotation('textbox', [0.14, 0.76, 0.28, 0.09], ...
        'String', '$\mathrm{PoF}_{\mathrm{OFF}}$: M6 data unavailable', ...
        'Interpreter', 'latex', 'FitBoxToText', 'on', ...
        'BackgroundColor', 'white');
    overwriteExport(figureHandle, outputPath);
end

function createMontage(paths, outputPath)
    figureHandle = figure('Visible', 'off', ...
        'Position', [100, 100, 1800, 2450]);
    cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
    layout = tiledlayout(7, 2, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    for index = 1:numel(paths)
        nexttile(layout);
        image(imread(paths(index)));
        axis image off;
    end
    title(layout, 'PoF Fits - COLDBOX SEPT 2026', ...
        'FontWeight', 'bold');
    overwriteExport(figureHandle, outputPath);
end

function writeMarkdownSynthesis(results, moduleSummary, outputPath)
    fileIdentifier = fopen(outputPath, 'w');
    if fileIdentifier < 0
        error('PDS:test:ColdBoxPoFSummaryOpenFailed', ...
            'Unable to create %s.', outputPath);
    end
    cleanupFile = onCleanup(@() fclose(fileIdentifier));
    fprintf(fileIdentifier, '# ColdBox September 2026: PoF comparison\n\n');
    fprintf(fileIdentifier, ['Status: exploratory acquisition-specific ', ...
        'comparison. SNR = (mu1-mu0)/sigma0.\n\n']);
    fprintf(fileIdentifier, ['The fixed shaping contract uses samples 1:100 ', ...
        'for the mean pedestal and 15--85%% cuts. The 2 MHz low-pass is ', ...
        'applied to M3 only; M6 uses no low-pass. PoF_OFF contains M3 ', ...
        'only, so its M6 bars are missing rather than zero.\n\n']);
    fprintf(fileIdentifier, ['| Configuration | Module | CH | DAPHNE | ', ...
        'Selected | SNR | Fit method | Global nominal SNR | R^2 | ', ...
        'Status |\n']);
    fprintf(fileIdentifier, ...
        '|---|---:|---:|---:|---:|---:|---|---:|---:|---|\n');
    for index = 1:height(results)
        fprintf(fileIdentifier, ...
            '| %s | M%d | %d | %d | %d | %s | %s | %.6f | %.6f | %s |\n', ...
            results.Configuration(index), results.Module(index), ...
            results.LogicalChannel(index), results.DaphneChannel(index), ...
            results.SelectedCount(index), formatMetric(results.SNR(index)), ...
            results.FitMethod(index), results.GlobalNominalSNR(index), ...
            results.FitRSquare(index), ...
            results.SeparationAssessment(index));
    end
    fprintf(fileIdentifier, '\n## Module means from valid channel fits\n\n');
    fprintf(fileIdentifier, ['| Configuration | Module | Valid/available | ', ...
        'Mean SNR | Delta from reference | Relative change |\n']);
    fprintf(fileIdentifier, '|---|---:|---:|---:|---:|---:|\n');
    for index = 1:height(moduleSummary)
        fprintf(fileIdentifier, ...
            '| %s | M%d | %d/%d | %s | %s | %s |\n', ...
            moduleSummary.Configuration(index), moduleSummary.Module(index), ...
            moduleSummary.ValidFitCount(index), ...
            moduleSummary.AvailableChannelCount(index), ...
            formatMetric(moduleSummary.MeanSNR(index)), ...
            formatMetric(moduleSummary.DeltaFromReference(index)), ...
            formatPercent(moduleSummary.RelativeChangePercent(index)));
    end
    fprintf(fileIdentifier, '\nNotes:\n\n');
    fprintf(fileIdentifier, '- Valid fits: %d/%d available channel cases.\n', ...
        sum(results.FitValid), height(results));
    fprintf(fileIdentifier, ['- Multi-Gaussian fits: %d/%d; common local ', ...
        '0-PE/1-PE fallbacks: %d/%d.\n'], ...
        sum(results.FitMethod == "multi-gaussian"), height(results), ...
        sum(results.FitMethod == "local-gaussian"), height(results));
    if any(~results.FitValid)
        fprintf(fileIdentifier, ['- Invalid fits carry NaN in SNR; attempted ', ...
            'values remain only in NominalSNR.\n']);
    end
    fprintf(fileIdentifier, ['- Module means are descriptive point ', ...
        'estimates. No repeated acquisitions or uncertainty model are ', ...
        'available, so differences are not significance claims.\n']);
end

function acquisition = readAcquisitionConfiguration(configPath, channel)
    text = fileread(configPath);
    configuredChannels = sscanf(extractValue(text, 'channels'), '%d').';
    if ~ismember(channel, configuredChannels)
        error('PDS:test:ColdBoxPoFChannelMismatch', ...
            'Channel %d is not declared in %s.', channel, configPath);
    end
    acquisition = struct( ...
        'timestampUtc', string(extractValue(text, 'timestamp_utc')), ...
        'afe', str2double(extractValue(text, 'afe')), ...
        'biasRequested', str2double(extractValue(text, 'bias_requested')), ...
        'vgainRequested', str2double(extractValue(text, 'vgain_requested')));
    values = [acquisition.afe, acquisition.biasRequested, ...
        acquisition.vgainRequested];
    if any(~isfinite(values))
        error('PDS:test:ColdBoxPoFInvalidConfiguration', ...
            'Invalid numeric configuration fields: %s.', configPath);
    end
end

function value = extractValue(text, key)
    token = regexp(text, ['(?m)^', regexptranslate('escape', key), ...
        '=([^\r\n]+)$'], 'tokens', 'once');
    if isempty(token)
        error('PDS:test:ColdBoxPoFMissingConfigurationKey', ...
            'Missing configuration key: %s.', key);
    end
    value = strtrim(token{1});
end

function coefficients = loadLegacyCoefficients(path)
    required = {'numz_planta_integrator', 'denz_planta_integrator', ...
        'numz_planta_movmean_hpk', 'denz_planta_movmean_hpk'};
    contents = load(path, required{:});
    for index = 1:numel(required)
        name = required{index};
        if ~isfield(contents, name) || ~isnumeric(contents.(name)) || ...
                ~isvector(contents.(name)) || any(~isfinite(contents.(name)))
            error('PDS:test:InvalidLegacyFilterCoefficients', ...
                'Invalid or missing coefficient vector: %s.', name);
        end
    end
    coefficients = struct( ...
        'integratorNumerator', contents.numz_planta_integrator, ...
        'integratorDenominator', contents.denz_planta_integrator, ...
        'movingMeanNumerator', contents.numz_planta_movmean_hpk, ...
        'movingMeanDenominator', contents.denz_planta_movmean_hpk);
end

function data = readColdBoxArchive(archivePath, expectedMember, ...
        sampleCount, expectedRecordCount)
    sevenZipPath = 'C:\Program Files\7-Zip\7z.exe';
    if ~isfile(sevenZipPath)
        error('PDS:test:SevenZipMissing', ...
            '7-Zip executable not found: %s', sevenZipPath);
    end
    extractionDirectory = tempname;
    mkdir(extractionDirectory);
    cleanupDirectory = onCleanup(@() removeDirectory(extractionDirectory));
    listCommand = sprintf('"%s" l -slt "%s"', sevenZipPath, archivePath);
    [listStatus, listing] = system(listCommand);
    if listStatus ~= 0
        error('PDS:test:ColdBoxPoFArchiveListFailed', ...
            '7-Zip could not list %s: %s', archivePath, listing);
    end
    pathTokens = regexp(listing, '(?m)^Path = ([^\r\n]+)', 'tokens');
    listedPaths = string(cellfun(@(token) strtrim(token{1}), ...
        pathTokens, 'UniformOutput', false));
    if numel(listedPaths) ~= 2 || listedPaths(2) ~= expectedMember
        error('PDS:test:UnexpectedColdBoxPoFArchiveContents', ...
            'Archive %s must contain only %s.', archivePath, expectedMember);
    end
    expectedByteCount = expectedRecordCount * sampleCount * 2;
    sizeTokens = regexp(listing, '(?m)^Size = (\d+)', 'tokens');
    if numel(sizeTokens) ~= 1 || str2double(sizeTokens{1}{1}) ~= expectedByteCount
        error('PDS:test:UnexpectedColdBoxPoFArchiveSize', ...
            'Archive member %s must contain %d bytes.', ...
            expectedMember, expectedByteCount);
    end
    extractCommand = sprintf('"%s" x -y -o"%s" "%s"', ...
        sevenZipPath, extractionDirectory, archivePath);
    [extractStatus, message] = system(extractCommand);
    if extractStatus ~= 0
        error('PDS:test:ColdBoxPoFExtractionFailed', ...
            '7-Zip failed with status %d: %s', extractStatus, message);
    end
    dataPath = fullfile(extractionDirectory, expectedMember);
    fileIdentifier = fopen(dataPath, 'r', 'ieee-le');
    if fileIdentifier < 0
        error('PDS:test:ColdBoxPoFDataOpenFailed', ...
            'Unable to open extracted data: %s', dataPath);
    end
    cleanupFile = onCleanup(@() fclose(fileIdentifier));
    rawSamples = fread(fileIdentifier, Inf, 'uint16=>double');
    clear cleanupFile;
    if numel(rawSamples) ~= expectedByteCount / 2
        error('PDS:test:UnexpectedColdBoxPoFDataSize', ...
            'Extracted member %s has an unexpected sample count.', ...
            expectedMember);
    end
    data = reshape(rawSamples, sampleCount, []).';
end

function digest = sha256File(filePath)
    fileIdentifier = fopen(filePath, 'rb');
    if fileIdentifier < 0
        error('PDS:test:ColdBoxPoFHashOpenFailed', ...
            'Unable to hash %s.', filePath);
    end
    cleanupFile = onCleanup(@() fclose(fileIdentifier));
    bytes = fread(fileIdentifier, Inf, '*uint8');
    engine = java.security.MessageDigest.getInstance('SHA-256');
    engine.update(bytes);
    digestBytes = typecast(engine.digest(), 'uint8');
    digest = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
end

function text = formatMetric(value)
    if isnan(value)
        text = "NaN";
    else
        text = string(sprintf('%.6f', value));
    end
end

function text = formatPercent(value)
    if isnan(value)
        text = "NaN";
    else
        text = string(sprintf('%+.2f%%', value));
    end
end

function overwriteExport(figureHandle, outputPath)
    if isfile(outputPath)
        delete(outputPath);
    end
    exportgraphics(figureHandle, outputPath, 'Resolution', 180);
end

function closeIfValid(figureHandle)
    if isgraphics(figureHandle)
        close(figureHandle);
    end
end

function removeDirectory(directory)
    if isfolder(directory)
        rmdir(directory, 's');
    end
end
