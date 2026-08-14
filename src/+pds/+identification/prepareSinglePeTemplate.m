function [preparedTemplate, diagnostics] = prepareSinglePeTemplate( ...
        template, options)
%PREPARESINGLEPETEMPLATE Baseline-correct and peak-normalize an SPE template.
%   Polarity is preserved. BaselineIndices are explicit sample indices.

arguments
    template
    options.BaselineIndices = []
    options.Polarity = "auto"
end

errorIdentifier = 'pds:identification:prepareSinglePeTemplate:InvalidTemplate';
if ~isnumeric(template) || ~isvector(template) || isempty(template) || ...
        ~isreal(template) || any(~isfinite(template(:))) || numel(template) < 2
    error(errorIdentifier, ...
        'Template must be a finite real numeric vector with at least two samples.');
end
validateExactIntegerConversion(template, errorIdentifier, 'Template');
template = double(template(:).');

baselineIndices = options.BaselineIndices;
if ~isnumeric(baselineIndices) || ~isvector(baselineIndices) || ...
        isempty(baselineIndices) || ~isreal(baselineIndices) || ...
        any(~isfinite(baselineIndices(:)))
    error('pds:identification:prepareSinglePeTemplate:InvalidBaselineIndices', ...
        'BaselineIndices must be a nonempty finite real numeric vector.');
end
validateExactIntegerConversion(baselineIndices, ...
    'pds:identification:prepareSinglePeTemplate:InvalidBaselineIndices', ...
    'BaselineIndices');
baselineIndices = double(baselineIndices(:).');
if any(baselineIndices ~= fix(baselineIndices)) || ...
        any(baselineIndices < 1 | baselineIndices > numel(template)) || ...
        any(diff(baselineIndices) <= 0)
    error('pds:identification:prepareSinglePeTemplate:InvalidBaselineIndices', ...
        'BaselineIndices must be strictly increasing unique indices in range.');
end

requestedPolarity = lower(string(options.Polarity));
if ~isscalar(requestedPolarity) || ...
        ~any(requestedPolarity == ["auto", "positive", "negative"])
    error('pds:identification:prepareSinglePeTemplate:InvalidPolarity', ...
        'Polarity must be auto, positive, or negative.');
end

baseline = median(template(baselineIndices));
corrected = template - baseline;
[positivePeak, positiveIndex] = max(corrected);
[negativePeak, negativeIndex] = min(corrected);
if positivePeak >= abs(negativePeak)
    detectedPolarity = "positive";
else
    detectedPolarity = "negative";
end
polarity = requestedPolarity;
if requestedPolarity == "auto"
    polarity = detectedPolarity;
end
if polarity == "positive"
    peakMagnitude = positivePeak;
    peakAmplitude = positivePeak;
    peakIndex = positiveIndex;
else
    peakMagnitude = abs(negativePeak);
    peakAmplitude = negativePeak;
    peakIndex = negativeIndex;
end
if ~isfinite(peakMagnitude) || peakMagnitude <= 0
    error('pds:identification:prepareSinglePeTemplate:DegenerateTemplate', ...
        'The requested polarity has no nonzero peak after baseline subtraction.');
end
preparedTemplate = corrected / peakMagnitude;

diagnostics = struct( ...
    'baseline', baseline, ...
    'baselineIndices', baselineIndices, ...
    'requestedPolarity', requestedPolarity, ...
    'detectedPolarity', detectedPolarity, ...
    'polarity', polarity, ...
    'normalization', "peak-magnitude", ...
    'peakIndex', peakIndex, ...
    'peakAmplitudeBeforeNormalization', peakAmplitude, ...
    'peakMagnitudeBeforeNormalization', peakMagnitude, ...
    'normalizationScale', 1 / peakMagnitude, ...
    'sampleCount', numel(template));
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
