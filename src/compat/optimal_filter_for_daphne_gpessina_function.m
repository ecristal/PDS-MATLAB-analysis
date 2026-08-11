function filterCoefficients = optimal_filter_for_daphne_gpessina_function( ...
        signalWaveforms, noiseWaveforms, applyDecimation, decimationFactor, ...
        isInverted, applyLowPass, useNoise, pedestalSampleCount)
%OPTIMAL_FILTER_FOR_DAPHNE_GPESSINA_FUNCTION Deprecated compatibility wrapper.
%   Use pds.signal.designOptimalFilter for new code. This wrapper accepts the
%   historical five-through-eight-input forms and returns corrected,
%   unit-gain FIR coefficients without creating figures. Historical implicit
%   low-pass/"decimation" branches are rejected rather than silently ignored.

    warning('PDS:optimal_filter:Deprecated', ...
        ['optimal_filter_for_daphne_gpessina_function is deprecated. ', ...
         'Use pds.signal.designOptimalFilter instead.']);

    if nargin < 5
        error('PDS:optimal_filter:NotEnoughInputs', ...
            'At least five historical inputs are required.');
    end
    if nargin < 6
        applyLowPass = false;
    end
    if nargin < 7
        useNoise = true;
    end
    if nargin < 8
        pedestalSampleCount = 200;
    end

    applyDecimation = validateFlag(applyDecimation, 'applyDecimation');
    isInverted = validateFlag(isInverted, 'isInverted');
    applyLowPass = validateFlag(applyLowPass, 'applyLowPass');
    useNoise = validateFlag(useNoise, 'useNoise');

    if ~isnumeric(signalWaveforms) || isempty(signalWaveforms) || ...
            ~ismatrix(signalWaveforms) || ~isreal(signalWaveforms) || ...
            any(~isfinite(signalWaveforms(:)))
        error('PDS:optimal_filter:InvalidSignalWaveforms', ...
            'signalWaveforms must contain finite real waveform records.');
    end
    if isvector(signalWaveforms)
        referenceSignal = signalWaveforms(:).';
    else
        referenceSignal = mean(signalWaveforms, 1);
    end
    if isInverted
        referenceSignal = -referenceSignal;
    end

    if applyDecimation
        error('PDS:optimal_filter:UnsupportedDecimation', ...
            ['The historical apply_decimation branch applied an implicit ', ...
             'low-pass operation but did not decimate. It is not reproduced ', ...
             'by the corrected wrapper (decimationFactor=%g).'], ...
            decimationFactor);
    end
    if applyLowPass
        error('PDS:optimal_filter:UnsupportedLowPass', ...
            ['The historical Butterworth preprocessing is not part of the ', ...
             'corrected optimal-filter core. Apply an explicit, documented ', ...
             'preprocessing stage before calling the new API.']);
    end

    if useNoise
        if isempty(noiseWaveforms)
            warning('PDS:optimal_filter:MissingNoise', ...
                'useNoise was true but noiseWaveforms is empty; using white noise.');
            noiseModel = "white";
        else
            noiseModel = "measured";
        end
    else
        noiseModel = "white";
        noiseWaveforms = [];
    end

    filterCoefficients = pds.signal.designOptimalFilter( ...
        referenceSignal, noiseWaveforms, SamplePeriod=16e-9, ...
        PedestalSampleCount=pedestalSampleCount, NoiseModel=noiseModel, ...
        Window="tukey", TukeyRatio=0.1);
end

function flag = validateFlag(value, label)
    if islogical(value) && isscalar(value)
        flag = value;
        return;
    end
    if isnumeric(value) && isscalar(value) && isreal(value) && ...
            isfinite(value) && (value == 0 || value == 1)
        flag = logical(value);
        return;
    end
    error('PDS:optimal_filter:InvalidFlag', ...
        '%s must be a logical scalar or numeric 0/1.', label);
end
