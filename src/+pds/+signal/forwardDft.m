function [coefficients, frequencyHz] = forwardDft(waveform, samplePeriod, options)
%FORWARDDFT Compute a bilateral discrete Fourier transform in FFT order.
%   [COEFFICIENTS, FREQUENCYHZ] = pds.signal.forwardDft(WAVEFORM,
%   SAMPLEPERIOD) returns FFT coefficients and the corresponding bilateral
%   frequency vector. SAMPLEPERIOD is expressed in seconds.
%
%   Name-value options:
%     Window      - Numeric window with one coefficient per sample. The
%                   window is multiplied by the waveform before the DFT.
%     SampleShift - Integer circular delay in samples applied before the
%                   transform. Positive values delay the waveform.

    arguments
        waveform
        samplePeriod
        options.Window = []
        options.SampleShift = 0
    end

    if ~isnumeric(waveform) || ~isvector(waveform) || isempty(waveform)
        error('pds:signal:forwardDft:WaveformDimensions', ...
            'Waveform must be a nonempty numeric vector.');
    end
    if numel(waveform) < 2
        error('pds:signal:forwardDft:TooFewSamples', ...
            'Waveform must contain at least two samples.');
    end
    if any(~isfinite(waveform(:)))
        error('pds:signal:forwardDft:NonfiniteWaveform', ...
            'Waveform samples must be finite.');
    end
    if ~isnumeric(samplePeriod) || ~isscalar(samplePeriod) || ...
            ~isreal(samplePeriod) || ~isfinite(samplePeriod) || samplePeriod <= 0
        error('pds:signal:forwardDft:InvalidSamplePeriod', ...
            'Sample period must be a finite positive real scalar.');
    end
    if ~isnumeric(options.SampleShift) || ~isscalar(options.SampleShift) || ...
            ~isreal(options.SampleShift) || ~isfinite(options.SampleShift) || ...
            options.SampleShift ~= fix(options.SampleShift)
        error('pds:signal:forwardDft:InvalidSampleShift', ...
            'SampleShift must be a finite integer scalar.');
    end

    samplePeriod = double(samplePeriod);
    sampleShift = double(options.SampleShift);
    waveform = double(waveform(:).');
    sampleCount = numel(waveform);

    if isempty(options.Window)
        window = ones(1, sampleCount);
    else
        window = options.Window;
        if ~isnumeric(window) || ~isvector(window) || numel(window) ~= sampleCount
            error('pds:signal:forwardDft:WindowLength', ...
                'Window must be a numeric vector with one value per sample.');
        end
        window = double(window(:).');
        if ~isreal(window) || any(~isfinite(window)) || sum(abs(window).^2) == 0
            error('pds:signal:forwardDft:InvalidWindow', ...
                'Window must contain finite real coefficients and nonzero energy.');
        end
    end

    windowedWaveform = waveform .* window;
    if sampleShift ~= 0
        windowedWaveform = circshift(windowedWaveform, sampleShift);
    end
    coefficients = fft(windowedWaveform);

    sampleRateHz = 1 / samplePeriod;
    positiveBins = 0:floor(sampleCount / 2);
    negativeBins = (-ceil(sampleCount / 2) + 1):-1;
    frequencyHz = [positiveBins, negativeBins] * (sampleRateHz / sampleCount);
end
