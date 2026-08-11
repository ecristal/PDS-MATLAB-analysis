function [filterCoefficients, diagnostics] = designOptimalFilter(referenceSignal, noiseWaveforms, options)
%DESIGNOPTIMALFILTER Design a unit-gain FIR matched/optimal filter.
%   [B, INFO] = pds.signal.designOptimalFilter(REFERENCE, NOISE) designs a
%   filter for an aligned real reference waveform. Rows of NOISE are noise
%   records. B is a causal FIR vector whose final output sample is the
%   amplitude estimate for an aligned record.
%
%   NoiseModel supports:
%     "auto"       - measured when NOISE is supplied, estimated when
%                    requested, otherwise white;
%     "white"      - flat unit PSD;
%     "measured"   - windowed bilateral PSD from NOISE;
%     "estimated"  - select pedestal events from CandidateWaveforms;
%     "provided"   - use the bilateral N-bin NoisePsd option;
%     "parametric" - AR(1) or power-law colored PSD.
%
%   Measured PSD estimates use a configurable Tukey/Hann/Hamming/custom
%   window and explicit window-power normalization. Regularization floors
%   small PSD bins before spectral whitening.

    arguments
        referenceSignal
        noiseWaveforms = []
        options.SamplePeriod = 16e-9
        options.PedestalSampleCount = []
        options.NoiseModel = "auto"
        options.NoisePsd = []
        options.ColoredNoiseModel = "ar1"
        options.ArCoefficient = 0.9
        options.PowerLawExponent = 1
        options.PowerLawCornerFrequencyHz = []
        options.Window = "tukey"
        options.TukeyRatio = 0.1
        options.RegularizationFraction = 1e-6
        options.EstimateNoiseFromSignals = false
        options.CandidateWaveforms = []
        options.NoiseSelectionSigma = 2
    end

    validateReference(referenceSignal);
    referenceSignal = double(referenceSignal(:).');
    sampleCount = numel(referenceSignal);
    validatePositiveScalar(options.SamplePeriod, ...
        'pds:signal:designOptimalFilter:InvalidSamplePeriod', 'SamplePeriod');
    samplePeriod = double(options.SamplePeriod);
    pedestalSampleCount = resolvePedestalSampleCount( ...
        options.PedestalSampleCount, sampleCount);
    validatePositiveScalar(options.RegularizationFraction, ...
        'pds:signal:designOptimalFilter:InvalidRegularization', ...
        'RegularizationFraction');
    regularizationFraction = double(options.RegularizationFraction);
    if regularizationFraction > 1
        error('pds:signal:designOptimalFilter:InvalidRegularization', ...
            'RegularizationFraction must be in (0,1].');
    end
    if ~(islogical(options.EstimateNoiseFromSignals) && ...
            isscalar(options.EstimateNoiseFromSignals))
        error('pds:signal:designOptimalFilter:InvalidEstimateNoiseFlag', ...
            'EstimateNoiseFromSignals must be a logical scalar.');
    end
    validatePositiveScalar(options.NoiseSelectionSigma, ...
        'pds:signal:designOptimalFilter:InvalidNoiseSelectionSigma', ...
        'NoiseSelectionSigma');
    noiseSelectionSigma = double(options.NoiseSelectionSigma);
    tukeyRatio = double(options.TukeyRatio);

    template = removePedestal(referenceSignal, pedestalSampleCount);
    if norm(template) == 0
        error('pds:signal:designOptimalFilter:DegenerateTemplate', ...
            'Reference signal is zero after pedestal removal.');
    end

    requestedModel = lower(string(options.NoiseModel));
    if ~isscalar(requestedModel)
        error('pds:signal:designOptimalFilter:UnknownNoiseModel', ...
            'NoiseModel must be a scalar string.');
    end
    noiseModel = resolveNoiseModel(requestedModel, noiseWaveforms, ...
        options.CandidateWaveforms, options.EstimateNoiseFromSignals);

    preliminary = struct('scores', [], 'mask', [], 'mean', NaN, 'sigma', NaN);
    psdInfo = struct();
    coloredNoiseModel = "none";

    switch noiseModel
        case "white"
            noisePsd = ones(1, sampleCount);
            frequencyHz = fftFrequencyAxis(sampleCount, samplePeriod);
            noiseSource = "white";
        case "measured"
            validateWaveformMatrix(noiseWaveforms, sampleCount, 'Noise');
            centeredNoise = removeWaveformPedestals(noiseWaveforms, pedestalSampleCount);
            [noisePsd, frequencyHz, psdInfo] = pds.signal.estimateNoisePsd( ...
                centeredNoise, samplePeriod, Window=options.Window, ...
                TukeyRatio=tukeyRatio, RemoveMean=false);
            noiseSource = "measured";
        case "provided"
            noisePsd = validateProvidedPsd(options.NoisePsd, sampleCount);
            frequencyHz = fftFrequencyAxis(sampleCount, samplePeriod);
            noiseSource = "provided";
        case "parametric"
            [noisePsd, frequencyHz, coloredNoiseModel] = parametricNoisePsd( ...
                sampleCount, samplePeriod, options.ColoredNoiseModel, ...
                options.ArCoefficient, options.PowerLawExponent, ...
                options.PowerLawCornerFrequencyHz);
            noiseSource = "parametric";
        case "estimated"
            validateWaveformMatrix(options.CandidateWaveforms, sampleCount, ...
                'CandidateWaveforms');
            [preliminaryCoefficients, ~] = pds.signal.designOptimalFilter( ...
                referenceSignal, [], SamplePeriod=samplePeriod, ...
                PedestalSampleCount=pedestalSampleCount, NoiseModel="white", ...
                RegularizationFraction=regularizationFraction);
            preliminary.scores = pds.signal.applyOptimalFilter( ...
                options.CandidateWaveforms, preliminaryCoefficients, ...
                PedestalSampleCount=pedestalSampleCount);
            [preliminary.mean, preliminary.sigma, preliminary.mask] = ...
                estimatePedestalPeak(preliminary.scores, noiseSelectionSigma);
            selectedNoise = options.CandidateWaveforms(preliminary.mask, :);
            minimumRecords = max(8, ceil(0.01 * size(options.CandidateWaveforms, 1)));
            if size(selectedNoise, 1) < minimumRecords
                error('pds:signal:designOptimalFilter:InsufficientEstimatedNoise', ...
                    'Only %d pedestal records were selected; at least %d are required.', ...
                    size(selectedNoise, 1), minimumRecords);
            end
            centeredNoise = removeWaveformPedestals(selectedNoise, pedestalSampleCount);
            [noisePsd, frequencyHz, psdInfo] = pds.signal.estimateNoisePsd( ...
                centeredNoise, samplePeriod, Window=options.Window, ...
                TukeyRatio=tukeyRatio, RemoveMean=false);
            noiseSource = "estimated";
        otherwise
            error('pds:signal:designOptimalFilter:UnknownNoiseModel', ...
                'Unknown NoiseModel "%s".', noiseModel);
    end

    if ~any(noisePsd > 0) || any(~isfinite(noisePsd)) || any(noisePsd < 0)
        error('pds:signal:designOptimalFilter:DegenerateNoisePsd', ...
            'Noise PSD must be finite, nonnegative, and contain positive power.');
    end
    verifyPsdSymmetry(noisePsd);
    psdFloor = regularizationFraction * max(noisePsd);
    regularizedNoisePsd = max(noisePsd, psdFloor);
    regularizedMask = noisePsd < psdFloor;

    templateSpectrum = pds.signal.forwardDft(template, samplePeriod);
    whitenedSpectrum = templateSpectrum ./ regularizedNoisePsd;
    weights = pds.signal.inverseDft(whitenedSpectrum, RealOutput=true);
    gainBeforeNormalization = dot(weights, template);
    gainScale = max(1, norm(weights) * norm(template));
    if ~isfinite(gainBeforeNormalization) || ...
            abs(gainBeforeNormalization) <= eps(gainScale) * sampleCount
        error('pds:signal:designOptimalFilter:DegenerateNormalization', ...
            'Optimal-filter gain on the reference template is zero.');
    end
    weights = weights / gainBeforeNormalization;
    filterCoefficients = fliplr(weights);

    if isfield(psdInfo, 'windowName')
        windowName = psdInfo.windowName;
        window = psdInfo.window;
        windowPower = psdInfo.windowPower;
    else
        [windowName, window, windowPower] = describeWindow( ...
            sampleCount, options.Window, tukeyRatio);
    end

    diagnostics = struct( ...
        'referenceTemplate', template, ...
        'samplePeriod', samplePeriod, ...
        'sampleRateHz', 1 / samplePeriod, ...
        'frequencyHz', frequencyHz, ...
        'noiseSource', noiseSource, ...
        'noisePsd', noisePsd, ...
        'regularizedNoisePsd', regularizedNoisePsd, ...
        'psdFloor', psdFloor, ...
        'regularizedBinMask', regularizedMask, ...
        'regularizedBinCount', sum(regularizedMask), ...
        'regularizationFraction', regularizationFraction, ...
        'weights', weights, ...
        'filterCoefficients', filterCoefficients, ...
        'gainBeforeNormalization', gainBeforeNormalization, ...
        'predictedNoiseVariance', (1 / samplePeriod) / gainBeforeNormalization, ...
        'normalization', "unit-response", ...
        'scoreIndex', sampleCount, ...
        'latencySamples', sampleCount - 1, ...
        'pedestalSampleCount', pedestalSampleCount, ...
        'windowName', windowName, ...
        'window', window, ...
        'windowPower', windowPower, ...
        'tukeyRatio', tukeyRatio, ...
        'coloredNoiseModel', coloredNoiseModel, ...
        'selectedNoiseMask', preliminary.mask, ...
        'selectedNoiseCount', sum(preliminary.mask), ...
        'preliminaryScores', preliminary.scores, ...
        'pedestalMean', preliminary.mean, ...
        'pedestalSigma', preliminary.sigma);
end

function validateReference(referenceSignal)
    if ~isnumeric(referenceSignal) || ~isvector(referenceSignal) || isempty(referenceSignal)
        error('pds:signal:designOptimalFilter:ReferenceDimensions', ...
            'Reference signal must be a nonempty numeric vector.');
    end
    if numel(referenceSignal) < 2
        error('pds:signal:designOptimalFilter:TooFewSamples', ...
            'Reference signal must contain at least two samples.');
    end
    if ~isreal(referenceSignal)
        error('pds:signal:designOptimalFilter:NonrealReference', ...
            'Reference signal must be real.');
    end
    if any(~isfinite(referenceSignal(:)))
        error('pds:signal:designOptimalFilter:NonfiniteReference', ...
            'Reference signal must contain only finite samples.');
    end
end

function validatePositiveScalar(value, identifier, label)
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(value) || value <= 0
        error(identifier, '%s must be a finite positive real scalar.', label);
    end
end

function count = resolvePedestalSampleCount(requestedCount, sampleCount)
    if isempty(requestedCount)
        count = max(1, floor(0.1 * sampleCount));
        return;
    end
    if ~isnumeric(requestedCount) || ~isscalar(requestedCount) || ...
            ~isreal(requestedCount) || ~isfinite(requestedCount) || ...
            requestedCount < 0 || requestedCount >= sampleCount || ...
            requestedCount ~= fix(requestedCount)
        error('pds:signal:designOptimalFilter:InvalidPedestalSampleCount', ...
            'PedestalSampleCount must be an integer in [0,N-1].');
    end
    count = double(requestedCount);
end

function centered = removePedestal(waveform, count)
    centered = waveform;
    if count > 0
        centered = centered - mean(centered(1:count));
    end
end

function centered = removeWaveformPedestals(waveforms, count)
    if isvector(waveforms)
        waveforms = double(waveforms(:).');
    else
        waveforms = double(waveforms);
    end
    centered = waveforms;
    if count > 0
        centered = centered - mean(centered(:, 1:count), 2);
    end
end

function validateWaveformMatrix(waveforms, sampleCount, label)
    if ~isnumeric(waveforms) || isempty(waveforms) || ~ismatrix(waveforms) || ...
            ~isreal(waveforms) || any(~isfinite(waveforms(:)))
        error('pds:signal:designOptimalFilter:InvalidWaveforms', ...
            '%s must contain finite real waveform records.', label);
    end
    if isvector(waveforms)
        actualSampleCount = numel(waveforms);
    else
        actualSampleCount = size(waveforms, 2);
    end
    if actualSampleCount ~= sampleCount
        error('pds:signal:designOptimalFilter:WaveformLength', ...
            '%s must have N samples per record.', label);
    end
end

function model = resolveNoiseModel(requested, noiseWaveforms, candidates, estimateFlag)
    valid = ["auto", "white", "measured", "estimated", "provided", "parametric"];
    if ~any(requested == valid)
        error('pds:signal:designOptimalFilter:UnknownNoiseModel', ...
            'Unknown NoiseModel "%s".', requested);
    end
    if requested ~= "auto"
        model = requested;
        return;
    end
    if ~isempty(noiseWaveforms)
        model = "measured";
    elseif estimateFlag && ~isempty(candidates)
        model = "estimated";
    else
        model = "white";
    end
end

function psd = validateProvidedPsd(psd, sampleCount)
    if ~isnumeric(psd) || ~isvector(psd) || numel(psd) ~= sampleCount
        error('pds:signal:designOptimalFilter:NoisePsdLength', ...
            'NoisePsd must be a numeric bilateral vector with N bins.');
    end
    psd = double(psd(:).');
    if ~isreal(psd) || any(~isfinite(psd)) || any(psd < 0)
        error('pds:signal:designOptimalFilter:InvalidNoisePsd', ...
            'NoisePsd must contain finite nonnegative real values.');
    end
end

function [psd, frequencyHz, model] = parametricNoisePsd( ...
        sampleCount, samplePeriod, modelSpecification, arCoefficient, ...
        powerLawExponent, powerLawCornerFrequencyHz)
    model = lower(string(modelSpecification));
    frequencyHz = fftFrequencyAxis(sampleCount, samplePeriod);
    switch model
        case "ar1"
            if ~isnumeric(arCoefficient) || ~isscalar(arCoefficient) || ...
                    ~isreal(arCoefficient) || ~isfinite(arCoefficient) || ...
                    abs(arCoefficient) >= 1
                error('pds:signal:designOptimalFilter:InvalidArCoefficient', ...
                    'ArCoefficient must be finite and satisfy abs(a)<1.');
            end
            arCoefficient = double(arCoefficient);
            omega = 2 * pi * (0:(sampleCount - 1)) / sampleCount;
            psd = (1 - arCoefficient^2) ./ ...
                abs(1 - arCoefficient * exp(-1i * omega)).^2;
            psd = real(psd / max(psd));
        case {"powerlaw", "1/f"}
            validatePositiveScalar(powerLawExponent, ...
                'pds:signal:designOptimalFilter:InvalidPowerLawExponent', ...
                'PowerLawExponent');
            powerLawExponent = double(powerLawExponent);
            if isempty(powerLawCornerFrequencyHz)
                corner = (1 / samplePeriod) / sampleCount;
            else
                validatePositiveScalar(powerLawCornerFrequencyHz, ...
                    'pds:signal:designOptimalFilter:InvalidPowerLawCorner', ...
                    'PowerLawCornerFrequencyHz');
                corner = double(powerLawCornerFrequencyHz);
            end
            psd = 1 ./ max(abs(frequencyHz), corner).^powerLawExponent;
            psd = psd / max(psd);
            model = "powerlaw";
        otherwise
            error('pds:signal:designOptimalFilter:UnknownColoredNoiseModel', ...
                'ColoredNoiseModel must be "ar1" or "powerlaw".');
    end
end

function verifyPsdSymmetry(psd)
    mirrored = psd([1, end:-1:2]);
    tolerance = 1e-10 * max(1, max(abs(psd)));
    if max(abs(psd - mirrored)) > tolerance
        error('pds:signal:designOptimalFilter:NonSymmetricNoisePsd', ...
            'A real stationary-noise PSD must be symmetric in FFT order.');
    end
end

function frequencyHz = fftFrequencyAxis(sampleCount, samplePeriod)
    sampleRateHz = 1 / samplePeriod;
    positiveBins = 0:floor(sampleCount / 2);
    negativeBins = (-ceil(sampleCount / 2) + 1):-1;
    frequencyHz = [positiveBins, negativeBins] * (sampleRateHz / sampleCount);
end

function [mu0, sigma0, mask] = estimatePedestalPeak(scores, selectionSigma)
    scores = scores(:);
    finiteScores = scores(isfinite(scores));
    binCount = max(80, min(240, round(3 * sqrt(numel(finiteScores)))));
    [counts, edges] = histcounts(finiteScores, binCount);
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    smoothedCounts = movmean(counts, 3);
    [peakHeight, modeIndex] = max(smoothedCounts);
    approximateMu = centers(modeIndex);

    % Isolate the contiguous pedestal peak before fitting. This avoids
    % contaminating sigma0 with photoelectron peaks or long negative tails.
    threshold = 0.3 * peakHeight;
    leftIndex = modeIndex;
    while leftIndex > 1 && smoothedCounts(leftIndex - 1) >= threshold
        leftIndex = leftIndex - 1;
    end
    rightIndex = modeIndex;
    while rightIndex < binCount && smoothedCounts(rightIndex + 1) >= threshold
        rightIndex = rightIndex + 1;
    end

    fitIndices = leftIndex:rightIndex;
    if numel(fitIndices) >= 3
        logCounts = log(max(smoothedCounts(fitIndices), eps));
        polynomial = polyfit(centers(fitIndices), logCounts, 2);
    else
        polynomial = [NaN, NaN, NaN];
    end

    if isfinite(polynomial(1)) && polynomial(1) < 0
        mu0 = -polynomial(2) / (2 * polynomial(1));
        sigma0 = sqrt(-1 / (2 * polynomial(1)));
    else
        mu0 = approximateMu;
        halfMaximum = 0.5 * peakHeight;
        leftHalf = find(smoothedCounts(1:modeIndex) < halfMaximum, 1, 'last');
        rightRelative = find(smoothedCounts(modeIndex:end) < halfMaximum, 1, 'first');
        if isempty(leftHalf) || isempty(rightRelative)
            sigma0 = std(finiteScores, 1);
        else
            rightHalf = modeIndex + rightRelative - 1;
            sigma0 = (centers(rightHalf) - centers(leftHalf)) / ...
                (2 * sqrt(2 * log(2)));
        end
    end

    binWidth = edges(2) - edges(1);
    fitSpan = max(binWidth, centers(rightIndex) - centers(leftIndex));
    if ~isfinite(mu0) || abs(mu0 - approximateMu) > fitSpan || ...
            ~isfinite(sigma0) || sigma0 <= binWidth / 4
        error('pds:signal:designOptimalFilter:DegeneratePedestalPeak', ...
            'Unable to estimate a stable Gaussian pedestal peak.');
    end

    mask = abs(scores - mu0) <= selectionSigma * sigma0;
end

function [name, window, power] = describeWindow(sampleCount, specification, tukeyRatio)
    window = pds.signal.createWindow(sampleCount, specification, TukeyRatio=tukeyRatio);
    power = sum(window.^2);
    if isnumeric(specification)
        name = "custom";
    else
        name = lower(string(specification));
        if name == "none"
            name = "rectangular";
        end
    end
end
