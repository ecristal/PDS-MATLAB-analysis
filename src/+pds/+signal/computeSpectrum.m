function spectrum = computeSpectrum(waveforms, samplePeriod, options)
%COMPUTESPECTRUM Compute averaged amplitude, PSD, coherent FFT, and RMS.
%   S = pds.signal.computeSpectrum(WAVEFORMS, SAMPLEPERIOD) treats each row
%   of WAVEFORMS as one record and samples along the second dimension. A
%   vector, row or column, is treated as one record.
%
%   Name-value options:
%     RemoveMean - subtract each record mean before the FFT (default false)
%     Sidedness  - "one-sided" (default) or "two-sided" in FFT order
%     InputUnit  - metadata used for labels, for example "ADU" or "V"
%
%   S contains frequencyHz, amplitudeMean, psdMean, complexMean,
%   rmsPerRecord, sampling metadata, sidedness, units, and meanRemoved.
%   Amplitude and PSD remain linear. Use pds.plotting.plotSpectrum for dB
%   conversion with an explicit reference.
arguments
    waveforms {mustBeNumeric, mustBeNonempty}
    samplePeriod (1,1) double {mustBePositive, mustBeFinite}
    options.RemoveMean (1,1) logical = false
    options.Sidedness (1,1) string ...
        {mustBeMember(options.Sidedness, ["one-sided", "two-sided"])} = "one-sided"
    options.InputUnit (1,1) string = "ADU"
end

if ~ismatrix(waveforms)
    error('pds:signal:computeSpectrum:WaveformDimensions', ...
        'Waveforms must be a vector or a two-dimensional records-by-samples matrix.');
end
if any(~isfinite(double(waveforms(:))))
    error('pds:signal:computeSpectrum:NonfiniteWaveforms', ...
        'Waveforms must contain only finite values.');
end
if ~isreal(waveforms)
    error('pds:signal:computeSpectrum:NonrealWaveforms', ...
        'One- and two-sided waveform spectra require real-valued input.');
end

if isvector(waveforms)
    waveforms = waveforms(:).';
end
waveforms = double(waveforms);
if size(waveforms, 2) < 2
    error('pds:signal:computeSpectrum:TooFewSamples', ...
        'Each waveform must contain at least two samples.');
end
if options.RemoveMean
    waveforms = waveforms - mean(waveforms, 2);
end

[recordCount, sampleCount] = size(waveforms);
sampleRateHz = 1 / samplePeriod;
frequencyResolutionHz = sampleRateHz / sampleCount;
complexSpectrum = fft(waveforms, [], 2);

if options.Sidedness == "one-sided"
    oneSidedBinCount = floor(sampleCount / 2) + 1;
    selectedSpectrum = complexSpectrum(:, 1:oneSidedBinCount);
    frequencyHz = frequencyResolutionHz * (0:(oneSidedBinCount - 1));

    doublingFactor = 2 * ones(1, oneSidedBinCount);
    doublingFactor(1) = 1;
    if mod(sampleCount, 2) == 0
        doublingFactor(end) = 1;
    end

    amplitudePerRecord = abs(selectedSpectrum) / sampleCount .* doublingFactor;
    psdPerRecord = abs(selectedSpectrum).^2 / ...
        (sampleCount * sampleRateHz) .* doublingFactor;
else
    frequencyBins = 0:(sampleCount - 1);
    firstNegativeBin = floor(sampleCount / 2) + 2;
    frequencyBins(firstNegativeBin:end) = ...
        frequencyBins(firstNegativeBin:end) - sampleCount;
    frequencyHz = frequencyResolutionHz * frequencyBins;

    amplitudePerRecord = abs(complexSpectrum) / sampleCount;
    psdPerRecord = abs(complexSpectrum).^2 / (sampleCount * sampleRateHz);
end

amplitudeMean = mean(amplitudePerRecord, 1);
psdMean = mean(psdPerRecord, 1);
rmsPerRecord = sqrt(sum(psdPerRecord, 2) * frequencyResolutionHz);

spectrum = struct( ...
    'frequencyHz', frequencyHz, ...
    'amplitudeMean', amplitudeMean, ...
    'psdMean', psdMean, ...
    'complexMean', mean(complexSpectrum, 1), ...
    'rmsPerRecord', rmsPerRecord, ...
    'samplePeriod', samplePeriod, ...
    'sampleRateHz', sampleRateHz, ...
    'sampleCount', sampleCount, ...
    'recordCount', recordCount, ...
    'inputUnit', options.InputUnit, ...
    'sidedness', options.Sidedness, ...
    'meanRemoved', options.RemoveMean);
end
