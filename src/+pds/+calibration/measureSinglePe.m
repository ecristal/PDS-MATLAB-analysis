function [amplitude,range,headroom,extrema,speMean,rawAmplitude] = measureSinglePe( ...
    speMeanRaw,baselineMedian,polarity,peakSample,options)
%MEASURESINGLEPE Measure filtered SPE dynamic range and raw ADC headroom.
% Applying the causal notch to the mean is equivalent to averaging records
% filtered independently with the same zero initial state.
arguments
    speMeanRaw (1,:) double {mustBeNonempty}
    baselineMedian (1,1) double
    polarity (1,1) double {mustBeMember(polarity,[-1,1])}
    peakSample (1,1) double {mustBePositive,mustBeInteger}
    options.FilterNumerator (1,:) double {mustBeFinite,mustBeNonempty} = 1
    options.FilterDenominator (1,:) double {mustBeFinite,mustBeNonempty} = 1
    options.AdcBits (1,1) double {mustBePositive,mustBeInteger} = 14
    options.Window (1,2) double {mustBeNonnegative,mustBeInteger} = [100 200]
end
assert(peakSample<=numel(speMeanRaw),'Peak sample is outside the waveform.');
speMean = filter(options.FilterNumerator,options.FilterDenominator,speMeanRaw);
indices = max(1,peakSample-options.Window(1)):min(numel(speMean),peakSample+options.Window(2));
extrema = [min(speMean(indices)),max(speMean(indices))];
rawExtrema = [min(speMeanRaw(indices)),max(speMeanRaw(indices))];
amplitude = diff(extrema);
rawAmplitude = diff(rawExtrema);
range = NaN;
headroom = NaN;
if amplitude>0
    range = 2^options.AdcBits/amplitude;
end
if rawAmplitude>0
    native = sort(polarity*rawExtrema);
    headroom = min((2^options.AdcBits-1-baselineMedian)/max(eps,native(2)), ...
        baselineMedian/max(eps,-native(1)));
end
end
