function [noisePsd, frequencyHz, info] = estimateNoisePsd(noiseWaveforms, samplePeriod, options)
%ESTIMATENOISEPSD Estimate a bilateral noise PSD from waveform records.
%   PSD = pds.signal.estimateNoisePsd(NOISE, SAMPLEPERIOD) treats rows as
%   records and columns as samples. Vectors represent one record. The PSD is
%   returned with N bins in FFT order and units of input-unit^2/Hz.
%
%   Window can be "rectangular", "tukey", "hann", "hamming", or a
%   numeric vector. Tukey is the default. PSD normalization uses
%   Fs*sum(window.^2), which accounts explicitly for window power.

    arguments
        noiseWaveforms
        samplePeriod
        options.Window = "tukey"
        options.TukeyRatio = 0.1
        options.RemoveMean = true
    end

    if ~isnumeric(noiseWaveforms) || isempty(noiseWaveforms) || ~ismatrix(noiseWaveforms)
        error('pds:signal:estimateNoisePsd:NoiseDimensions', ...
            'Noise waveforms must be a nonempty numeric vector or matrix.');
    end
    if ~isreal(noiseWaveforms)
        error('pds:signal:estimateNoisePsd:NonrealNoise', ...
            'Noise waveforms must be real.');
    end
    if any(~isfinite(noiseWaveforms(:)))
        error('pds:signal:estimateNoisePsd:NonfiniteNoise', ...
            'Noise waveforms must contain only finite samples.');
    end
    if ~isnumeric(samplePeriod) || ~isscalar(samplePeriod) || ...
            ~isreal(samplePeriod) || ~isfinite(samplePeriod) || samplePeriod <= 0
        error('pds:signal:estimateNoisePsd:InvalidSamplePeriod', ...
            'Sample period must be a finite positive real scalar.');
    end
    if ~(islogical(options.RemoveMean) && isscalar(options.RemoveMean))
        error('pds:signal:estimateNoisePsd:InvalidRemoveMean', ...
            'RemoveMean must be a logical scalar.');
    end

    samplePeriod = double(samplePeriod);
    tukeyRatio = double(options.TukeyRatio);
    if isvector(noiseWaveforms)
        noiseWaveforms = double(noiseWaveforms(:).');
    else
        noiseWaveforms = double(noiseWaveforms);
    end
    [recordCount, sampleCount] = size(noiseWaveforms);
    if sampleCount < 2
        error('pds:signal:estimateNoisePsd:TooFewSamples', ...
            'Each noise record must contain at least two samples.');
    end

    window = pds.signal.createWindow(sampleCount, options.Window, ...
        TukeyRatio=tukeyRatio);
    if options.RemoveMean
        noiseWaveforms = noiseWaveforms - mean(noiseWaveforms, 2);
    end

    windowedNoise = noiseWaveforms .* window;
    sampleRateHz = 1 / samplePeriod;
    windowPower = sum(window.^2);
    coefficients = fft(windowedNoise, [], 2);
    psdPerRecord = abs(coefficients).^2 / (sampleRateHz * windowPower);
    noisePsd = mean(psdPerRecord, 1);

    positiveBins = 0:floor(sampleCount / 2);
    negativeBins = (-ceil(sampleCount / 2) + 1):-1;
    frequencyHz = [positiveBins, negativeBins] * (sampleRateHz / sampleCount);

    if isnumeric(options.Window)
        windowName = "custom";
    else
        windowName = lower(string(options.Window));
        if windowName == "none"
            windowName = "rectangular";
        end
    end
    info = struct( ...
        'recordCount', recordCount, ...
        'sampleCount', sampleCount, ...
        'samplePeriod', samplePeriod, ...
        'sampleRateHz', sampleRateHz, ...
        'frequencyResolutionHz', sampleRateHz / sampleCount, ...
        'window', window, ...
        'windowName', windowName, ...
        'windowPower', windowPower, ...
        'tukeyRatio', tukeyRatio, ...
        'meanRemoved', options.RemoveMean, ...
        'psdPerRecord', psdPerRecord);
end
