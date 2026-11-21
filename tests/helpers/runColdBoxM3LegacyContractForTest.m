function result = runColdBoxM3LegacyContractForTest( ...
        coefficientPath, outputDirectory, configuration)
%RUNCOLDBOXM3LEGACYCONTRACTFORTEST Apply one fixed ColdBox M3 contract.
%   The same event cuts, samples 1:100 pedestal, shaping chain, score,
%   normalization, histogram-bin sweep, and Gaussian fit are used for every
%   configured acquisition.

    validateConfiguration(configuration);
    contractId = "coldbox-m3-legacy-shaping-v1";
    sampleCount = 1024;
    expectedRecordCount = 30000;
    pedestalSampleCount = 100;
    sampleRateHz = 62.5e6;
    quantileLimits = [0.15, 0.85];
    lowPassOrder = 3;
    lowPassCutoffHz = 2e6;
    scoreHalfWidth = 1;
    scoreScale = 2;
    fitComponentCount = 6;
    binWidths = 0.02:0.01:0.05;

    data = readColdBoxArchive(configuration.ArchivePath, ...
        configuration.ArchiveMember, sampleCount, expectedRecordCount);
    coefficients = loadLegacyCoefficients(coefficientPath);

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

    [lowPassNumerator, lowPassDenominator] = butter( ...
        lowPassOrder, lowPassCutoffHz / (sampleRateHz / 2), 'low');
    filtered = filter(lowPassNumerator, lowPassDenominator, ...
        corrected, [], 2);
    clear corrected;
    filtered = filter(coefficients.integratorNumerator, ...
        coefficients.integratorDenominator, filtered, [], 2);
    filtered = filter(coefficients.movingMeanNumerator, ...
        coefficients.movingMeanDenominator, filtered, [], 2);

    meanFiltered = mean(filtered, 1);
    [normalizationScale, peakIndex] = max(meanFiltered);
    if peakIndex <= scoreHalfWidth || ...
            peakIndex > sampleCount - scoreHalfWidth
        error('PDS:test:ColdBoxPeakAtBoundary', ...
            'The filtered mean peak cannot support the score window.');
    end
    scoreIndices = (peakIndex - scoreHalfWidth): ...
        (peakIndex + scoreHalfWidth);
    scores = scoreScale * mean(filtered(:, scoreIndices), 2) / ...
        normalizationScale;
    clear filtered;

    trialSnr = zeros(size(binWidths));
    trialCenters = cell(size(binWidths));
    for trialIndex = 1:numel(binWidths)
        figureHandle = figure('Visible', 'off');
        cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
        [~, ~, ~, ~, ~, trialSnr(trialIndex), ~, ~, ~, ...
            trialCenters{trialIndex}] = gaussian_fit_SNR( ...
            scores, binWidths(trialIndex), 0.8, -0.5, ...
            -0.25, 4, -0.5, 0.5, 0.3, fitComponentCount, 45);
        clear cleanupFigure;
    end

    [~, bestIndex] = max(trialSnr);
    selectedCenters = trialCenters{bestIndex};
    if numel(selectedCenters) < 2 || selectedCenters(2) == 0
        error('PDS:test:ColdBoxPeakNormalization', ...
            'At least two nonzero histogram peaks are required.');
    end
    normalizationPeak = selectedCenters(2);
    normalizedScores = scores / normalizationPeak;
    normalizedBinWidth = binWidths(bestIndex) / normalizationPeak;

    figureHandle = figure('Visible', 'off');
    cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
    [mu0, sigma0, mu1, sigma1, delta, snr, evaluationAxis, ...
        fittedCurve, fitRSquare, finalCenters] = gaussian_fit_SNR( ...
        normalizedScores, normalizedBinWidth, 0.8 / normalizationPeak, ...
        -0.5, -0.25 / normalizationPeak, 4 / normalizationPeak, ...
        -0.5, 0.5, 0.3, fitComponentCount, 45);
    clear cleanupFigure;

    figureHandle = figure('Visible', 'off', ...
        'Position', [100, 100, 1100, 700]);
    cleanupFigure = onCleanup(@() closeIfValid(figureHandle));
    histogram(normalizedScores, 'BinWidth', normalizedBinWidth, ...
        'DisplayStyle', 'stairs', 'LineWidth', 2, ...
        'EdgeColor', [0, 0.4470, 0.7410]);
    hold on;
    plot(evaluationAxis, fittedCurve, 'r', 'LineWidth', 1.25);
    xline(mu0, 'r--');
    xline(mu0 - sigma0, 'b--');
    xline(mu0 + sigma0, 'b--');
    xline(mu1, 'r--');
    grid on;
    xlabel('ADU');
    ylabel('Entries');
    title(configuration.PlotTitle);
    annotation('textbox', [0.67, 0.68, 0.18, 0.15], ...
        'Interpreter', 'tex', 'String', sprintf( ...
        '\\Delta = %.4f\n\\sigma_0 = %.5f\nSNR = %.4f', ...
        delta, sigma0, snr), 'FitBoxToText', 'on');
    xlim([-0.5, 4.5]);

    if ~isfolder(outputDirectory)
        mkdir(outputDirectory);
    end
    plotPath = fullfile(outputDirectory, configuration.PlotFileName);
    if isfile(plotPath)
        delete(plotPath);
    end
    exportgraphics(figureHandle, plotPath, 'Resolution', 180);

    fitValid = all(isfinite([mu0, sigma0, mu1, sigma1, delta, snr, ...
        fitRSquare])) && delta > 0.5 && delta < 1.5 && sigma0 > 0 && ...
        sigma0 < 0.75 && fitRSquare > 0.95;
    meetsSnr5 = fitValid && snr > 5;
    result = table( ...
        string(configuration.Case), configuration.Channel, contractId, ...
        expectedRecordCount, size(scores, 1), sampleCount, sampleRateHz, ...
        pedestalSampleCount, "mean", quantileLimits(1), quantileLimits(2), ...
        lowPassOrder, lowPassCutoffHz, scoreHalfWidth, scoreScale, ...
        fitComponentCount, rmsLimits(1), rmsLimits(2), ...
        pedestalLimits(1), pedestalLimits(2), peakIndex, ...
        binWidths(bestIndex), normalizationPeak, mu0, sigma0, mu1, ...
        sigma1, delta, snr, fitRSquare, fitValid, meetsSnr5, ...
        string(configuration.ReferencePlotPath), string(coefficientPath), ...
        string(plotPath), ...
        'VariableNames', {'Case', 'Channel', 'ContractId', 'RecordCount', ...
        'SelectedCount', 'SampleCount', 'SampleRateHz', ...
        'PedestalSampleCount', 'PedestalMethod', 'QuantileLower', ...
        'QuantileUpper', 'LowPassOrder', 'LowPassCutoffHz', ...
        'ScoreHalfWidth', 'ScoreScale', 'FitComponentCount', ...
        'RmsLowerQuantile', 'RmsUpperQuantile', ...
        'PedestalLowerQuantile', 'PedestalUpperQuantile', 'PeakIndex', ...
        'SelectedRawBinWidth', 'NormalizationPeak', 'Mu0', 'Sigma0', ...
        'Mu1', 'Sigma1', 'Delta', 'SNR', 'FitRSquare', 'FitValid', ...
        'MeetsSNR5', 'ReferencePlotPath', 'CoefficientPath', 'PlotPath'});

    writetable(result, fullfile(outputDirectory, 'summary.csv'));
    save(fullfile(outputDirectory, 'summary.mat'), 'result', 'binWidths', ...
        'trialSnr', 'trialCenters', 'finalCenters', 'normalizationScale');
    writeMarkdownSummary(result, fullfile(outputDirectory, 'summary.md'));
end

function validateConfiguration(configuration)
    required = {'Case', 'Channel', 'ArchivePath', 'ArchiveMember', ...
        'ReferencePlotPath', 'PlotFileName', 'PlotTitle'};
    if ~isstruct(configuration) || ~isscalar(configuration) || ...
            ~all(isfield(configuration, required))
        error('PDS:test:InvalidColdBoxConfiguration', ...
            'The ColdBox configuration is incomplete.');
    end
    if ~isfile(configuration.ArchivePath)
        error('PDS:test:ColdBoxArchiveMissing', ...
            'ColdBox archive not found: %s', configuration.ArchivePath);
    end
end

function coefficients = loadLegacyCoefficients(path)
    required = {'numz_planta_integrator', 'denz_planta_integrator', ...
        'numz_planta_movmean_hpk', 'denz_planta_movmean_hpk'};
    contents = load(path, required{:});
    for fieldIndex = 1:numel(required)
        fieldName = required{fieldIndex};
        if ~isfield(contents, fieldName) || ...
                ~isnumeric(contents.(fieldName)) || ...
                ~isvector(contents.(fieldName)) || ...
                any(~isfinite(contents.(fieldName)))
            error('PDS:test:InvalidLegacyFilterCoefficients', ...
                'Invalid or missing coefficient vector: %s.', fieldName);
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
        error('PDS:test:ColdBoxArchiveListFailed', ...
            '7-Zip could not list %s (status %d): %s', ...
            archivePath, listStatus, listing);
    end
    pathTokens = regexp(listing, '(?m)^Path = ([^\r\n]+)', 'tokens');
    listedPaths = string(cellfun(@(token) strtrim(token{1}), ...
        pathTokens, 'UniformOutput', false));
    if numel(listedPaths) ~= 2 || listedPaths(2) ~= expectedMember
        error('PDS:test:UnexpectedColdBoxArchiveContents', ...
            'Archive %s must contain only %s.', archivePath, expectedMember);
    end

    expectedByteCount = expectedRecordCount * sampleCount * 2;
    sizeTokens = regexp(listing, '(?m)^Size = (\d+)', 'tokens');
    if numel(sizeTokens) ~= 1 || str2double(sizeTokens{1}{1}) ~= expectedByteCount
        error('PDS:test:UnexpectedColdBoxArchiveSize', ...
            'Archive member %s must contain %d bytes.', ...
            expectedMember, expectedByteCount);
    end

    extractCommand = sprintf('"%s" x -y -o"%s" "%s"', ...
        sevenZipPath, extractionDirectory, archivePath);
    [extractStatus, message] = system(extractCommand);
    if extractStatus ~= 0
        error('PDS:test:ColdBoxExtractionFailed', ...
            '7-Zip failed with status %d: %s', extractStatus, message);
    end

    dataPath = fullfile(extractionDirectory, expectedMember);
    dataFile = dir(dataPath);
    if isempty(dataFile) || dataFile.bytes ~= expectedByteCount
        error('PDS:test:UnexpectedColdBoxDataSize', ...
            'Extracted member %s does not contain %d bytes.', ...
            expectedMember, expectedByteCount);
    end
    fileIdentifier = fopen(dataPath, 'r', 'ieee-le');
    if fileIdentifier < 0
        error('PDS:test:ColdBoxDataOpenFailed', ...
            'Unable to open extracted data: %s', dataPath);
    end
    cleanupFile = onCleanup(@() fclose(fileIdentifier));
    rawSamples = fread(fileIdentifier, Inf, 'uint16=>double');
    clear cleanupFile;

    data = reshape(rawSamples, sampleCount, []).';
    if size(data, 1) ~= expectedRecordCount
        error('PDS:test:UnexpectedColdBoxRecordCount', ...
            'Expected %d records, found %d.', ...
            expectedRecordCount, size(data, 1));
    end
end

function writeMarkdownSummary(result, outputPath)
    fileIdentifier = fopen(outputPath, 'w');
    if fileIdentifier < 0
        error('PDS:test:SummaryOpenFailed', ...
            'Unable to create summary: %s', outputPath);
    end
    cleanupFile = onCleanup(@() fclose(fileIdentifier));
    fprintf(fileIdentifier, '# ColdBox M3 %s legacy contract\n\n', result.Case);
    fprintf(fileIdentifier, ['Contract: `%s`. Pedestal: mean of samples ', ...
        '1:100. Identical 15--85%% RMS and pedestal cuts, shaping, ', ...
        'score extraction, normalization, and Gaussian fit.\n\n'], ...
        result.ContractId);
    fprintf(fileIdentifier, ['| Selected events | Delta | Sigma0 | SNR | ', ...
        'R^2 | Fit valid | SNR > 5 |\n']);
    fprintf(fileIdentifier, '|---:|---:|---:|---:|---:|:---:|:---:|\n');
    fprintf(fileIdentifier, ...
        '| %d | %.6f | %.6f | %.6f | %.6f | %d | %d |\n\n', ...
        result.SelectedCount, result.Delta, result.Sigma0, result.SNR, ...
        result.FitRSquare, result.FitValid, result.MeetsSNR5);
    fprintf(fileIdentifier, ['The measurement is acquisition- and ', ...
        'configuration-specific.\n']);
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
