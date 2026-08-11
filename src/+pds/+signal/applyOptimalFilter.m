function [scores, filteredWaveforms] = applyOptimalFilter(waveforms, filterCoefficients, options)
%APPLYOPTIMALFILTER Apply FIR optimal-filter coefficients to waveforms.
%   SCORES = pds.signal.applyOptimalFilter(WAVEFORMS, COEFFICIENTS) treats
%   rows as records, removes a per-record pedestal, applies the FIR along
%   columns, and returns the final filtered sample for each record.
%
%   COEFFICIENTS must have one value per waveform sample. For coefficients
%   returned by designOptimalFilter, the final sample is the unit-gain
%   amplitude estimate for a waveform aligned with the reference template.

    arguments
        waveforms
        filterCoefficients
        options.PedestalSampleCount = []
    end

    if ~isnumeric(waveforms) || isempty(waveforms) || ~ismatrix(waveforms)
        error('pds:signal:applyOptimalFilter:WaveformDimensions', ...
            'Waveforms must be a nonempty numeric vector or matrix.');
    end
    if ~isreal(waveforms)
        error('pds:signal:applyOptimalFilter:NonrealWaveforms', ...
            'Waveforms must be real.');
    end
    if any(~isfinite(waveforms(:)))
        error('pds:signal:applyOptimalFilter:NonfiniteWaveforms', ...
            'Waveforms must contain only finite samples.');
    end
    if ~isnumeric(filterCoefficients) || ~isvector(filterCoefficients) || ...
            isempty(filterCoefficients) || ~isreal(filterCoefficients) || ...
            any(~isfinite(filterCoefficients(:)))
        error('pds:signal:applyOptimalFilter:InvalidFilter', ...
            'Filter coefficients must be a finite real vector.');
    end

    if isvector(waveforms)
        waveforms = double(waveforms(:).');
    else
        waveforms = double(waveforms);
    end
    filterCoefficients = double(filterCoefficients(:).');
    sampleCount = size(waveforms, 2);
    if numel(filterCoefficients) ~= sampleCount
        error('pds:signal:applyOptimalFilter:LengthMismatch', ...
            'Filter and waveform lengths must match.');
    end

    pedestalSampleCount = resolvePedestalSampleCount( ...
        options.PedestalSampleCount, sampleCount);
    if pedestalSampleCount > 0
        pedestal = mean(waveforms(:, 1:pedestalSampleCount), 2);
    else
        pedestal = zeros(size(waveforms, 1), 1, 'like', waveforms);
    end

    if nargout > 1
        correctedWaveforms = waveforms - pedestal;
        filteredWaveforms = filter( ...
            filterCoefficients, 1, correctedWaveforms, [], 2);
        scores = filteredWaveforms(:, end);
    else
        % For the final sample of an N-tap FIR applied to an N-sample
        % record, the operation is exactly a dot product with the reversed
        % coefficients. This path avoids allocating a full filtered matrix.
        weights = fliplr(filterCoefficients);
        scores = waveforms * weights.' - pedestal * sum(weights);
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
        error('pds:signal:applyOptimalFilter:InvalidPedestalSampleCount', ...
            'PedestalSampleCount must be an integer in [0,N-1].');
    end
    count = double(requestedCount);
end
