function lineHandle = plotSpectrum(spectrum, options)
%PLOTSPECTRUM Plot amplitude or PSD without changing computed results.
%   pds.plotting.plotSpectrum(S) plots S.amplitudeMean in linear units.
%
%   Quantity is "amplitude" or "psd". Scale is "linear" or "decibel".
%   Decibel conversion always uses the explicit positive ReferenceValue:
%   amplitude uses 20*log10(A/ref), while PSD uses
%   10*log10(PSD/ref^2). MinimumDecibels optionally floors displayed zeros;
%   its default -Inf preserves the mathematical result. Normalize="peak"
%   normalizes the selected linear quantity before any dB conversion.
%   FrequencyUnit selects display in Hz (default) or MHz.
arguments
    spectrum (1,1) struct
    options.Quantity (1,1) string ...
        {mustBeMember(options.Quantity, ["amplitude", "psd"])} = "amplitude"
    options.Scale (1,1) string ...
        {mustBeMember(options.Scale, ["linear", "decibel"])} = "linear"
    options.ReferenceValue (1,1) double {mustBePositive, mustBeFinite} = 1
    options.ReferenceLabel (1,1) string = ""
    options.FrequencyUnit (1,1) string {mustBeMember(options.FrequencyUnit,["Hz","MHz"])} = "Hz"
    options.Normalize (1,1) string ...
        {mustBeMember(options.Normalize, ["none", "peak"])} = "none"
    options.MinimumDecibels (1,1) double = -Inf
    options.Axes = []
end

if isempty(options.Axes)
    axesHandle = axes(figure());
else
    axesHandle = options.Axes;
    if ~isgraphics(axesHandle, 'axes')
        error('pds:plotting:plotSpectrum:InvalidAxes', ...
            'Axes must be a valid MATLAB axes handle.');
    end
end

if options.Quantity == "amplitude"
    plotData = spectrum.amplitudeMean;
    decibelFactor = 20;
    referenceForQuantity = options.ReferenceValue;
    linearLabel = sprintf('Amplitude (%s)', spectrum.inputUnit);
    quantityName = 'Amplitude';
else
    plotData = spectrum.psdMean;
    decibelFactor = 10;
    referenceForQuantity = options.ReferenceValue^2;
    linearLabel = sprintf('PSD (%s^2/Hz)', spectrum.inputUnit);
    quantityName = 'PSD';
end

if options.Normalize == "peak"
    peakValue = max(plotData);
    if peakValue <= 0
        error('pds:plotting:plotSpectrum:ZeroPeak', ...
            'Peak normalization requires at least one positive value.');
    end
    plotData = plotData / peakValue;
end

if options.Scale == "decibel"
    plotData = decibelFactor * log10(plotData / referenceForQuantity);
    plotData = max(plotData, options.MinimumDecibels);
end

frequency = spectrum.frequencyHz;
if options.FrequencyUnit == "MHz"
    frequency = frequency/1e6;
end
lineHandle = plot(axesHandle, frequency, plotData);
xlabel(axesHandle, sprintf('Frequency (%s)',options.FrequencyUnit));
if options.Scale == "decibel"
    if options.ReferenceLabel == ""
        referenceLabel = sprintf('dB re %g %s', ...
            options.ReferenceValue, spectrum.inputUnit);
    else
        referenceLabel = options.ReferenceLabel;
    end
    ylabel(axesHandle, sprintf('%s (%s)', quantityName, referenceLabel));
else
    ylabel(axesHandle, linearLabel);
end
grid(axesHandle, 'on');
end
