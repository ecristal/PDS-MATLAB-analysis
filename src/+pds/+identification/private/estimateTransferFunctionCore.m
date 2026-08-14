function [model, diagnostics] = estimateTransferFunctionCore( ...
        inputSignal, outputSignal, domain, apiName, options)
%ESTIMATETRANSFERFUNCTIONCORE Shared bounded SISO identification engine.

    [inputSignal, outputSignal] = validateSignals( ...
        inputSignal, outputSignal, apiName);
    sampleTime = validatePositiveScalar(options.SampleTime, ...
        identifier(apiName, 'InvalidSampleTime'), 'SampleTime');
    maxOrder = validatePositiveInteger(options.MaxOrder, ...
        identifier(apiName, 'InvalidMaxOrder'), 'MaxOrder');
    [trainingSampleCount, trainingIndices, validationIndices, ...
        validationMode] = validateTrainingSampleCount( ...
        options.TrainingSampleCount, numel(inputSignal), apiName);
    if maxOrder >= trainingSampleCount
        error(identifier(apiName, 'InvalidMaxOrder'), ...
            'MaxOrder must be smaller than TrainingSampleCount.');
    end
    delayRange = validateDelayRange( ...
        options.DelayRange, numel(inputSignal), apiName);
    fitTolerance = validateNonnegativeScalar(options.FitTolerance, ...
        identifier(apiName, 'InvalidFitTolerance'), 'FitTolerance');
    selectionCriterion = lower(string(options.SelectionCriterion));
    supportedCriteria = ["parsimonious-fit", "best-fit", "bic", "aicc"];
    if ~isscalar(selectionCriterion) || ...
            ~any(selectionCriterion == supportedCriteria)
        error(identifier(apiName, 'UnknownSelectionCriterion'), ...
            'SelectionCriterion must be parsimonious-fit, best-fit, bic, or aicc.');
    end

    candidateCount = maxOrder * numel(delayRange);
    callerRngState = rng;
    rngCleanup = onCleanup(@() rng(callerRngState));
    rng(0, 'twister');
    poleOrder = zeros(candidateCount, 1);
    zeroOrder = zeros(candidateCount, 1);
    delaySamples = zeros(candidateCount, 1);
    fitPercent = NaN(candidateCount, 1);
    rmse = NaN(candidateCount, 1);
    nrmse = NaN(candidateCount, 1);
    bic = NaN(candidateCount, 1);
    aicc = NaN(candidateCount, 1);
    stable = false(candidateCount, 1);
    valid = false(candidateCount, 1);
    failureMessage = strings(candidateCount, 1);
    models = cell(candidateCount, 1);
    row = 0;
    estimationOptions = tfestOptions( ...
        EnforceStability=true, InitialCondition='zero', Display='off');

    for currentPoleOrder = 1:maxOrder
        currentZeroOrder = max(0, currentPoleOrder - 1);
        for currentDelay = delayRange
            row = row + 1;
            poleOrder(row) = currentPoleOrder;
            zeroOrder(row) = currentZeroOrder;
            delaySamples(row) = currentDelay;
            trainingInput = shiftWithZeroPadding( ...
                inputSignal(trainingIndices), currentDelay);
            trainingOutput = outputSignal(trainingIndices);
            try
                data = iddata(trainingOutput, trainingInput, sampleTime);
                candidate = estimateCandidate(data, currentPoleOrder, ...
                    currentZeroOrder, sampleTime, domain, estimationOptions);
                currentFit = double(candidate.Report.Fit.FitPercent);
                currentStable = isstable(candidate);
                if ~isscalar(currentFit) || ~isfinite(currentFit)
                    failureMessage(row) = "Nonfinite fit returned by tfest.";
                    continue;
                end
                fitPercent(row) = currentFit;
                [rmse(row), nrmse(row), bic(row), aicc(row)] = ...
                    residualScores(candidate, trainingInput, trainingOutput, ...
                    sampleTime, currentPoleOrder, currentZeroOrder, domain);
                stable(row) = currentStable;
                valid(row) = currentStable && isfinite(rmse(row));
                models{row} = candidate;
                if ~currentStable
                    failureMessage(row) = "Estimated model is unstable.";
                elseif ~valid(row)
                    failureMessage(row) = "Residual diagnostics are nonfinite.";
                end
            catch exception
                failureMessage(row) = string(exception.identifier) + ": " + ...
                    string(exception.message);
            end
        end
    end

    candidateTrainingSampleCount = repmat( ...
        trainingSampleCount, candidateCount, 1);
    candidateTable = table(poleOrder, zeroOrder, delaySamples, ...
        candidateTrainingSampleCount, fitPercent, rmse, nrmse, bic, aicc, ...
        stable, valid, failureMessage, 'VariableNames', ...
        {'poleOrder', 'zeroOrder', 'delaySamples', 'trainingSampleCount', ...
        'fitPercent', 'rmse', 'nrmse', 'bic', 'aicc', 'stable', 'valid', ...
        'failureMessage'});
    validRows = find(valid);
    if isempty(validRows)
        error(identifier(apiName, 'NoValidModel'), ...
            ['No stable model with finite fit and residual RMSE was identified ' ...
            'within MaxOrder and DelayRange.']);
    end

    bestFitPercent = max(fitPercent(validRows));
    selectedRow = selectCandidate(selectionCriterion, validRows, ...
        poleOrder, fitPercent, bic, aicc, bestFitPercent, fitTolerance, apiName);
    model = models{selectedRow};
    selectedShiftedInput = shiftWithZeroPadding( ...
        inputSignal, delaySamples(selectedRow));
    fullPrediction = simulateModel( ...
        model, selectedShiftedInput, sampleTime, domain);
    [validationRmse, validationNrmse, validationFitPercent] = ...
        holdoutScores(outputSignal, fullPrediction, validationIndices);

    diagnostics = struct( ...
        'domain', domain, ...
        'sampleTime', sampleTime, ...
        'maxOrder', maxOrder, ...
        'delayRange', delayRange, ...
        'fitTolerance', fitTolerance, ...
        'selectionCriterion', selectionCriterion, ...
        'trainingSampleCount', trainingSampleCount, ...
        'trainingIndices', trainingIndices, ...
        'validationIndices', validationIndices, ...
        'validationMode', validationMode, ...
        'validationRmse', validationRmse, ...
        'validationNrmse', validationNrmse, ...
        'validationFitPercent', validationFitPercent, ...
        'fullPrediction', fullPrediction, ...
        'numeratorOrderPolicy', "pole-order-minus-one", ...
        'selectedPoleOrder', poleOrder(selectedRow), ...
        'selectedZeroOrder', zeroOrder(selectedRow), ...
        'selectedDelaySamples', delaySamples(selectedRow), ...
        'selectedFitPercent', fitPercent(selectedRow), ...
        'selectedRmse', rmse(selectedRow), ...
        'selectedNrmse', nrmse(selectedRow), ...
        'selectedBic', bic(selectedRow), ...
        'selectedAicc', aicc(selectedRow), ...
        'bestFitPercent', bestFitPercent, ...
        'maxOrderReached', poleOrder(selectedRow) == maxOrder, ...
        'candidateTable', candidateTable);
end

function candidate = estimateCandidate(data, poleOrder, zeroOrder, ...
        sampleTime, domain, estimationOptions)
    if domain == "continuous"
        candidate = tfest(data, poleOrder, zeroOrder, ...
            'Ts', 0, estimationOptions);
    else
        candidate = tfest(data, poleOrder, zeroOrder, ...
            'Ts', sampleTime, estimationOptions);
        candidate.Variable = 'z^-1';
    end
end

function selectedRow = selectCandidate(criterion, validRows, poleOrder, ...
        fitPercent, bic, aicc, bestFitPercent, fitTolerance, apiName)
    switch criterion
        case "parsimonious-fit"
            eligibleRows = validRows(fitPercent(validRows) >= ...
                bestFitPercent - fitTolerance);
            minimumOrder = min(poleOrder(eligibleRows));
            parsimoniousRows = eligibleRows( ...
                poleOrder(eligibleRows) == minimumOrder);
            [~, localBest] = max(fitPercent(parsimoniousRows));
            selectedRow = parsimoniousRows(localBest);
        case "best-fit"
            [~, localBest] = max(fitPercent(validRows));
            selectedRow = validRows(localBest);
        case "bic"
            eligibleRows = validRows(isfinite(bic(validRows)));
            selectedRow = minimumScoreRow(eligibleRows, bic, criterion, apiName);
        case "aicc"
            eligibleRows = validRows(isfinite(aicc(validRows)));
            selectedRow = minimumScoreRow(eligibleRows, aicc, criterion, apiName);
    end
end

function selectedRow = minimumScoreRow(eligibleRows, score, criterion, apiName)
    if isempty(eligibleRows)
        error(identifier(apiName, 'NoFiniteSelectionScore'), ...
            'No valid model has a finite %s score.', criterion);
    end
    [~, localBest] = min(score(eligibleRows));
    selectedRow = eligibleRows(localBest);
end

function [inputSignal, outputSignal] = validateSignals( ...
        inputSignal, outputSignal, apiName)
    errorIdentifier = identifier(apiName, 'InvalidSignals');
    if ~isnumeric(inputSignal) || ~isnumeric(outputSignal) || ...
            ~isvector(inputSignal) || ~isvector(outputSignal) || ...
            isempty(inputSignal) || isempty(outputSignal) || ...
            ~isreal(inputSignal) || ~isreal(outputSignal) || ...
            any(~isfinite(inputSignal(:))) || any(~isfinite(outputSignal(:))) || ...
            numel(inputSignal) ~= numel(outputSignal) || numel(inputSignal) < 4
        error(errorIdentifier, ...
            'Input and output must be equal-length finite real numeric vectors with at least four samples.');
    end
    validateExactIntegerConversion(inputSignal, errorIdentifier, 'Input signal');
    validateExactIntegerConversion(outputSignal, errorIdentifier, 'Output signal');
    inputSignal = double(inputSignal(:));
    outputSignal = double(outputSignal(:));
    if norm(inputSignal) == 0
        error(errorIdentifier, 'Input signal must contain nonzero excitation.');
    end
    if norm(outputSignal) == 0
        error(errorIdentifier, 'Output signal must contain a nonzero response.');
    end
end

function validateExactIntegerConversion(value, errorIdentifier, label)
    if isa(value, 'uint64')
        unsafe = any(value(:) > uint64(flintmax));
    elseif isa(value, 'int64')
        limit = int64(flintmax);
        unsafe = any(value(:) > limit | value(:) < -limit);
    else
        unsafe = false;
    end
    if unsafe
        error(errorIdentifier, ...
            '%s contains integers outside double contiguous exact range.', label);
    end
end

function value = validatePositiveScalar(value, errorIdentifier, label)
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(value) || value <= 0
        error(errorIdentifier, ...
            '%s must be a finite positive real scalar.', label);
    end
    validateExactIntegerConversion(value, errorIdentifier, label);
    value = double(value);
end

function value = validateNonnegativeScalar(value, errorIdentifier, label)
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(value) || value < 0
        error(errorIdentifier, ...
            '%s must be a finite nonnegative real scalar.', label);
    end
    validateExactIntegerConversion(value, errorIdentifier, label);
    value = double(value);
end

function value = validatePositiveInteger(value, errorIdentifier, label)
    value = validatePositiveScalar(value, errorIdentifier, label);
    if value ~= fix(value)
        error(errorIdentifier, '%s must be a positive integer.', label);
    end
end

function delayRange = validateDelayRange(delayRange, sampleCount, apiName)
    errorIdentifier = identifier(apiName, 'InvalidDelayRange');
    if ~isnumeric(delayRange) || ~isvector(delayRange) || isempty(delayRange) || ...
            ~isreal(delayRange) || any(~isfinite(delayRange(:)))
        error(errorIdentifier, ...
            'DelayRange must be a nonempty vector of unique finite integer sample shifts.');
    end
    validateExactIntegerConversion(delayRange, errorIdentifier, 'DelayRange');
    delayRange = double(delayRange(:).');
    if any(delayRange ~= fix(delayRange)) || ...
            numel(unique(delayRange)) ~= numel(delayRange) || ...
            any(abs(delayRange) >= sampleCount)
        error(errorIdentifier, ...
            'DelayRange must contain unique integers with absolute value smaller than signal length.');
    end
end

function [rmse, nrmse, bic, aicc] = residualScores( ...
        model, inputSignal, outputSignal, sampleTime, poleOrder, zeroOrder, ...
        domain)
    predicted = simulateModel(model, inputSignal, sampleTime, domain);
    residual = outputSignal - predicted;
    sampleCount = numel(residual);
    squaredError = sum(residual .^ 2);
    rmse = sqrt(squaredError / sampleCount);
    scale = norm(outputSignal - mean(outputSignal));
    if scale > 0
        nrmse = norm(residual) / scale;
    else
        nrmse = NaN;
    end
    parameterCount = transferFunctionParameterCount( ...
        poleOrder, zeroOrder, domain);
    protectedMse = max(squaredError / sampleCount, realmin('double'));
    bic = sampleCount * log(protectedMse) + parameterCount * log(sampleCount);
    aic = sampleCount * log(protectedMse) + 2 * parameterCount;
    if sampleCount > parameterCount + 1
        aicc = aic + 2 * parameterCount * (parameterCount + 1) / ...
            (sampleCount - parameterCount - 1);
    else
        aicc = Inf;
    end
end

function parameterCount = transferFunctionParameterCount( ...
        poleOrder, zeroOrder, domain)
    if domain == "discrete" && zeroOrder > 0
        parameterCount = poleOrder + zeroOrder;
    else
        parameterCount = poleOrder + zeroOrder + 1;
    end
end

function predicted = simulateModel(model, inputSignal, sampleTime, domain)
    time = (0:(numel(inputSignal) - 1)).' * sampleTime;
    if domain == "continuous"
        predicted = lsim(model, inputSignal, time, 'zoh');
    else
        predicted = lsim(model, inputSignal, time);
    end
    predicted = double(predicted(:));
end

function [rmse, nrmse, fitPercent] = holdoutScores( ...
        outputSignal, prediction, validationIndices)
    if isempty(validationIndices)
        rmse = NaN;
        nrmse = NaN;
        fitPercent = NaN;
        return;
    end
    target = outputSignal(validationIndices);
    residual = target - prediction(validationIndices);
    rmse = sqrt(mean(residual.^2));
    scale = norm(target - mean(target));
    if scale > 0
        nrmse = norm(residual) / scale;
        fitPercent = 100 * (1 - nrmse);
    else
        nrmse = NaN;
        fitPercent = NaN;
    end
end

function [trainingSampleCount, trainingIndices, validationIndices, mode] = ...
        validateTrainingSampleCount(value, signalLength, apiName)
    if isempty(value)
        trainingSampleCount = signalLength;
        trainingIndices = 1:signalLength;
        validationIndices = zeros(1, 0);
        mode = "in-sample-only";
        return;
    end
    trainingSampleCount = validatePositiveInteger(value, ...
        identifier(apiName, 'InvalidTrainingSampleCount'), ...
        'TrainingSampleCount');
    if trainingSampleCount < 4 || trainingSampleCount >= signalLength
        error(identifier(apiName, 'InvalidTrainingSampleCount'), ...
            ['TrainingSampleCount must be at least four and smaller than ', ...
            'the signal length to define a nonempty temporal holdout.']);
    end
    trainingIndices = 1:trainingSampleCount;
    validationIndices = (trainingSampleCount + 1):signalLength;
    mode = "temporal-holdout";
end

function shifted = shiftWithZeroPadding(signal, delay)
    shifted = zeros(size(signal));
    if delay >= 0
        shifted((delay + 1):end) = signal(1:(end - delay));
    else
        advance = -delay;
        shifted(1:(end - advance)) = signal((advance + 1):end);
    end
end

function value = identifier(apiName, suffix)
    value = "pds:identification:" + apiName + ":" + suffix;
end
