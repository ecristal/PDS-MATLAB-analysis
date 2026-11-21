classdef TestPedestalEstimatorComparison < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'src')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'tests', 'helpers')));
        end
    end
    methods (Test)
        function baselineHasExactSchemaAndAllMethods(testCase)
            w = repmat([4; 9], 1, 20);
            [s, d] = comparePedestalEstimatorsForTest(w, 1:20, [4; 9], [4; 9]);
            names = {'method','target','eventCount','bias','rmse', ...
                'medianAbsoluteError','p90AbsoluteError','p95AbsoluteError', ...
                'p99AbsoluteError','flagRate','falseValidRate', ...
                'falseInvalidRate','coverage','coverageAvailableCount', ...
                'coverageUnavailableCount','runtimeSeconds'};
            testCase.verifyClass(s, 'table');
            testCase.verifySize(s, [6, 16]);
            testCase.verifyEqual(s.Properties.VariableNames, names);
            testCase.verifyEqual(s.method, repelem(["mean"; "median"; "median-of-means"], 2));
            testCase.verifyEqual(s.target, repmat(["pedestal-mean"; "reference"], 3, 1));
            testCase.verifyEqual(s.eventCount, repmat(2, 6, 1));
            testCase.verifyEqual(d.estimates, repmat([4; 9], 1, 3));
            testCase.verifySize(d.standardErrors, [2, 3]);
            testCase.verifyClass(d.validEventMasks, 'logical');
            testCase.verifySize(d.validEventMasks, [2, 3]);
            testCase.verifySize(d.errors, [2, 3, 2]);
            testCase.verifyEqual(d.methods, ["mean", "median", "median-of-means"]);
            testCase.verifyEqual(d.targetNames, ["pedestal-mean", "reference"]);
            testCase.verifySize(d.diagnostics, [1, 3]);
            testCase.verifyEqual(d.sampleIndices, 1:20);
            testCase.verifyEmpty(d.acceptableMask);
            testCase.verifyTrue(all(isfinite(s.runtimeSeconds) & s.runtimeSeconds >= 0));
            for m = 1:3
                [level, diag] = pds.preprocess.estimatePedestal(w, ...
                    SampleIndices=1:20, Method=d.methods(m), BlockSize=10);
                testCase.verifyEqual(d.estimates(:, m), level);
                testCase.verifyEqual(d.diagnostics{m}, diag);
                testCase.verifyEqual(d.standardErrors(:, m), diag.pedestalStandardError);
                testCase.verifyEqual(d.validEventMasks(:, m), diag.validEventMask);
            end
        end
        function contaminatedMetricsUseIndependentTruth(testCase)
            % Twenty events make 90/95/99 percentiles exercise interpolation.
            a = (1:20)';
            w = [999 * ones(20, 1), zeros(20, 9), 10*a, -999*ones(20, 1)];
            pedestal = zeros(20, 1);
            reference = 2 * ones(20, 1);
            [s, d] = comparePedestalEstimatorsForTest(w, 2:11, pedestal, ...
                reference, BlockSize=2);
            expected = [a, zeros(20, 2)]; % Mean sees spike; median/MoM reject it.
            testCase.verifyEqual(d.estimates, expected);
            testCase.verifyEqual(d.errors(:, :, 1), expected);
            testCase.verifyEqual(d.errors(:, :, 2), expected - 2);
            testCase.verifyTrue(any(~d.validEventMasks(:, 1)));
            testCase.verifyEqual(s.eventCount, 20*ones(6, 1));
            for m = 1:3
                for t = 1:2
                    row = 2*(m-1)+t;
                    e = expected(:, m) - 2*(t-1);
                    sorted = sort(abs(e));
                    % MATLAB midpoint plotting positions: h=N*p+0.5.
                    q = [0, 0, 0];
                    probabilities = [0.90, 0.95, 0.99];
                    for k = 1:3
                        h = min(20, max(1, 20*probabilities(k)+0.5));
                        lo = floor(h); hi = ceil(h);
                        q(k) = sorted(lo) + (h-lo)*(sorted(hi)-sorted(lo));
                    end
                    testCase.verifyEqual(s.bias(row), sum(e)/20, 'AbsTol', 1e-12);
                    testCase.verifyEqual(s.rmse(row), sqrt(sum(e.*e)/20), 'AbsTol', 1e-12);
                    testCase.verifyEqual(s.medianAbsoluteError(row), ...
                        (sorted(10)+sorted(11))/2, 'AbsTol', 1e-12);
                    testCase.verifyEqual(s{row, {'p90AbsoluteError', ...
                        'p95AbsoluteError','p99AbsoluteError'}}, q, 'AbsTol', 1e-12);
                    testCase.verifyEqual(s.flagRate(row), sum(~d.validEventMasks(:, m))/20);
                end
            end
        end
        function coverageCountsUnavailableAndZeroStandardError(testCase)
            w = [zeros(1, 10); repmat([-1, 1], 1, 5); ones(1, 10)];
            [s, d] = comparePedestalEstimatorsForTest(w, 1:10, [0; 0.5; 1], ...
                [1; 0; 1]);
            testCase.verifyTrue(all(isnan(d.standardErrors(:, 3))));
            testCase.verifyEqual(s.coverageAvailableCount, [3; 3; 3; 3; 0; 0]);
            testCase.verifyEqual(s.coverageUnavailableCount, [0; 0; 0; 0; 3; 3]);
            testCase.verifyEqual(s.coverage, [1; 2/3; 1; 2/3; NaN; NaN]);
            testCase.verifyEqual(d.standardErrors([1, 3], 1:2), zeros(2));
            for m = 1:2
                for t = 1:2
                    expected = sum(abs(d.errors(:, m, t)) <= ...
                        1.96*d.standardErrors(:, m))/3;
                    testCase.verifyEqual(s.coverage(2*(m-1)+t), expected);
                end
            end
            s0 = comparePedestalEstimatorsForTest(w, 1:10, [0; 0.5; 1], ...
                [1; 0; 1], CoverageMultiplier=0);
            testCase.verifyEqual(s0.coverage, [2/3; 2/3; 2/3; 2/3; NaN; NaN]);
        end
        function confusionUsesExternalConditionalLabels(testCase)
            w = [zeros(2, 10); repmat(1:10, 3, 1)];
            labels = logical([0, 1; 0, 0; 0, 1; 1, 0; 1, 0]);
            [s, d] = comparePedestalEstimatorsForTest(w, 1:10, ...
                zeros(5, 1), zeros(5, 1), AcceptableMask=labels);
            testCase.verifyEqual(d.validEventMasks, repmat(logical([1; 1; 0; 0; 0]), 1, 3));
            testCase.verifyEqual(d.acceptableMask, labels);
            testCase.verifyEqual(s.falseValidRate, repmat([2/3; 1/3], 3, 1));
            testCase.verifyEqual(s.falseInvalidRate, repmat([1; 1/2], 3, 1));
            % Identical numeric truth/errors but different external labels.
            emptyClass = comparePedestalEstimatorsForTest(w, 1:10, ...
                zeros(5, 1), zeros(5, 1), AcceptableMask=[true(5, 1), false(5, 1)]);
            testCase.verifyEqual(emptyClass.falseValidRate, repmat([NaN; 2/5], 3, 1));
            testCase.verifyEqual(emptyClass.falseInvalidRate, repmat([3/5; NaN], 3, 1));
            missing = comparePedestalEstimatorsForTest(w, 1:10, zeros(5, 1), zeros(5, 1));
            testCase.verifyTrue(all(isnan(missing.falseValidRate)));
            testCase.verifyTrue(all(isnan(missing.falseInvalidRate)));
        end
        function integerInputsPreserveValuesStateAndDeterminism(testCase)
            w = int16([zeros(1, 9), 3; ones(1, 10)]);
            indices = uint16(1:10);
            p = int16([0; 1]); r = int16([1; 2]);
            labels = logical([1, 0; 0, 1]);
            before = {w, indices, p, r, labels};
            state = rng;
            [s, d] = comparePedestalEstimatorsForTest(w, indices, p, r, ...
                BlockSize=uint8(2), CoverageMultiplier=uint8(2), AcceptableMask=labels);
            testCase.verifyEqual(d.errors(:, 1, 1), [0.3; 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(d.errors(:, 1, 2), [-0.7; -1], 'AbsTol', 1e-12);
            [s2, d2] = comparePedestalEstimatorsForTest(w, indices, p, r, ...
                BlockSize=uint8(2), CoverageMultiplier=uint8(2), AcceptableMask=labels);
            testCase.verifyEqual(d, d2);
            testCase.verifyEqual(s(:, 1:15), s2(:, 1:15)); % Runtime is observational.
            testCase.verifyEqual({w, indices, p, r, labels}, before);
            testCase.verifyEqual(rng, state);
            huge = uint64(flintmax) + uint64(1);
            testCase.verifyError(@() comparePedestalEstimatorsForTest(w, indices, ...
                [huge; huge], r), 'pds:test:comparePedestalEstimators:InvalidTruth');
        end
        function invalidShapesLabelsAndOptionsAreRejected(testCase)
            w = zeros(2, 10); truth = zeros(2, 1);
            helperId = 'pds:test:comparePedestalEstimators:';
            estimatorId = 'pds:preprocess:estimatePedestal:';
            badTruths = {[], 0, [0, 0], zeros(2, 2), [NaN; 0], [Inf; 0], ...
                [1i; 0], {'a'; 'b'}, true(2, 1), ...
                repmat(intmin('int64'), 2, 1)};
            for k = 1:numel(badTruths)
                testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                    w, 1:10, badTruths{k}, truth), [helperId, 'InvalidTruth']);
                testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                    w, 1:10, truth, badTruths{k}), [helperId, 'InvalidTruth']);
            end
            badLabels = {ones(2, 2), true(1, 2), true(2, 1), true(2, 2, 2), ...
                'ab', zeros(0, 2), {true, false; false, true}};
            for k = 1:numel(badLabels)
                testCase.verifyError(@() comparePedestalEstimatorsForTest(w, ...
                    1:10, truth, truth, AcceptableMask=badLabels{k}), ...
                    [helperId, 'InvalidAcceptableMask']);
            end
            badMultipliers = {-1, NaN, Inf, 1i, [], [1, 2], 'x', true, ...
                uint64(flintmax)+uint64(1)};
            for k = 1:numel(badMultipliers)
                testCase.verifyError(@() comparePedestalEstimatorsForTest(w, ...
                    1:10, truth, truth, CoverageMultiplier=badMultipliers{k}), ...
                    [helperId, 'InvalidCoverageMultiplier']);
            end
            testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                zeros(2, 10, 2), 1:10, truth, truth), [estimatorId, 'InvalidWaveforms']);
            testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                zeros(2, 1), 1, truth, truth, BlockSize=1), ...
                [estimatorId, 'AmbiguousColumnVector']);
            testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                zeros(0, 10), 1:10, zeros(0, 1), zeros(0, 1)), ...
                [estimatorId, 'InvalidWaveforms']);
            testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                repmat(uint64(flintmax)+uint64(1), 2, 10), 1:10, truth, truth), ...
                [estimatorId, 'InexactIntegerConversion']);
            badIndices = {[1, 1], [2, 1], [0, 1], [1, 11], [1, 2.5], ...
                uint64(flintmax)+uint64(1)};
            for k = 1:numel(badIndices)
                testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                    w, badIndices{k}, truth, truth), [estimatorId, 'InvalidSampleIndices']);
            end
            testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                w, [], truth, truth), [estimatorId, 'MissingSampleIndices']);
            testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                w, [1, 3; 2, 4], truth, truth, BlockSize=2), ...
                [estimatorId, 'InvalidSampleIndices']);
            for block = {0, 3, 1.5, [1, 2], uint64(flintmax)+uint64(1)}
                testCase.verifyError(@() comparePedestalEstimatorsForTest( ...
                    w, 1:10, truth, truth, BlockSize=block{1}), ...
                    [estimatorId, 'InvalidBlockSize']);
            end
            % Estimator argument validators retain their own error identifiers.
            for badWaveform = {NaN(2, 10), Inf(2, 10), 1i*ones(2, 10), true(2, 10)}
                testCase.verifyFalse(acceptsWaveform(badWaveform{1}, truth));
            end
        end
    end
end

function accepted = acceptsWaveform(waveforms, truth)
try
    comparePedestalEstimatorsForTest(waveforms, 1:10, truth, truth);
    accepted = true;
catch
    accepted = false;
end
end
