function [eventTrain, truth] = generateEventTrain( ...
        sampleCount, samplePeriod, options)
%GENERATEEVENTTRAIN Generate target impulses with configurable multiplicity.
%   Dark counts and large-event impulses remain separate components.
%   Rows are independent events and columns are parent-trace samples.

arguments
    sampleCount
    samplePeriod
    options.EventCount = 1
    options.ReferenceIndex = []
    options.ReferenceAmplitude = 1
    options.SignalMultiplicityDistribution = "fixed"
    options.SignalMultiplicity = 1
    options.SignalMultiplicityLambda = 1
    options.SignalMultiplicitySupport = [0, 1]
    options.SignalMultiplicityPmf = [0, 1]
    options.DarkRateHz = 0
    options.LargeEventRateHz = 0
    options.LargeAmplitudeDistribution = "fixed"
    options.LargeAmplitude = 8000
    options.LargeAmplitudeRange = [8000, 16000]
    options.RandomStream = []
    options.Seed = []
    options.SaturationRange = []
end

sampleCount = validatePositiveInteger(sampleCount, ...
    'pds:simulation:generateEventTrain:InvalidSampleCount', 'SampleCount');
samplePeriod = validatePositiveScalar(samplePeriod, ...
    'pds:simulation:generateEventTrain:InvalidSamplePeriod', 'SamplePeriod');
eventCount = validatePositiveInteger(options.EventCount, ...
    'pds:simulation:generateEventTrain:InvalidEventCount', 'EventCount');
if isempty(options.ReferenceIndex)
    referenceIndex = ceil(sampleCount / 2);
else
    referenceIndex = validatePositiveInteger(options.ReferenceIndex, ...
        'pds:simulation:generateEventTrain:InvalidReferenceIndex', ...
        'ReferenceIndex');
    if referenceIndex > sampleCount
        error('pds:simulation:generateEventTrain:InvalidReferenceIndex', ...
            'ReferenceIndex must not exceed SampleCount.');
    end
end
referenceAmplitude = validatePositiveScalar(options.ReferenceAmplitude, ...
    'pds:simulation:generateEventTrain:InvalidReferenceAmplitude', ...
    'ReferenceAmplitude');
signalMultiplicityDistribution = validateSignalMultiplicityDistribution( ...
    options.SignalMultiplicityDistribution);
signalMultiplicityFixedValue = validateNonnegativeInteger( ...
    options.SignalMultiplicity, ...
    'pds:simulation:generateEventTrain:InvalidSignalMultiplicity', ...
    'SignalMultiplicity');
if signalMultiplicityFixedValue > flintmax
    error('pds:simulation:generateEventTrain:InvalidSignalMultiplicity', ...
        'SignalMultiplicity must not exceed flintmax.');
end
signalMultiplicityLambda = validateNonnegativeScalar( ...
    options.SignalMultiplicityLambda, ...
    'pds:simulation:generateEventTrain:InvalidSignalMultiplicityLambda', ...
    'SignalMultiplicityLambda');
maximumSignalMultiplicityLambda = 1e9;
if signalMultiplicityLambda > maximumSignalMultiplicityLambda
    error('pds:simulation:generateEventTrain:InvalidSignalMultiplicityLambda', ...
        'SignalMultiplicityLambda must not exceed 1e9.');
end
signalMultiplicitySupport = validateSignalMultiplicitySupport( ...
    options.SignalMultiplicitySupport);
signalMultiplicityPmf = validateSignalMultiplicityPmf( ...
    options.SignalMultiplicityPmf, numel(signalMultiplicitySupport));
validateReferenceMultiplicityProduct(referenceAmplitude, ...
    signalMultiplicityDistribution, signalMultiplicityFixedValue, ...
    signalMultiplicityLambda, signalMultiplicitySupport, ...
    signalMultiplicityPmf);
darkRateHz = validateNonnegativeScalar(options.DarkRateHz, ...
    'pds:simulation:generateEventTrain:InvalidDarkRateHz', 'DarkRateHz');
largeEventRateHz = validateNonnegativeScalar(options.LargeEventRateHz, ...
    'pds:simulation:generateEventTrain:InvalidLargeEventRateHz', ...
    'LargeEventRateHz');
largeAmplitude = validatePositiveScalar(options.LargeAmplitude, ...
    'pds:simulation:generateEventTrain:InvalidLargeAmplitude', ...
    'LargeAmplitude');
largeAmplitudeRange = validateOrderedRange(options.LargeAmplitudeRange, ...
    'pds:simulation:generateEventTrain:InvalidLargeAmplitudeRange', ...
    'LargeAmplitudeRange', true);
largeAmplitudeDistribution = validateAmplitudeDistribution( ...
    options.LargeAmplitudeDistribution);
saturationRange = validateSaturationRange(options.SaturationRange);
durationSeconds = sampleCount * samplePeriod;
if ~isfinite(durationSeconds) || durationSeconds <= 0
    error('pds:simulation:generateEventTrain:InvalidSamplePeriod', ...
        'SampleCount times SamplePeriod must be finite and positive.');
end

[stream, randomSource, seed] = resolveRandomSource( ...
    options.RandomStream, options.Seed);
[signalMultiplicity, expectedSignalMultiplicity] = ...
    sampleSignalMultiplicity(stream, eventCount, ...
    signalMultiplicityDistribution, signalMultiplicityFixedValue, ...
    signalMultiplicityLambda, signalMultiplicitySupport, ...
    signalMultiplicityPmf);
if any(signalMultiplicity > flintmax)
    error(['pds:simulation:generateEventTrain:' ...
        'SampledSignalMultiplicityOutOfRange'], ...
        'A sampled Poisson multiplicity exceeded flintmax.');
end
referenceComponent = zeros(eventCount, sampleCount);
referenceComponent(:, referenceIndex) = ...
    referenceAmplitude * signalMultiplicity;
darkComponent = zeros(eventCount, sampleCount);
largeEventComponent = zeros(eventCount, sampleCount);
darkEventTimesSeconds = repmat({zeros(1, 0)}, eventCount, 1);
darkEventIndices = repmat({zeros(1, 0)}, eventCount, 1);
darkEventAmplitudes = repmat({zeros(1, 0)}, eventCount, 1);
largeEventTimesSeconds = repmat({zeros(1, 0)}, eventCount, 1);
largeEventIndices = repmat({zeros(1, 0)}, eventCount, 1);
largeEventAmplitudes = repmat({zeros(1, 0)}, eventCount, 1);
for eventIndex = 1:eventCount
    [darkTimes, darkIndices] = simulatePoissonProcess( ...
        stream, darkRateHz, durationSeconds, samplePeriod, sampleCount);
    darkAmplitudes = ones(size(darkIndices));
    darkComponent(eventIndex, :) = accumulateEvents( ...
        darkIndices, darkAmplitudes, sampleCount);
    darkEventTimesSeconds{eventIndex} = darkTimes;
    darkEventIndices{eventIndex} = darkIndices;
    darkEventAmplitudes{eventIndex} = darkAmplitudes;

    [largeTimes, largeIndices] = simulatePoissonProcess( ...
        stream, largeEventRateHz, durationSeconds, samplePeriod, sampleCount);
    if largeAmplitudeDistribution == "fixed"
        largeAmplitudes = largeAmplitude * ones(size(largeIndices));
    else
        rangeWidth = largeAmplitudeRange(2) - largeAmplitudeRange(1);
        largeAmplitudes = largeAmplitudeRange(1) + rangeWidth * ...
            rand(stream, size(largeIndices));
    end
    largeEventComponent(eventIndex, :) = accumulateEvents( ...
        largeIndices, largeAmplitudes, sampleCount);
    largeEventTimesSeconds{eventIndex} = largeTimes;
    largeEventIndices{eventIndex} = largeIndices;
    largeEventAmplitudes{eventIndex} = largeAmplitudes;
end
unsaturatedEventTrain = referenceComponent + darkComponent + largeEventComponent;
if isempty(saturationRange)
    saturationMask = false(eventCount, sampleCount);
    eventTrain = unsaturatedEventTrain;
else
    saturationMask = unsaturatedEventTrain < saturationRange(1) | ...
        unsaturatedEventTrain > saturationRange(2);
    eventTrain = min(max(unsaturatedEventTrain, saturationRange(1)), ...
        saturationRange(2));
end

darkEventCount = cellfun(@numel, darkEventIndices);
largeEventCount = cellfun(@numel, largeEventIndices);
truth = struct( ...
    'sampleCount', sampleCount, ...
    'samplePeriod', samplePeriod, ...
    'durationSeconds', durationSeconds, ...
    'eventCount', eventCount, ...
    'referenceIndex', referenceIndex, ...
    'referenceAmplitude', referenceAmplitude, ...
    'signalMultiplicityDistribution', signalMultiplicityDistribution, ...
    'signalMultiplicity', signalMultiplicity, ...
    'signalMultiplicityFixedValue', signalMultiplicityFixedValue, ...
    'signalMultiplicityLambda', signalMultiplicityLambda, ...
    'signalMultiplicitySupport', signalMultiplicitySupport, ...
    'signalMultiplicityPmf', signalMultiplicityPmf, ...
    'expectedSignalMultiplicity', expectedSignalMultiplicity, ...
    'referenceComponent', referenceComponent, ...
    'darkComponent', darkComponent, ...
    'largeEventComponent', largeEventComponent, ...
    'darkEventMask', darkComponent ~= 0, ...
    'largeEventMask', largeEventComponent ~= 0, ...
    'unsaturatedEventTrain', unsaturatedEventTrain, ...
    'saturationMask', saturationMask, ...
    'saturationRange', saturationRange, ...
    'darkEventCount', darkEventCount, ...
    'largeEventCount', largeEventCount, ...
    'darkEventTimesSeconds', {darkEventTimesSeconds}, ...
    'darkEventIndices', {darkEventIndices}, ...
    'darkEventAmplitudes', {darkEventAmplitudes}, ...
    'largeEventTimesSeconds', {largeEventTimesSeconds}, ...
    'largeEventIndices', {largeEventIndices}, ...
    'largeEventAmplitudes', {largeEventAmplitudes}, ...
    'darkRateHz', darkRateHz, ...
    'largeEventRateHz', largeEventRateHz, ...
    'expectedDarkEventCount', darkRateHz * durationSeconds, ...
    'expectedLargeEventCount', largeEventRateHz * durationSeconds, ...
    'largeAmplitudeDistribution', largeAmplitudeDistribution, ...
    'largeAmplitude', largeAmplitude, ...
    'largeAmplitudeRange', largeAmplitudeRange, ...
    'randomSource', randomSource, ...
    'seed', seed);
end


function value = validatePositiveInteger(value, errorIdentifier, label)
value = validatePositiveScalar(value, errorIdentifier, label);
if value ~= fix(value)
    error(errorIdentifier, '%s must be an integer.', label);
end
end


function value = validateNonnegativeInteger(value, errorIdentifier, label)
value = validateNonnegativeScalar(value, errorIdentifier, label);
if value ~= fix(value)
    error(errorIdentifier, '%s must be an integer.', label);
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


function range = validateOrderedRange( ...
        range, errorIdentifier, label, requirePositive)
if ~isnumeric(range) || ~isvector(range) || numel(range) ~= 2 || ...
        ~isreal(range) || any(~isfinite(range(:)))
    error(errorIdentifier, ...
        '%s must contain two finite real values.', label);
end
validateExactIntegerConversion(range, errorIdentifier, label);
range = double(reshape(range, 1, 2));
if range(1) >= range(2) || requirePositive && any(range <= 0)
    suffix = "";
    if requirePositive
        suffix = " and positive";
    end
    error(errorIdentifier, ...
        '%s must be strictly increasing%s.', label, suffix);
end
end


function distribution = validateAmplitudeDistribution(value)
errorIdentifier = ...
    'pds:simulation:generateEventTrain:InvalidLargeAmplitudeDistribution';
if ~(isstring(value) && isscalar(value) || ischar(value) && isrow(value))
    error(errorIdentifier, ...
        'LargeAmplitudeDistribution must be fixed or uniform.');
end
distribution = string(value);
if ~any(distribution == ["fixed", "uniform"])
    error(errorIdentifier, ...
        'LargeAmplitudeDistribution must be fixed or uniform.');
end
end


function distribution = validateSignalMultiplicityDistribution(value)
errorIdentifier = ...
    'pds:simulation:generateEventTrain:InvalidSignalMultiplicityDistribution';
if ~(isstring(value) && isscalar(value) || ischar(value) && isrow(value))
    error(errorIdentifier, ...
        ['SignalMultiplicityDistribution must be fixed, poisson, ' ...
        'or empirical-pmf.']);
end
distribution = string(value);
if ~any(distribution == ["fixed", "poisson", "empirical-pmf"])
    error(errorIdentifier, ...
        ['SignalMultiplicityDistribution must be fixed, poisson, ' ...
        'or empirical-pmf.']);
end
end


function support = validateSignalMultiplicitySupport(support)
errorIdentifier = ...
    'pds:simulation:generateEventTrain:InvalidSignalMultiplicitySupport';
if ~isnumeric(support) || ~isvector(support) || isempty(support) || ...
        ~isreal(support) || any(~isfinite(support(:)))
    error(errorIdentifier, ...
        'SignalMultiplicitySupport must be a finite real numeric vector.');
end
validateExactIntegerConversion(support, errorIdentifier, ...
    'SignalMultiplicitySupport');
support = double(reshape(support, 1, []));
if any(support < 0) || any(support ~= fix(support)) || ...
        any(support > flintmax) || any(diff(support) <= 0)
    error(errorIdentifier, ...
        ['SignalMultiplicitySupport must contain strictly increasing ' ...
        'nonnegative integers not exceeding flintmax.']);
end
end


function probability = validateSignalMultiplicityPmf(probability, supportCount)
errorIdentifier = 'pds:simulation:generateEventTrain:InvalidSignalMultiplicityPmf';
if ~isnumeric(probability) || ~isvector(probability) || ...
        numel(probability) ~= supportCount || ~isreal(probability) || ...
        any(~isfinite(probability(:)))
    error(errorIdentifier, ...
        ['SignalMultiplicityPmf must be a finite real numeric vector ' ...
        'matching SignalMultiplicitySupport.']);
end
validateExactIntegerConversion(probability, errorIdentifier, ...
    'SignalMultiplicityPmf');
probability = double(reshape(probability, 1, []));
if any(probability < 0)
    error(errorIdentifier, ...
        'SignalMultiplicityPmf probabilities must be nonnegative.');
end
probabilitySum = sum(probability);
if ~isfinite(probabilitySum)
    error(errorIdentifier, ...
        'SignalMultiplicityPmf must have a finite sum.');
end
tolerance = max(1e-12, 10 * eps(max(1, probabilitySum)) * supportCount);
if abs(probabilitySum - 1) > tolerance
    error(errorIdentifier, ...
        'SignalMultiplicityPmf probabilities must sum to one.');
end
probability = probability / probabilitySum;
end


function validateReferenceMultiplicityProduct(referenceAmplitude, ...
        distribution, fixedValue, lambda, support, probability)
if distribution == "fixed"
    maximumMultiplicity = fixedValue;
elseif distribution == "poisson"
    if lambda == 0
        maximumMultiplicity = 0;
    else
        maximumMultiplicity = flintmax;
    end
else
    activeSupport = support(probability > 0);
    maximumMultiplicity = max(activeSupport);
end
if maximumMultiplicity > 0 && ...
        referenceAmplitude > realmax('double') / maximumMultiplicity
    error(['pds:simulation:generateEventTrain:' ...
        'SignalMultiplicityAmplitudeOverflow'], ...
        ['ReferenceAmplitude times the maximum relevant signal ' ...
        'multiplicity must remain finite in double.']);
end
end

function range = validateSaturationRange(range)
if isempty(range)
    range = [];
    return;
end
range = validateOrderedRange(range, ...
    'pds:simulation:generateEventTrain:InvalidSaturationRange', ...
    'SaturationRange', false);
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


function [multiplicity, expectedMultiplicity] = sampleSignalMultiplicity( ...
        stream, eventCount, distribution, fixedValue, lambda, ...
        support, probability)
if distribution == "fixed"
    multiplicity = fixedValue * ones(eventCount, 1);
    expectedMultiplicity = fixedValue;
    return;
end
if distribution == "poisson"
    multiplicity = zeros(eventCount, 1);
    for eventIndex = 1:eventCount
        multiplicity(eventIndex) = samplePoisson(stream, lambda);
    end
    expectedMultiplicity = lambda;
    return;
end
cumulativeProbability = cumsum(probability);
cumulativeProbability(end) = 1;
uniformDraw = rand(stream, eventCount, 1);
supportIndex = sum(uniformDraw >= cumulativeProbability, 2) + 1;
multiplicity = reshape(support(supportIndex), [], 1);
expectedMultiplicity = sum(support .* probability);
end


function value = samplePoisson(stream, lambda)
if lambda == 0
    value = 0;
    return;
end
if lambda < 10
    threshold = exp(-lambda);
    % Knuth requires one draw even when exp(-lambda) rounds to one.
    product = rand(stream);
    value = 0;
    while product > threshold
        value = value + 1;
        product = product * rand(stream);
    end
    return;
end

sqrtLambda = sqrt(lambda);
b = 0.931 + 2.53 * sqrtLambda;
a = -0.059 + 0.02483 * b;
inverseAlpha = 1.1239 + 1.1328 / (b - 3.4);
vThreshold = 0.9277 - 3.6224 / (b - 2);
while true
    u = rand(stream) - 0.5;
    v = rand(stream);
    uSymmetric = 0.5 - abs(u);
    if uSymmetric <= 0
        continue;
    end
    candidate = floor((2 * a / uSymmetric + b) * u + lambda + 0.43);
    if uSymmetric >= 0.07 && v <= vThreshold
        value = candidate;
        return;
    end
    if candidate < 0 || uSymmetric < 0.013 && v > uSymmetric
        continue;
    end
    acceptanceLog = log(v * inverseAlpha / ...
        (a / (uSymmetric * uSymmetric) + b));
    poissonLogMass = -lambda + candidate * log(lambda) - ...
        gammaln(candidate + 1);
    if acceptanceLog <= poissonLogMass
        value = candidate;
        return;
    end
end
end


function [times, indices] = simulatePoissonProcess( ...
        stream, rateHz, durationSeconds, samplePeriod, sampleCount)
if rateHz == 0
    times = zeros(1, 0);
    indices = zeros(1, 0);
    return;
end

times = zeros(1, 0);
currentTime = -log(max(rand(stream), realmin)) / rateHz;
while currentTime < durationSeconds
    times(end + 1) = currentTime; %#ok<AGROW>
    currentTime = currentTime - ...
        log(max(rand(stream), realmin)) / rateHz;
end
indices = min(floor(times / samplePeriod) + 1, sampleCount);
end


function component = accumulateEvents(indices, amplitudes, sampleCount)
component = zeros(1, sampleCount);
for occurrence = 1:numel(indices)
    component(indices(occurrence)) = component(indices(occurrence)) + ...
        amplitudes(occurrence);
end
end


function [stream, source, seed] = resolveRandomSource(stream, seed)
if ~isempty(stream) && ~isempty(seed)
    error('pds:simulation:generateEventTrain:ConflictingRandomSource', ...
        'Specify either RandomStream or Seed, not both.');
end
if ~isempty(stream)
    if ~isa(stream, 'RandStream') || ~isscalar(stream)
        error('pds:simulation:generateEventTrain:InvalidRandomStream', ...
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
    seed = validateNonnegativeScalar(seed, ...
        'pds:simulation:generateEventTrain:InvalidSeed', 'Seed');
    if seed ~= fix(seed)
        error('pds:simulation:generateEventTrain:InvalidSeed', ...
            'Seed must be an integer.');
    end
    source = "seed";
end
try
    stream = RandStream('mt19937ar', 'Seed', seed);
catch exception
    error('pds:simulation:generateEventTrain:InvalidRandomStream', ...
        'Could not create a local random stream: %s', exception.message);
end
end
