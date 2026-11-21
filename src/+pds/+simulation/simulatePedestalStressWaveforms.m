function [waveforms, truth] = simulatePedestalStressWaveforms( ...
        sampleCount, samplePeriod, options)
%SIMULATEPEDESTALSTRESSWAVEFORMS Compose a long parent trace, then crop.
arguments
    sampleCount
    samplePeriod
    options.ResponseNumerator = []
    options.ResponseDenominator = 1
    options.OnePeAmplitude = []
    options.EventCount = 1
    options.EventOptions = struct()
    options.InjectedEvents = []
    options.InjectedEventProvenance = ""
    options.PretriggerSampleCount = []
    options.PedestalSampleCount = 100
    options.PedestalGuardSampleCount = 0
    options.BurnInSampleCount = []
    options.ResponseTolerance = 1e-3
    options.MaximumParentSampleCount = 1e6
    options.BaselineOffset = 0
    options.BaselineMode = "constant"
    options.BaselineSlopePerSample = []
    options.BaselineStepOffsetSamples = []
    options.BaselineStepAmplitude = []
    options.BaselineWanderStepRms = []
    options.RandomStream = []
    options.Seed = []
    options.NoisePsd = []
    options.NoiseRms = []
    options.SaturationRange = []
end
if isempty(sampleCount)
    sampleCount = 2048;
end
sampleCount = scalar(sampleCount, 'InvalidSampleCount', 1, true);
samplePeriod = scalar(samplePeriod, 'InvalidSamplePeriod', realmin, false);
options.EventCount = scalar(options.EventCount, 'InvalidEventCount', 1, true);
options.OnePeAmplitude = scalar(options.OnePeAmplitude, 'InvalidOnePeAmplitude', realmin, false);
options.ResponseTolerance = scalar(options.ResponseTolerance, 'InvalidResponseTolerance', realmin, false);
if options.ResponseTolerance >= 1
    fail('InvalidResponseTolerance', 'ResponseTolerance must be below one.');
end
options.MaximumParentSampleCount = scalar(options.MaximumParentSampleCount, 'ParentLimit', 1, true);
pretrigger = options.PretriggerSampleCount;
if isempty(pretrigger)
    pretrigger = floor(sampleCount / 2);
end
pretrigger = scalar(pretrigger, 'InvalidRegion', 0, true);
pedestalCount = scalar(options.PedestalSampleCount, 'InvalidRegion', 1, true);
guard = scalar(options.PedestalGuardSampleCount, 'InvalidRegion', 0, true);
if pretrigger >= sampleCount || pedestalCount + guard > pretrigger
    fail('InvalidRegion', 'Pedestal plus guard must fit strictly before the reference.');
end
response = prepareResponse(options);
burnIn = options.BurnInSampleCount;
if isempty(burnIn)
    burnIn = numel(response.impulse) - 1;
end
burnIn = scalar(burnIn, 'InvalidBurnIn', 0, true);
if burnIn < numel(response.impulse)-1
    fail('InvalidBurnIn', 'BurnInSampleCount is shorter than the validated response horizon.');
end
parentCount = 2 * (burnIn + max(pretrigger, sampleCount-pretrigger-1)) + 1;
if ~isfinite(parentCount) || parentCount > flintmax || ...
        parentCount > options.MaximumParentSampleCount / options.EventCount
    fail('ParentLimit', 'Parent samples across all rows exceed the configured limit.');
end
duration = parentCount * samplePeriod;
if ~isfinite(duration)
    fail('InvalidSamplePeriod', 'Parent duration must remain finite.');
end
reference = ceil(parentCount / 2);
crop = reference - pretrigger + (0:sampleCount-1);
injected = validateInjected(options, parentCount);
baseline = prepareBaseline(options, parentCount, reference);
saturationRange = validateSaturation(options.SaturationRange);
eventArgs = validateEventOptions(options, duration);
[stream, random] = resolveRandom(options);
[~, events] = pds.simulation.generateEventTrain(parentCount, samplePeriod, ...
    eventArgs{:}, EventCount=options.EventCount, ReferenceIndex=reference, ...
    ReferenceAmplitude=options.OnePeAmplitude, RandomStream=stream);
% generateEventTrain dark impulses are in PE; reference/large are amplitude units.
events.darkComponent = options.OnePeAmplitude * events.darkComponent;
events.darkEventAmplitudes = cellfun(@(x) options.OnePeAmplitude*x, ...
    events.darkEventAmplitudes, 'UniformOutput', false);
events.unsaturatedEventTrain = events.referenceComponent + ...
    events.darkComponent + events.largeEventComponent;
requireFinite(events);
impulses = struct('reference', events.referenceComponent, ...
    'dark', events.darkComponent, 'largeEvent', events.largeEventComponent);
classes = {'dark', 'largeEvent'};
for k = 1:size(injected, 1)
    name = classes{injected(k, 3)};
    row = injected(k, 1);
    column = injected(k, 2);
    impulses.(name)(row, column) = impulses.(name)(row, column) + injected(k, 4);
end
requireFinite(impulses);
names = fieldnames(impulses);
parent = struct();
components = struct();
arrivalMasks = struct();
filterStates = struct();
pedestalContamination = struct();
pedestal = (pretrigger - guard - pedestalCount + 1):(pretrigger - guard);
for k = 1:numel(names)
    name = names{k};
    [parent.components.(name), filterStates.(name)] = ...
        filterComponent(impulses.(name), response, crop(1));
    parent.arrivalMasks.(name) = impulses.(name) ~= 0;
    components.(name) = parent.components.(name)(:, crop);
    arrivalMasks.(name) = parent.arrivalMasks.(name)(:, crop);
    pedestalContamination.(name) = any( ...
        abs(components.(name)(:, pedestal)) > ...
        options.OnePeAmplitude * options.ResponseTolerance, 2);
end
parent.impulses = impulses;
parent.components.baseline = repmat(baseline, options.EventCount, 1);
if string(options.BaselineMode) == "wander"
    increments = double(options.BaselineWanderStepRms) * ...
        randn(stream, options.EventCount, parentCount-1);
    parent.components.baseline = parent.components.baseline + ...
        [zeros(options.EventCount, 1), cumsum(increments, 2)];
end
parent.components.noise = zeros(options.EventCount, parentCount);
noiseDiagnostics = struct();
if ~isempty(options.NoisePsd)
    [parent.components.noise, noiseDiagnostics] = ...
        pds.simulation.generateColoredNoise(parentCount, samplePeriod, ...
        NoisePsd=options.NoisePsd, TargetRms=options.NoiseRms, ...
        EventCount=options.EventCount, RandomStream=stream);
elseif ~isempty(options.NoiseRms)
    fail('InvalidNoise', 'NoiseRms requires an explicit parent-grid NoisePsd.');
end
components.baseline = parent.components.baseline(:, crop);
components.noise = parent.components.noise(:, crop);
waveforms = components.baseline + components.reference + ...
    components.dark + components.largeEvent + components.noise;
requireFinite(parent);
requireFinite(filterStates);
requireFinite(noiseDiagnostics);
requireFinite(waveforms);
preAdc = waveforms;
saturationMask = false(size(waveforms));
if ~isempty(saturationRange)
    saturationMask = waveforms < saturationRange(1) | waveforms > saturationRange(2);
    waveforms = min(max(waveforms, saturationRange(1)), saturationRange(2));
end
random.finalState = stream.State;
configuration = rmfield(options, 'RandomStream');
configuration.SampleCount = sampleCount;
configuration.SamplePeriod = samplePeriod;
truth = struct('noiseDiagnostics', noiseDiagnostics, 'random', random, 'referenceIndex', pretrigger + 1, ...
    'parentReferenceIndex', reference, 'parentSampleCount', parentCount, ...
    'cropIndices', crop, 'pedestalIndices', pedestal, ...
    'pedestalBaselineMean', finiteMean(components.baseline(:, pedestal)), ...
    'baselineAtReference', parent.components.baseline(:, reference), ...
    'response', response, 'burnInSampleCount', burnIn, ...
    'responsePeakIndex', pretrigger + response.peakIndex, ...
    'parentResponsePeakIndex', reference + response.peakIndex - 1, ...
    'filterStates', filterStates, 'parent', parent, 'components', components, ...
    'arrivalMasks', arrivalMasks, 'pedestalContamination', pedestalContamination, ...
    'eventTruth', events, 'injectedEvents', injected, ...
    'injectedEventProvenance', string(options.InjectedEventProvenance), ...
    'preAdc', preAdc, 'postAdc', waveforms, 'saturationMask', saturationMask, ...
    'saturationRange', saturationRange, 'configuration', configuration);
% Commit the private stream only after every validation/composition succeeds.
if ~isempty(options.RandomStream)
    options.RandomStream.State = stream.State;
end
end

function args = validateEventOptions(options, duration)
value = options.EventOptions;
allowed = {'SignalMultiplicityDistribution', 'SignalMultiplicity', ...
    'SignalMultiplicityLambda', 'SignalMultiplicitySupport', 'SignalMultiplicityPmf', ...
    'DarkRateHz', 'LargeEventRateHz', 'LargeAmplitudeDistribution', ...
    'LargeAmplitude', 'LargeAmplitudeRange'};
if ~isstruct(value) || ~isscalar(value) || ...
        any(~ismember(fieldnames(value), allowed))
    fail('InvalidEventOptions', ...
        'EventOptions must be scalar struct with exact nonreserved event option names.');
end
rates = {'DarkRateHz', 'LargeEventRateHz'};
expected = 0;
for k = 1:numel(rates)
    if ~isfield(value, rates{k})
        continue;
    end
    rate = value.(rates{k});
    % Invalid rates are rejected by generateEventTrain before its first draw.
    if isnumeric(rate) && isscalar(rate) && isreal(rate) && isfinite(rate) && rate >= 0
        expected = expected + double(rate) * duration * options.EventCount;
        if k == 2 && rate > 0
            amplitudeField = 'LargeAmplitude';
            if isfield(value, 'LargeAmplitudeDistribution') && ...
                    isequal(string(value.LargeAmplitudeDistribution), "uniform")
                amplitudeField = 'LargeAmplitudeRange';
            end
            if ~isfield(value, amplitudeField)
                fail('InvalidEventOptions', 'Enabled large events require explicit amplitude calibration.');
            end
        end
    end
end
if ~isfinite(expected) || expected > options.MaximumParentSampleCount
    fail('ParentLimit', 'Expected dark plus large arrivals exceed the configured parent budget.');
end
args = namedargs2cell(value);
end

function range = validateSaturation(range)
if isempty(range)
    range = [];
    return;
end
range = realVector(range, 'InvalidSaturationRange');
if numel(range) ~= 2 || range(1) >= range(2)
    fail('InvalidSaturationRange', 'SaturationRange must be a strictly increasing pair.');
end
end

function [stream, provenance] = resolveRandom(options)
stream = options.RandomStream;
seed = options.Seed;
if ~isempty(stream) && ~isempty(seed)
    fail('ConflictingRandomSource', 'Specify RandomStream or Seed, not both.');
end
if ~isempty(stream)
    if ~isa(stream, 'RandStream') || ~isscalar(stream)
        fail('InvalidRandomStream', 'RandomStream must be a scalar RandStream.');
    end
    if stream == RandStream.getGlobalStream
        fail('InvalidRandomStream', 'Supply a local stream, not the global RNG handle.');
    end
    source = "stream";
    original = stream;
    stream = RandStream.create(original.Type, 'NumStreams', original.NumStreams, ...
        'StreamIndices', original.StreamIndex, 'Seed', original.Seed);
    stream.NormalTransform = original.NormalTransform;
    stream.Antithetic = original.Antithetic;
    stream.FullPrecision = original.FullPrecision;
    if original.Substream ~= 1
        stream.Substream = original.Substream;
    end
    stream.State = original.State;
else
    if isempty(seed)
        seed = 0;
        source = "default-seed";
    else
        seed = scalar(seed, 'InvalidSeed', 0, true);
        if seed > 2^32-1
            fail('InvalidSeed', 'Seed must not exceed 2^32-1.');
        end
        source = "seed";
    end
    stream = RandStream('mt19937ar', 'Seed', seed);
end
provenance = struct('source', source, 'seed', seed, 'type', stream.Type, ...
    'initialState', stream.State, 'normalTransform', stream.NormalTransform, ...
    'antithetic', stream.Antithetic, 'fullPrecision', stream.FullPrecision, ...
    'settings', get(stream));
end

function baseline = prepareBaseline(options, parentCount, reference)
offset = scalar(options.BaselineOffset, 'InvalidBaseline', -realmax, false);
mode = options.BaselineMode;
if ~(isstring(mode) && isscalar(mode) || ischar(mode) && isrow(mode)) || ...
        ~any(string(mode) == ["constant", "slope", "step", "wander"])
    fail('InvalidBaseline', 'BaselineMode must be constant, slope, step, or wander.');
end
fields = {'BaselineSlopePerSample', 'BaselineStepAmplitude', ...
    'BaselineStepOffsetSamples', 'BaselineWanderStepRms'};
activeModes = ["slope", "step", "step", "wander"];
for k = 1:numel(fields)
    if ~isempty(options.(fields{k})) && string(mode) ~= activeModes(k)
        fail('InvalidBaseline', 'Baseline parameters must match the selected mode.');
    end
end
if string(mode) == "wander"
    scalar(options.BaselineWanderStepRms, 'InvalidBaseline', realmin, false);
end
baseline = offset * ones(1, parentCount);
if string(mode) == "slope"
    slope = scalar(options.BaselineSlopePerSample, 'InvalidBaseline', -realmax, false);
    baseline = baseline + slope*((1:parentCount)-reference);
elseif string(mode) == "step"
    amplitude = scalar(options.BaselineStepAmplitude, 'InvalidBaseline', -realmax, false);
    offsetSamples = scalar(options.BaselineStepOffsetSamples, 'InvalidBaseline', -flintmax, false);
    index = reference + offsetSamples;
    if offsetSamples ~= fix(offsetSamples) || index < 1 || index > parentCount
        fail('InvalidBaseline', 'Step offset must identify an integer parent sample.');
    end
    baseline(index:end) = baseline(index:end) + amplitude;
end
if any(~isfinite(baseline))
    fail('InvalidBaseline', 'Baseline arithmetic overflowed.');
end
end

function injected = validateInjected(options, parentCount)
injected = options.InjectedEvents;
provenance = options.InjectedEventProvenance;
if ~(isstring(provenance) && isscalar(provenance) || ...
        ischar(provenance) && (isrow(provenance) || isempty(provenance))) || ...
        ismissing(string(provenance))
    fail('InvalidInjectedEvents', 'InjectedEventProvenance must be nonmissing scalar text.');
end
if isempty(injected)
    injected = zeros(0, 4);
    return;
end
if ~isnumeric(injected) || issparse(injected) || ~isreal(injected) || ...
        ~ismatrix(injected) || size(injected, 2) ~= 4 || ...
        any(~isfinite(injected(:)))
    fail('InvalidInjectedEvents', 'InjectedEvents must be finite [row parentIndex class amplitude] rows.');
end
validateExactInteger(injected, 'InvalidInjectedEvents');
injected = double(injected);
if any(injected(:, 1) < 1 | injected(:, 1) > options.EventCount) || ...
        any(injected(:, 2) < 1 | injected(:, 2) > parentCount) || ...
        any(injected(:, 1:3) ~= fix(injected(:, 1:3)), 'all') || ...
        any(~ismember(injected(:, 3), [1 2])) || any(injected(:, 4) <= 0) || ...
        any(injected(injected(:, 3)==1, 4) ~= options.OnePeAmplitude)
    fail('InvalidInjectedEvents', 'Indices/classes or amplitudes are invalid; a dark arrival is exactly one PE.');
end
if ~(isstring(options.InjectedEventProvenance) && isscalar(options.InjectedEventProvenance) || ...
        ischar(options.InjectedEventProvenance) && isrow(options.InjectedEventProvenance)) || ...
        strlength(strtrim(string(options.InjectedEventProvenance))) == 0
    fail('InvalidInjectedEvents', 'Deterministic additions require explicit provenance.');
end
end

function [component, states] = filterComponent(impulses, response, cropStart)
order = max(numel(response.numerator), numel(response.denominator))-1;
initial = zeros(size(impulses, 1), order);
[component, final] = filter(response.numerator, response.denominator, ...
    impulses.', initial.', 1);
component = component.';
atCrop = initial.';
if cropStart > 1
    [~, atCrop] = filter(response.numerator, response.denominator, ...
        impulses(:, 1:cropStart-1).', initial.', 1);
end
states = struct('initial', initial, 'atCrop', atCrop.', 'final', final.');
end

function response = prepareResponse(options)
b = realVector(options.ResponseNumerator, 'InvalidResponse');
a = realVector(options.ResponseDenominator, 'InvalidResponse');
if a(1) == 0 || ~any(b)
    fail('InvalidResponse', 'Response must be causal with nonzero gain and denominator lead.');
end
b = b / a(1);
a = a / a(1);
if any(~isfinite([a b]))
    fail('InvalidResponse', 'Coefficient normalization must remain finite.');
end
poles = roots(a);
radius = max([0; abs(poles)]);
if radius >= 1
    fail('InvalidResponse', 'All response poles must be strictly inside the unit circle.');
end
horizon = numel(b);
if radius > 0
    horizon = max(horizon, numel(b) + ...
        ceil(log(options.ResponseTolerance * 1e-3) / log(radius)) * ...
        max(1, numel(a)-1));
end
while true
    if ~isfinite(horizon) || horizon > options.MaximumParentSampleCount / 2
        fail('ParentLimit', 'Response settling horizon exceeds the configured limit.');
    end
    impulse = filter(b, a, [1 zeros(1, horizon-1)]);
    [peak, peakIndex] = max(abs(impulse));
    if ~isfinite(peak) || peak == 0 || any(~isfinite(impulse))
        fail('InvalidResponse', 'Response impulse must have a finite nonzero peak.');
    end
    terminalPeak = max(abs(impulse(max(1, floor(.75*horizon)):end))) / peak;
    if radius == 0 || terminalPeak <= options.ResponseTolerance
        break;
    end
    horizon = 2 * horizon;
end
response = struct('numerator', b/peak, 'denominator', a, ...
    'impulse', impulse/peak, 'peakMagnitude', peak, 'peakIndex', peakIndex, ...
    'poles', poles, 'poleRadius', radius, 'terminalRelativePeak', terminalPeak, ...
    'tolerance', options.ResponseTolerance);
end

function value = realVector(value, identifier)
if ~isnumeric(value) || issparse(value) || ~isreal(value) || ~isvector(value) || ...
        isempty(value) || any(~isfinite(value(:)))
    fail(identifier, 'Expected a nonempty finite real numeric vector.');
end
validateExactInteger(value, identifier);
value = double(value(:).');
end

function value = scalar(value, identifier, minimum, integer)
if ~isnumeric(value) || issparse(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isfinite(value) || value < minimum || ...
        integer && (value ~= fix(value) || value > flintmax)
    fail(identifier, 'Expected a finite real scalar in the documented range.');
end
validateExactInteger(value, identifier);
value = double(value);
end

function value = finiteMean(samples)
value = mean(samples, 2);
bad = ~isfinite(value);
if any(bad)
    scale = max(abs(samples(bad, :)), [], 2);
    value(bad) = mean(samples(bad, :) ./ scale, 2) .* scale;
end
requireFinite(value);
end

function requireFinite(value)
if isstruct(value)
    names = fieldnames(value);
    for k = 1:numel(names)
        requireFinite(value.(names{k}));
    end
elseif iscell(value)
    for k = 1:numel(value)
        requireFinite(value{k});
    end
elseif isnumeric(value) && any(~isfinite(value(:)))
    fail('NumericOverflow', 'Simulation arithmetic must remain finite before saturation.');
end
end

function validateExactInteger(value, identifier)
if isa(value, 'uint64')
    unsafe = any(value(:) > uint64(flintmax));
elseif isa(value, 'int64')
    limit = int64(flintmax);
    unsafe = any(value(:) > limit | value(:) < -limit);
else
    unsafe = false;
end
if unsafe
    fail(identifier, 'Integer inputs must lie in the contiguous exact double range.');
end
end

function fail(identifier, message)
error(['pds:simulation:simulatePedestalStressWaveforms:' identifier], '%s', message);
end
