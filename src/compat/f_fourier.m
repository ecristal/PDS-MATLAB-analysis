function [frequencyHz, amplitude, complexMean, psd, rmsPerRecord] = ...
    f_fourier(waveforms, samplePeriod, doPlot, yLabel, normalize)
%F_FOURIER Compatibility wrapper for the legacy Fourier-analysis API.
%   New numerical code should call pds.signal.computeSpectrum directly.
%   This wrapper preserves legacy call arity, RMS row orientation, numeric
%   0/1 flags, and the historical plotting/normalization branch.

if nargin < 3 || isempty(doPlot)
    doPlot = false;
end
if nargin < 4 || isempty(yLabel)
    yLabel = "abs";
end
if nargin < 5 || isempty(normalize)
    normalize = false;
end

yLabel = string(yLabel);
if ~isscalar(yLabel) || ~any(strcmpi(yLabel, ["abs", "dBFS"]))
    error('PDS:f_fourier:InvalidLabel', ...
        'yLabel must be "abs" or "dBFS".');
end
isValidDoPlot = isscalar(doPlot) && (islogical(doPlot) || ...
    (isnumeric(doPlot) && isreal(doPlot) && isfinite(doPlot) && ...
     (doPlot == 0 || doPlot == 1)));
if ~isValidDoPlot
    error('PDS:f_fourier:InvalidDoPlot', ...
        'doPlot must be logical or numeric 0/1.');
end
isValidNormalize = isscalar(normalize) && (islogical(normalize) || ...
    (isnumeric(normalize) && isreal(normalize) && isfinite(normalize) && ...
     (normalize == 0 || normalize == 1)));
if ~isValidNormalize
    error('PDS:f_fourier:InvalidNormalize', ...
        'normalize must be logical or numeric 0/1.');
end
doPlot = logical(doPlot);
normalize = logical(normalize);

warning('PDS:f_fourier:Deprecated', ...
    ['f_fourier is a compatibility wrapper. Use ', ...
     'pds.signal.computeSpectrum for new analyses.']);

spectrum = pds.signal.computeSpectrum(waveforms, samplePeriod);
frequencyHz = spectrum.frequencyHz;
amplitude = spectrum.amplitudeMean;
complexMean = spectrum.complexMean;
psd = spectrum.psdMean;
rmsPerRecord = spectrum.rmsPerRecord.';

if strcmpi(yLabel, "dBFS")
    amplitude = 20 * log10(amplitude / 2^14);
end
yLabelText = yLabel;

if doPlot
    figure(3);
    if normalize
        amplitude = amplitude / max(amplitude);
        semilogx(frequencyHz, 20 * log10(amplitude));
    else
        semilogx(frequencyHz, amplitude);
    end
    title('Single-Sided Amplitude Spectrum of X(t)', ...
        'Interpreter', 'latex', 'FontSize', 14);
    xlabel('f [Hz]', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel(yLabelText, 'Interpreter', 'latex', 'FontSize', 12);
    grid on;
end
end
