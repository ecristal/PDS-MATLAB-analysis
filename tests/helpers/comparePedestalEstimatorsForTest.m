function [summary, details] = comparePedestalEstimatorsForTest( ...
        waveforms, sampleIndices, pedestalTruth, referenceTruth, options)
%COMPAREPEDESTALESTIMATORSFORTEST Compare identical events and sample regions.
% [summary, details] = comparePedestalEstimatorsForTest(waveforms, ...
%     sampleIndices, pedestalTruth, referenceTruth, BlockSize=10, ...
%     AcceptableMask=[], CoverageMultiplier=1.96)
% Rows are events; columns are samples. Both truths must be finite real
% numeric E-by-1 columns. Waveform/index/block validation delegates to
% estimatePedestal; unlike that estimator, this helper rejects index matrices.
% Integer inputs beyond +/-flintmax are rejected before conversion to double.
%
% Summary is a six-row table: mean, median, median-of-means, each paired
% with pedestal-mean then reference. Errors are estimate minus target truth.
% Bias is mean(error), RMSE is sqrt(mean(error.^2)); absolute-error quantiles
% use MATLAB prctile midpoint plotting positions with endpoint clamping.
% All events contribute, including flagged events. Flag rate is P(invalid).
% AcceptableMask is an EXTERNAL logical E-by-2 truth label array; labels are
% never inferred from numerical error. False-valid rate is P(valid | truth
% unacceptable); false-invalid rate is P(invalid | truth acceptable). Missing
% labels or an empty conditioning class give NaN, not a zero error rate.
%
% Coverage is the fraction satisfying abs(error) <= CoverageMultiplier*SE,
% over finite nonnegative SEs (including zero); unavailable SEs are counted
% separately. With no available SEs coverage is NaN. MoM SE remains NaN;
% no uncertainty is fabricated. The default multiplier does NOT establish
% calibrated 95 percent coverage, particularly under colored noise.
% runtimeSeconds times each estimator call once and repeats it for both
% targets; it excludes metric computation and is not deterministic.
%
% Details contains estimates/standardErrors/validEventMasks (E-by-3), errors
% (E-by-3-by-2), methods/targetNames (row strings), diagnostics (1-by-3 cell),
% normalized sampleIndices (row double), and the original acceptableMask.
% No inputs or global RNG state are modified. This is test-only scaffolding.
arguments
    waveforms
    sampleIndices
    pedestalTruth
    referenceTruth
    options.BlockSize = 10
    options.AcceptableMask = []
    options.CoverageMultiplier = 1.96
end
methods = ["mean", "median", "median-of-means"];
targetNames = ["pedestal-mean", "reference"];
eventCount = size(waveforms, 1);
pedestalTruth = validateTruth(pedestalTruth, eventCount);
referenceTruth = validateTruth(referenceTruth, eventCount);
if ~isempty(sampleIndices) && ~isvector(sampleIndices)
    error('pds:preprocess:estimatePedestal:InvalidSampleIndices', ...
        'Sample indices must be a vector, not an implicitly flattened matrix.');
end
mask = options.AcceptableMask;
if ~isequal(mask, []) && ~(islogical(mask) && isequal(size(mask), [eventCount, 2]))
    error('pds:test:comparePedestalEstimators:InvalidAcceptableMask', ...
        'AcceptableMask must be [] or an external logical E-by-2 truth label array.');
end
multiplier = options.CoverageMultiplier;
if ~isnumeric(multiplier) || ~isreal(multiplier) || ~isscalar(multiplier) || ...
        ~isfinite(multiplier) || multiplier < 0 || hasInexactIntegerValues(multiplier)
    error('pds:test:comparePedestalEstimators:InvalidCoverageMultiplier', ...
        'CoverageMultiplier must be a finite nonnegative numeric scalar safely convertible to double.');
end
options.CoverageMultiplier = double(multiplier);

estimates = zeros(eventCount, 3);
standardErrors = NaN(eventCount, 3);
validEventMasks = false(eventCount, 3);
diagnostics = cell(1, 3);
runtimes = zeros(3, 1);
for m = 1:3
    started = tic;
    [estimates(:, m), diagnostics{m}] = pds.preprocess.estimatePedestal( ...
        waveforms, SampleIndices=sampleIndices, Method=methods(m), ...
        BlockSize=options.BlockSize);
    runtimes(m) = toc(started);
    standardErrors(:, m) = diagnostics{m}.pedestalStandardError;
    validEventMasks(:, m) = diagnostics{m}.validEventMask;
end
errors = cat(3, estimates - pedestalTruth, estimates - referenceTruth);
metricNames = {'eventCount','bias','rmse','medianAbsoluteError', ...
    'p90AbsoluteError','p95AbsoluteError','p99AbsoluteError','flagRate', ...
    'falseValidRate','falseInvalidRate','coverage','coverageAvailableCount', ...
    'coverageUnavailableCount','runtimeSeconds'};
summary = [table(repelem(methods(:), 2), repmat(targetNames(:), 3, 1), ...
    'VariableNames', {'method','target'}), ...
    array2table(NaN(6, 14), 'VariableNames', metricNames)];
summary.eventCount(:) = eventCount;
summary.runtimeSeconds = repelem(runtimes, 2);
for m = 1:3
    for t = 1:2
        row = 2*(m-1)+t;
        e = errors(:, m, t);
        absoluteError = abs(e);
        summary.bias(row) = mean(e);
        summary.rmse(row) = sqrt(mean(e.^2));
        summary.medianAbsoluteError(row) = median(absoluteError);
        summary{row, {'p90AbsoluteError','p95AbsoluteError','p99AbsoluteError'}} = ...
            prctile(absoluteError, [90, 95, 99]);
        summary.flagRate(row) = mean(~validEventMasks(:, m));
        if ~isempty(options.AcceptableMask)
            acceptable = options.AcceptableMask(:, t);
            if any(~acceptable)
                summary.falseValidRate(row) = mean(validEventMasks(~acceptable, m));
            end
            if any(acceptable)
                summary.falseInvalidRate(row) = mean(~validEventMasks(acceptable, m));
            end
        end
        available = isfinite(standardErrors(:, m)) & standardErrors(:, m) >= 0;
        summary.coverageAvailableCount(row) = sum(available);
        summary.coverageUnavailableCount(row) = eventCount - sum(available);
        if any(available)
            summary.coverage(row) = mean(absoluteError(available) <= ...
                options.CoverageMultiplier * standardErrors(available, m));
        end

    end
end
details = struct('estimates', estimates, 'standardErrors', standardErrors, ...
    'validEventMasks', validEventMasks, 'errors', errors, 'methods', methods, ...
    'targetNames', targetNames, 'diagnostics', {diagnostics}, ...
    'sampleIndices', diagnostics{1}.sampleIndices, ...
    'acceptableMask', options.AcceptableMask);
end

function truth = validateTruth(truth, eventCount)
if ~isnumeric(truth) || ~isreal(truth) || ~isequal(size(truth), [eventCount, 1]) || ...
        any(~isfinite(truth(:))) || hasInexactIntegerValues(truth)
    error('pds:test:comparePedestalEstimators:InvalidTruth', ...
        'Each truth must be a finite real numeric E-by-1 column convertible exactly to double.');
end
truth = double(truth);
end

function tf = hasInexactIntegerValues(value)
if isa(value, 'uint64')
    tf = any(value(:) > uint64(flintmax));
elseif isa(value, 'int64')
    limit = int64(flintmax);
    tf = any(value(:) > limit | value(:) < -limit);
else
    tf = false;
end
end
