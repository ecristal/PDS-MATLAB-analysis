function [filterCoefficients, diagnostics] = ...
        designCovarianceOptimalFilter(referenceSignal, noiseWaveforms, options)
%DESIGNCOVARIANCEOPTIMALFILTER Design a full-covariance unit-gain FIR.
%   Rows of NOISEWAVEFORMS are pedestal-class records with the same sample
%   count as REFERENCESIGNAL. The returned causal FIR produces the optimal
%   generalized least-squares amplitude estimate at its final output sample.
%
%   ShrinkageFraction adds FRACTION*mean(diag(C))*I to the noise covariance.
%   PriorCovariance may supply an independently measured covariance. It is
%   trace-normalized to the empirical covariance and blended using
%   PriorWeight before diagonal shrinkage is applied.

    arguments
        referenceSignal
        noiseWaveforms
        options.ShrinkageFraction = 1e-4
        options.PriorCovariance = []
        options.PriorWeight = 0
    end

    identifier = 'pds:signal:designCovarianceOptimalFilter:';
    if ~isnumeric(referenceSignal) || ~isvector(referenceSignal) || ...
            isempty(referenceSignal) || ~isreal(referenceSignal) || ...
            any(~isfinite(referenceSignal(:)))
        error([identifier, 'InvalidReference'], ...
            'Reference signal must be a nonempty finite real numeric vector.');
    end
    rejectInexactIntegerValues(referenceSignal, identifier);
    referenceSignal = double(referenceSignal(:).');
    sampleCount = numel(referenceSignal);
    if sampleCount < 2
        error([identifier, 'InvalidReference'], ...
            'Reference signal must contain at least two samples.');
    end
    if norm(referenceSignal) == 0
        error([identifier, 'DegenerateReference'], ...
            'Reference signal must have nonzero energy.');
    end

    if ~isnumeric(noiseWaveforms) || isempty(noiseWaveforms) || ...
            ~ismatrix(noiseWaveforms) || ~isreal(noiseWaveforms) || ...
            any(~isfinite(noiseWaveforms(:)))
        error([identifier, 'InvalidNoise'], ...
            'Noise waveforms must form a nonempty finite real matrix.');
    end
    if isvector(noiseWaveforms)
        noiseRecordCount = 1;
        actualSampleCount = numel(noiseWaveforms);
    else
        noiseRecordCount = size(noiseWaveforms, 1);
        actualSampleCount = size(noiseWaveforms, 2);
    end
    if actualSampleCount ~= sampleCount
        error([identifier, 'NoiseLength'], ...
            'Noise records and reference signal must have equal length.');
    end
    if noiseRecordCount < 2
        error([identifier, 'InsufficientNoiseRecords'], ...
            'At least two noise records are required.');
    end
    rejectInexactIntegerValues(noiseWaveforms, identifier);
    noiseWaveforms = double(noiseWaveforms);

    shrinkageFraction = options.ShrinkageFraction;
    if ~isnumeric(shrinkageFraction) || ~isscalar(shrinkageFraction) || ...
            ~isreal(shrinkageFraction) || ~isfinite(shrinkageFraction) || ...
            shrinkageFraction < 0 || shrinkageFraction > 1
        error([identifier, 'InvalidShrinkage'], ...
            'ShrinkageFraction must be a finite scalar in [0,1].');
    end
    shrinkageFraction = double(shrinkageFraction);

    priorWeight = options.PriorWeight;
    if ~isnumeric(priorWeight) || ~isscalar(priorWeight) || ...
            ~isreal(priorWeight) || ~isfinite(priorWeight) || ...
            priorWeight < 0 || priorWeight > 1
        error([identifier, 'InvalidPriorWeight'], ...
            'PriorWeight must be a finite scalar in [0,1].');
    end
    priorWeight = double(priorWeight);

    noiseMean = mean(noiseWaveforms, 1);
    centeredNoise = noiseWaveforms - noiseMean;
    empiricalCovariance = ...
        (centeredNoise.' * centeredNoise) / noiseRecordCount;
    priorCovariance = options.PriorCovariance;
    priorScale = 0;
    if isempty(priorCovariance)
        if priorWeight > 0
            error([identifier, 'MissingPriorCovariance'], ...
                'A nonzero PriorWeight requires PriorCovariance.');
        end
        covariance = empiricalCovariance;
    else
        rejectInexactIntegerValues(priorCovariance, identifier);
        if ~isnumeric(priorCovariance) || ~isreal(priorCovariance) || ...
                ~isequal(size(priorCovariance), [sampleCount, sampleCount]) || ...
                any(~isfinite(priorCovariance(:)))
            error([identifier, 'InvalidPriorCovariance'], ...
                'PriorCovariance must be a finite real N-by-N matrix.');
        end
        priorCovariance = double(priorCovariance);
        symmetryScale = max(1, norm(priorCovariance, 'fro'));
        if norm(priorCovariance - priorCovariance.', 'fro') > ...
                1e-10 * symmetryScale
            error([identifier, 'InvalidPriorCovariance'], ...
                'PriorCovariance must be symmetric.');
        end
        priorCovariance = (priorCovariance + priorCovariance.') / 2;
        priorTrace = trace(priorCovariance);
        empiricalTrace = trace(empiricalCovariance);
        if priorTrace <= 0 || empiricalTrace <= 0 || ...
                min(eig(priorCovariance)) < -1e-10 * symmetryScale
            error([identifier, 'InvalidPriorCovariance'], ...
                'PriorCovariance must be positive semidefinite with positive trace.');
        end
        priorScale = empiricalTrace / priorTrace;
        covariance = (1 - priorWeight) * empiricalCovariance + ...
            priorWeight * priorScale * priorCovariance;
    end
    covarianceScale = trace(covariance) / sampleCount;
    if ~isfinite(covarianceScale) || covarianceScale <= 0
        error([identifier, 'DegenerateCovariance'], ...
            'Noise covariance must contain positive finite power.');
    end
    regularization = shrinkageFraction * covarianceScale;
    regularizedCovariance = covariance + ...
        regularization * eye(sampleCount);

    rawWeights = regularizedCovariance \ referenceSignal.';
    gainBeforeNormalization = referenceSignal * rawWeights;
    gainScale = max(1, norm(referenceSignal) * norm(rawWeights));
    if ~isfinite(gainBeforeNormalization) || ...
            abs(gainBeforeNormalization) <= eps(gainScale) * sampleCount
        error([identifier, 'DegenerateNormalization'], ...
            'The covariance-weighted template gain is zero.');
    end
    weights = (rawWeights / gainBeforeNormalization).';
    filterCoefficients = fliplr(weights);
    predictedNoiseVariance = weights * covariance * weights.';

    diagnostics = struct( ...
        'referenceSignal', referenceSignal, ...
        'noiseMean', noiseMean, ...
        'noiseRecordCount', noiseRecordCount, ...
        'sampleCount', sampleCount, ...
        'empiricalCovariance', empiricalCovariance, ...
        'priorCovariance', priorCovariance, ...
        'priorWeight', priorWeight, ...
        'priorScale', priorScale, ...
        'covariance', covariance, ...
        'covarianceScale', covarianceScale, ...
        'shrinkageFraction', shrinkageFraction, ...
        'regularization', regularization, ...
        'regularizedCovariance', regularizedCovariance, ...
        'weights', weights, ...
        'filterCoefficients', filterCoefficients, ...
        'gainBeforeNormalization', gainBeforeNormalization, ...
        'predictedNoiseVariance', predictedNoiseVariance, ...
        'normalization', "unit-response", ...
        'scoreIndex', sampleCount, ...
        'latencySamples', sampleCount - 1);
end

function rejectInexactIntegerValues(value, identifier)
    if isa(value, 'uint64')
        unsafe = any(value(:) > uint64(flintmax));
    elseif isa(value, 'int64')
        exactLimit = int64(flintmax);
        unsafe = any(value(:) > exactLimit | value(:) < -exactLimit);
    else
        unsafe = false;
    end
    if unsafe
        error([identifier, 'InexactIntegerConversion'], ...
            'Integer inputs must lie in the contiguous exact double range.');
    end
end
