function [pedestalLevel, diagnostics] = estimatePedestal(waveforms, options)
%ESTIMATEPEDESTAL Estimate one pedestal level per waveform.
%
% Rows are events and columns are samples. The pedestal region is explicit.

arguments
    waveforms {mustBeNumeric, mustBeReal, mustBeFinite}
    options.SampleIndices {mustBeNumeric, mustBeReal, mustBeFinite} = []
    options.Method (1, 1) string = "mean"
    options.BlockSize {mustBeNumeric, mustBeReal, mustBeFinite} = []
end

if isempty(waveforms) || ~ismatrix(waveforms)
    error('pds:preprocess:estimatePedestal:InvalidWaveforms', ...
        'Waveforms must be a nonempty two-dimensional numeric array.');
end
if iscolumn(waveforms) && numel(waveforms) > 1
    error('pds:preprocess:estimatePedestal:AmbiguousColumnVector', ...
        ['A column vector is ambiguous under the events-by-samples ' ...
        'contract; provide one waveform as a row vector.']);
end
if hasInexactIntegerValues(waveforms)
    error('pds:preprocess:estimatePedestal:InexactIntegerConversion', ...
        'Integer waveform values must be exactly representable as double.');
end
if isvector(waveforms)
    waveforms = reshape(waveforms, 1, []);
end
waveforms = double(waveforms);

sampleIndices = double(options.SampleIndices(:).');
if isempty(sampleIndices)
    error('pds:preprocess:estimatePedestal:MissingSampleIndices', ...
        'SampleIndices must explicitly identify the pedestal region.');
end
if any(sampleIndices < 1 | sampleIndices > size(waveforms, 2) | ...
        sampleIndices ~= fix(sampleIndices)) || ...
        any(diff(sampleIndices) <= 0)
    error('pds:preprocess:estimatePedestal:InvalidSampleIndices', ...
        ['SampleIndices must contain strictly increasing integer sample ' ...
        'indices in range.']);
end

method = lower(options.Method);
pedestalSamples = waveforms(:, sampleIndices);
sampleCount = numel(sampleIndices);
blockMeans = zeros(size(waveforms, 1), 0);
blockCount = 0;
blockSize = 0;

switch method
    case "mean"
        pedestalLevel = mean(pedestalSamples, 2);
        sampleNoiseSigma = std(pedestalSamples, 0, 2);
        pedestalStandardError = sampleNoiseSigma / sqrt(sampleCount);
    case "median"
        pedestalLevel = median(pedestalSamples, 2);
        sampleNoiseSigma = 1.4826 * median( ...
            abs(pedestalSamples - pedestalLevel), 2);
        pedestalStandardError = sqrt(pi / 2) * ...
            sampleNoiseSigma / sqrt(sampleCount);
    case "median-of-means"
        blockSize = validateBlockSize(options.BlockSize, sampleCount);
        blockCount = sampleCount / blockSize;
        blockMeans = zeros(size(waveforms, 1), blockCount);
        for blockIndex = 1:blockCount
            firstIndex = (blockIndex - 1) * blockSize + 1;
            localIndices = firstIndex:(firstIndex + blockSize - 1);
            blockMeans(:, blockIndex) = mean( ...
                pedestalSamples(:, localIndices), 2);
        end
        pedestalLevel = median(blockMeans, 2);
        sampleNoiseSigma = 1.4826 * median( ...
            abs(pedestalSamples - pedestalLevel), 2);
        pedestalStandardError = sqrt(pi / 2) * ...
            sampleNoiseSigma / sqrt(sampleCount);
    otherwise
        error('pds:preprocess:estimatePedestal:UnknownMethod', ...
            'Unsupported pedestal method: %s.', options.Method);
end

diagnostics = struct( ...
    'method', method, ...
    'sampleIndices', sampleIndices, ...
    'sampleCount', sampleCount, ...
    'sampleNoiseSigma', sampleNoiseSigma, ...
    'pedestalStandardError', pedestalStandardError, ...
    'blockSize', blockSize, ...
    'blockCount', blockCount, ...
    'blockMeans', blockMeans);
end

function tf = hasInexactIntegerValues(value)
if isa(value, 'uint64')
    tf = any(value(:) > uint64(flintmax));
elseif isa(value, 'int64')
    limit = int64(flintmax);
    tf = any(value(:) > limit | value(:) < -limit);
else
    tf = false;
end
end

function blockSize = validateBlockSize(value, sampleCount)
blockSize = double(value);
if ~isscalar(blockSize) || blockSize < 1 || ...
        blockSize ~= fix(blockSize) || mod(sampleCount, blockSize) ~= 0
    error('pds:preprocess:estimatePedestal:InvalidBlockSize', ...
        'BlockSize must be a positive integer divisor of the sample count.');
end
end
