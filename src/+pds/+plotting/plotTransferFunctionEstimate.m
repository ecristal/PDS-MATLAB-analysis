function [figureHandle, axesHandles] = plotTransferFunctionEstimate( ...
        target, predictions, options)
%PLOTTRANSFERFUNCTIONESTIMATE Plot full, peak, and tail response diagnostics.
%   This function creates graphics only. It does not save or load files.

arguments
    target
    predictions
    options.SampleTime = []
    options.ModelLabels = strings(0, 1)
    options.TrainingSampleCount = []
    options.TailStartIndex = []
    options.Visible = "on"
    options.Title = "Transfer-function estimate review"
end

[target, predictions] = validateSignals(target, predictions);
sampleTime = validatePositiveScalar(options.SampleTime, ...
    'pds:plotting:plotTransferFunctionEstimate:InvalidSampleTime');
modelCount = size(predictions, 1);
labels = validateLabels(options.ModelLabels, modelCount);
visible = lower(string(options.Visible));
if ~isscalar(visible) || ~any(visible == ["on", "off"])
    error('pds:plotting:plotTransferFunctionEstimate:InvalidVisible', ...
        'Visible must be on or off.');
end
plotTitle = string(options.Title);
if ~isscalar(plotTitle)
    error('pds:plotting:plotTransferFunctionEstimate:InvalidTitle', ...
        'Title must be scalar text.');
end

sampleCount = numel(target);
trainingSampleCount = validateOptionalIndex(options.TrainingSampleCount, ...
    sampleCount, 'InvalidTrainingSampleCount');
[~, peakIndex] = max(abs(target));
if isempty(options.TailStartIndex)
    tailStartIndex = min(sampleCount, peakIndex + max(1, round(sampleCount / 10)));
else
    tailStartIndex = validateOptionalIndex(options.TailStartIndex, ...
        sampleCount, 'InvalidTailStartIndex');
end

timeMicroseconds = (0:(sampleCount - 1)) * sampleTime * 1e6;
peakHalfWidth = max(5, round(sampleCount / 20));
peakWindow = max(1, peakIndex - peakHalfWidth): ...
    min(sampleCount, peakIndex + 2 * peakHalfWidth);
tailWindow = tailStartIndex:sampleCount;

figureHandle = figure('Visible', char(visible), 'Color', 'w', ...
    'Position', [100, 100, 1150, 850], 'Name', char(plotTitle), ...
    'NumberTitle', 'off');
layout = tiledlayout(figureHandle, 3, 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, plotTitle);
axesHandles = gobjects(3, 1);
axesHandles(1) = nexttile(layout);
plotWindow(axesHandles(1), 1:sampleCount, "Full waveform");
axesHandles(2) = nexttile(layout);
plotWindow(axesHandles(2), peakWindow, "Peak region");
axesHandles(3) = nexttile(layout);
plotWindow(axesHandles(3), tailWindow, "Tail and undershoot");
xlabel(axesHandles(3), 'Time [microseconds]');

    function plotWindow(axisHandle, indices, panelTitle)
        hold(axisHandle, 'on');
        plot(axisHandle, timeMicroseconds(indices), target(indices), ...
            'k-', 'LineWidth', 1.5, 'DisplayName', 'target');
        colors = lines(modelCount);
        for modelIndex = 1:modelCount
            plot(axisHandle, timeMicroseconds(indices), ...
                predictions(modelIndex, indices), '--', 'LineWidth', 1.25, ...
                'Color', colors(modelIndex, :), ...
                'DisplayName', labels(modelIndex));
        end
        yline(axisHandle, 0, ':', 'Color', [0.4, 0.4, 0.4], ...
            'HandleVisibility', 'off');
        if ~isempty(trainingSampleCount) && trainingSampleCount < sampleCount
            boundaryTime = timeMicroseconds(trainingSampleCount + 1);
            if boundaryTime >= min(timeMicroseconds(indices)) && ...
                    boundaryTime <= max(timeMicroseconds(indices))
                xline(axisHandle, boundaryTime, '-.', 'holdout', ...
                    'Color', [0.3, 0.3, 0.3], 'LineWidth', 1.1, ...
                    'HandleVisibility', 'off');
            end
        end
        grid(axisHandle, 'on');
        ylabel(axisHandle, 'Normalized amplitude');
        title(axisHandle, panelTitle);
        if axisHandle == axesHandles(1)
            legend(axisHandle, 'Location', 'best');
        end
    end
end


function [target, predictions] = validateSignals(target, predictions)
errorIdentifier = 'pds:plotting:plotTransferFunctionEstimate:InvalidSignals';
if ~isnumeric(target) || ~isvector(target) || isempty(target) || ...
        ~isreal(target) || any(~isfinite(target(:))) || ...
        ~isnumeric(predictions) || ~ismatrix(predictions) || ...
        isempty(predictions) || ~isreal(predictions) || ...
        any(~isfinite(predictions(:)))
    error(errorIdentifier, 'Target and predictions must be finite real arrays.');
end
validateExactIntegerConversion(target, errorIdentifier, 'Target');
validateExactIntegerConversion(predictions, errorIdentifier, 'Predictions');
target = double(target(:).');
predictions = double(predictions);
if isvector(predictions)
    predictions = predictions(:).';
end
if size(predictions, 2) ~= numel(target)
    error(errorIdentifier, ...
        'Each prediction row must have the same sample count as target.');
end
end


function labels = validateLabels(labels, modelCount)
if isempty(labels)
    labels = "model " + string((1:modelCount).');
else
    labels = string(labels(:));
    if numel(labels) ~= modelCount || any(strlength(labels) == 0)
        error('pds:plotting:plotTransferFunctionEstimate:InvalidModelLabels', ...
            'ModelLabels must contain one nonempty label per prediction row.');
    end
end
end


function value = validatePositiveScalar(value, errorIdentifier)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value <= 0
    error(errorIdentifier, 'SampleTime must be a finite positive scalar.');
end
validateExactIntegerConversion(value, errorIdentifier, 'SampleTime');
value = double(value);
end


function value = validateOptionalIndex(value, sampleCount, suffix)
if isempty(value)
    return;
end
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value ~= fix(value) || value < 1 || ...
        value > sampleCount
    error("pds:plotting:plotTransferFunctionEstimate:" + suffix, ...
        'Index must be an integer in the signal range.');
end
validateExactIntegerConversion(value, ...
    "pds:plotting:plotTransferFunctionEstimate:" + suffix, 'Index');
value = double(value);
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
