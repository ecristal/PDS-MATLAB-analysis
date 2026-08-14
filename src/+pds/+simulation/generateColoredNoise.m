function [noise, diagnostics] = generateColoredNoise( ...
        sampleCount, samplePeriod, options)
%GENERATECOLOREDNOISE Generate real stationary noise from a bilateral PSD.
%   Rows are independent events and columns are samples. NoisePsd must have
%   SAMPLECOUNT nonnegative bins in FFT order and units of signal-unit^2/Hz.

arguments
    sampleCount
    samplePeriod
    options.NoisePsd = []
    options.TargetRms = []
    options.EventCount = 1
    options.RandomStream = []
    options.Seed = []
    options.OutputSampleCount = []
end

sampleCount = validatePositiveInteger(sampleCount, ...
    'pds:simulation:generateColoredNoise:InvalidSampleCount', 'SampleCount');
samplePeriod = validatePositiveScalar(samplePeriod, ...
    'pds:simulation:generateColoredNoise:InvalidSamplePeriod', 'SamplePeriod');
eventCount = validatePositiveInteger(options.EventCount, ...
    'pds:simulation:generateColoredNoise:InvalidEventCount', 'EventCount');
noisePsd = validatePsd(options.NoisePsd, sampleCount);
outputSampleCount = validateOutputSampleCount( ...
    options.OutputSampleCount, sampleCount);
[stream, randomSource, seed] = resolveRandomSource( ...
    options.RandomStream, options.Seed);

targetRms = options.TargetRms;
if ~isempty(targetRms)
    targetRms = validatePositiveScalar(targetRms, ...
        'pds:simulation:generateColoredNoise:InvalidTargetRms', 'TargetRms');
end

sampleRateHz = 1 / samplePeriod;
coefficientPower = sampleRateHz * sampleCount * noisePsd;
coefficients = complex(zeros(eventCount, sampleCount));
coefficients(:, 1) = sqrt(coefficientPower(1)) .* ...
    randn(stream, eventCount, 1);

if rem(sampleCount, 2) == 0
    positiveIndices = 2:(sampleCount / 2);
    nyquistIndex = sampleCount / 2 + 1;
    coefficients(:, nyquistIndex) = sqrt(coefficientPower(nyquistIndex)) .* ...
        randn(stream, eventCount, 1);
else
    positiveIndices = 2:((sampleCount + 1) / 2);
end

for positiveIndex = positiveIndices
    negativeIndex = sampleCount - positiveIndex + 2;
    standardDeviation = sqrt(coefficientPower(positiveIndex) / 2);
    value = standardDeviation .* (randn(stream, eventCount, 1) + ...
        1i * randn(stream, eventCount, 1));
    coefficients(:, positiveIndex) = value;
    coefficients(:, negativeIndex) = conj(value);
end

generatedNoise = real(ifft(coefficients, [], 2));
cropStart = floor((sampleCount - outputSampleCount) / 2) + 1;
cropIndices = cropStart:(cropStart + outputSampleCount - 1);
if ~isempty(targetRms)
    deliveredBeforeScaling = generatedNoise(:, cropIndices);
    realizedRmsBeforeScaling = sqrt(mean(deliveredBeforeScaling.^2, 2));
    if any(realizedRmsBeforeScaling == 0)
        error('pds:simulation:generateColoredNoise:ZeroRealizedRms', ...
            'A positive TargetRms cannot scale a zero-power realization.');
    end
    normalizationScale = targetRms ./ realizedRmsBeforeScaling;
    generatedNoise = generatedNoise .* normalizationScale;
    normalization = "per-delivered-event-rms";
else
    normalizationScale = ones(eventCount, 1);
    normalization = "none";
end

realizedPsdPerEvent = abs(fft(generatedNoise, [], 2)).^2 / ...
    (sampleRateHz * sampleCount);
noise = generatedNoise(:, cropIndices);
realizedRms = sqrt(mean(noise.^2, 2));
deliveredRealizedPsdPerEvent = abs(fft(noise, [], 2)).^2 / ...
    (sampleRateHz * outputSampleCount);
effectiveTargetPsd = noisePsd * mean(normalizationScale.^2);
positiveBins = 0:floor(sampleCount / 2);
negativeBins = (-ceil(sampleCount / 2) + 1):-1;
frequencyHz = [positiveBins, negativeBins] * (sampleRateHz / sampleCount);
deliveredPositiveBins = 0:floor(outputSampleCount / 2);
deliveredNegativeBins = (-ceil(outputSampleCount / 2) + 1):-1;
deliveredFrequencyHz = [deliveredPositiveBins, deliveredNegativeBins] * ...
    (sampleRateHz / outputSampleCount);

diagnostics = struct( ...
    'sampleCount', sampleCount, ...
    'generatedSampleCount', sampleCount, ...
    'outputSampleCount', outputSampleCount, ...
    'cropIndices', cropIndices, ...
    'eventCount', eventCount, ...
    'samplePeriod', samplePeriod, ...
    'sampleRateHz', sampleRateHz, ...
    'frequencyHz', frequencyHz, ...
    'frequencyOrder', "fft", ...
    'psdSidedness', "bilateral", ...
    'psdUnits', "signal-unit^2/Hz", ...
    'randomSource', randomSource, ...
    'seed', seed, ...
    'targetPsd', noisePsd, ...
    'effectiveTargetPsd', effectiveTargetPsd, ...
    'realizedPsd', mean(realizedPsdPerEvent, 1), ...
    'realizedPsdPerEvent', realizedPsdPerEvent, ...
    'deliveredFrequencyHz', deliveredFrequencyHz, ...
    'deliveredRealizedPsd', mean(deliveredRealizedPsdPerEvent, 1), ...
    'deliveredRealizedPsdPerEvent', deliveredRealizedPsdPerEvent, ...
    'targetRms', targetRms, ...
    'realizedRms', realizedRms, ...
    'normalization', normalization, ...
    'normalizationScale', normalizationScale);
end


function value = validatePositiveInteger(value, errorIdentifier, label)
value = validatePositiveScalar(value, errorIdentifier, label);
if value ~= fix(value) || value < 2 && label == "SampleCount"
    error(errorIdentifier, '%s must be an integer in its valid range.', label);
end
end


function outputSampleCount = validateOutputSampleCount(value, sampleCount)
if isempty(value)
    outputSampleCount = sampleCount;
    return;
end
errorIdentifier = ...
    'pds:simulation:generateColoredNoise:InvalidOutputSampleCount';
outputSampleCount = validatePositiveInteger( ...
    value, errorIdentifier, 'OutputSampleCount');
if outputSampleCount > sampleCount
    error(errorIdentifier, ...
        'OutputSampleCount must not exceed SampleCount.');
end
end


function value = validatePositiveScalar(value, errorIdentifier, label)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value <= 0
    error(errorIdentifier, '%s must be a finite positive real scalar.', label);
end
validateExactIntegerConversion(value, errorIdentifier, label);
value = double(value);
end


function noisePsd = validatePsd(noisePsd, sampleCount)
errorIdentifier = 'pds:simulation:generateColoredNoise:InvalidNoisePsd';
if ~isnumeric(noisePsd) || ~isvector(noisePsd) || ...
        numel(noisePsd) ~= sampleCount || ~isreal(noisePsd) || ...
        any(~isfinite(noisePsd(:))) || any(noisePsd(:) < 0) || ...
        ~any(noisePsd(:) > 0)
    error(errorIdentifier, ...
        ['NoisePsd must be a nonzero finite nonnegative real vector with ', ...
        'SampleCount bins.']);
end
validateExactIntegerConversion(noisePsd, errorIdentifier, 'NoisePsd');
noisePsd = double(noisePsd(:).');
mirrored = noisePsd([1, end:-1:2]);
tolerance = 100 * eps(max(1, max(noisePsd))) * sampleCount;
if max(abs(noisePsd - mirrored)) > tolerance
    error('pds:simulation:generateColoredNoise:NonHermitianPsd', ...
        'NoisePsd must be symmetric between positive and negative frequencies.');
end
end


function [stream, source, seed] = resolveRandomSource(stream, seed)
if ~isempty(stream) && ~isempty(seed)
    error('pds:simulation:generateColoredNoise:ConflictingRandomSource', ...
        'Specify either RandomStream or Seed, not both.');
end
if ~isempty(stream)
    if ~isa(stream, 'RandStream') || ~isscalar(stream)
        error('pds:simulation:generateColoredNoise:InvalidRandomStream', ...
            'RandomStream must be a scalar RandStream object.');
    end
    source = "stream";
    seed = [];
    return;
end
if isempty(seed)
    seed = 0;
    source = "default-seed";
else
    if ~isnumeric(seed) || ~isscalar(seed) || ~isreal(seed) || ...
            ~isfinite(seed) || seed < 0 || seed ~= fix(seed)
        error('pds:simulation:generateColoredNoise:InvalidSeed', ...
            'Seed must be a finite nonnegative integer scalar.');
    end
    validateExactIntegerConversion(seed, ...
        'pds:simulation:generateColoredNoise:InvalidSeed', 'Seed');
    seed = double(seed);
    source = "seed";
end
try
    stream = RandStream('mt19937ar', 'Seed', seed);
catch exception
    error('pds:simulation:generateColoredNoise:InvalidRandomStream', ...
        'Could not create a local random stream: %s', exception.message);
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
