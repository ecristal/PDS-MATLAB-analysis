classdef TestEstimatePedestal < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function explicitPretriggerMeanIsComputedPerWaveform(testCase)
            waveforms = [10, 10, 10, 40; 100, 100, 100, 400];

            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                waveforms, SampleIndices=1:3, Method="mean");

            testCase.verifyEqual(level, [10; 100]);
            testCase.verifyEqual(diagnostics.method, "mean");
            testCase.verifyEqual(diagnostics.sampleIndices, 1:3);
            testCase.verifyEqual(diagnostics.sampleCount, 3);
            testCase.verifyEqual(diagnostics.sampleNoiseSigma, [0; 0]);
            testCase.verifyEqual(diagnostics.pedestalStandardError, [0; 0]);
        end

        function rejectsNonmatrixAndEmptyWaveforms(testCase)
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                zeros(2, 2, 2), SampleIndices=1), ...
                'pds:preprocess:estimatePedestal:InvalidWaveforms');
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                [], SampleIndices=1), ...
                'pds:preprocess:estimatePedestal:InvalidWaveforms');
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                [1; 2; 3], SampleIndices=1), ...
                'pds:preprocess:estimatePedestal:AmbiguousColumnVector');
        end

        function rejectsIntegerWaveformsNotExactlyRepresentableAsDouble(testCase)
            unsafe = uint64(flintmax) + uint64(1);
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                [unsafe, unsafe], SampleIndices=1:2), ...
                'pds:preprocess:estimatePedestal:InexactIntegerConversion');
        end

        function requiresIncreasingSampleIndices(testCase)
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                [10, 11, 12], SampleIndices=[2, 1], ...
                Method="median-of-means", BlockSize=1), ...
                'pds:preprocess:estimatePedestal:InvalidSampleIndices');
        end

        function medianRejectsSingleLargePretriggerOutlier(testCase)
            waveforms = [10, 10, 1000, 10, 40; 20, 20, 20, -900, 50];

            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                waveforms, SampleIndices=1:4, Method="median");

            testCase.verifyEqual(level, [10; 20]);
            testCase.verifyEqual(diagnostics.method, "median");
            testCase.verifyEqual(diagnostics.sampleIndices, 1:4);
        end

        function medianOfMeansRejectsNondivisibleSampleCount(testCase)
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                1:5, SampleIndices=1:5, Method="median-of-means", ...
                BlockSize=2), ...
                'pds:preprocess:estimatePedestal:InvalidBlockSize');
        end

        function medianOfMeansNoiseUsesSampleMedianCenteredMad(testCase)
            pretrigger = [0, 0, 0, 0, 0, 300, ...
                0, 0, 300, 0, 0, 300];

            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                pretrigger, SampleIndices=1:12, ...
                Method="median-of-means", BlockSize=3);

            testCase.verifyEqual(level, 100);
            testCase.verifyEqual(diagnostics.sampleNoiseSigma, 0);
            testCase.verifyTrue(isnan(diagnostics.pedestalStandardError));
        end

        function medianOfMeansRejectsOneContaminatedBlock(testCase)
            pretrigger = [10, 10, 10, 10, 10, 10, 1000, 1000, 1000, 10, 10, 10];
            waveforms = [pretrigger, 50; 100 + pretrigger, 150];

            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                waveforms, SampleIndices=1:12, Method="median-of-means", ...
                BlockSize=3);

            testCase.verifyEqual(level, [10; 110]);
            testCase.verifyEqual(diagnostics.method, "median-of-means");
            testCase.verifyEqual(diagnostics.blockCount, 4);
            testCase.verifyEqual(diagnostics.blockSize, 3);
            testCase.verifySize(diagnostics.blockMeans, [2, 4]);
            testCase.verifyTrue(all(isnan( ...
                diagnostics.pedestalStandardError)));
        end

        function qualityDiagnosticsFlagKnownDriftWithoutChangingEstimate(testCase)
            clean = 10 + repmat([-1, 1], 1, 10);
            drifted = clean + linspace(0, 20, 20);
            waveforms = [clean; drifted];

            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                waveforms, SampleIndices=1:20, Method="mean", ...
                NonstationarityThreshold=3);

            testCase.verifyEqual(level, mean(waveforms, 2), AbsTol=1e-12);
            testCase.verifyEqual(diagnostics.slopePerSample(1), 0, ...
                AbsTol=0.02);
            testCase.verifyGreaterThan(diagnostics.slopePerSample(2), 0.9);
            testCase.verifyFalse( ...
                diagnostics.qualityFlags.nonstationaryBaseline(1));
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.nonstationaryBaseline(2));
            testCase.verifyTrue(diagnostics.validEventMask(1));
            testCase.verifyFalse(diagnostics.validEventMask(2));
            testCase.verifyEqual( ...
                diagnostics.thresholds.nonstationarity, 3);
        end

        function robustDriftSlopeRejectsIsolatedContamination(testCase)
            sampleIndices = 1:20;
            clean = 10 + 0.25 * sampleIndices + ...
                0.1 * repmat([-1, 1], 1, 10);
            contaminated = clean;
            contaminated(end) = contaminated(end) + 20;

            [levels, diagnostics] = pds.preprocess.estimatePedestal( ...
                [clean; contaminated], SampleIndices=sampleIndices, ...
                Method="mean", OutlierThreshold=3.5);

            testCase.verifyEqual(levels, mean([clean; contaminated], 2), ...
                AbsTol=1e-12);
            testCase.verifyEqual(diagnostics.slopePerSample(1), 0.25, ...
                AbsTol=0.02);
            testCase.verifyEqual(diagnostics.slopePerSample(2), 0.25, ...
                AbsTol=0.02);
            testCase.verifyLessThan(abs(diff( ...
                diagnostics.slopePerSample)), 0.01);
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.pretriggerContaminated(2));
        end

        function qualityDiagnosticsTraceOutliersAndContamination(testCase)
            clean = repmat([-1, 1], 1, 10);
            oneSpike = clean;
            oneSpike(8) = 20;
            manySpikes = clean;
            manySpikes([3, 7, 11, 15]) = 20;

            [~, diagnostics] = pds.preprocess.estimatePedestal( ...
                [clean; oneSpike; manySpikes], SampleIndices=1:20, ...
                Method="median", OutlierThreshold=3.5, ...
                MaximumOutlierFraction=0.1);

            testCase.verifyEqual(diagnostics.outlierFraction, ...
                [0; 1 / 20; 4 / 20], AbsTol=1e-12);
            testCase.verifyFalse( ...
                diagnostics.qualityFlags.pretriggerContaminated(1));
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.pretriggerContaminated(2));
            testCase.verifyFalse( ...
                diagnostics.qualityFlags.excessiveOutliers(2));
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.excessiveOutliers(3));
            testCase.verifyFalse(diagnostics.validEventMask(2));
            testCase.verifyEqual(diagnostics.thresholds.outlier, 3.5);
            testCase.verifyEqual( ...
                diagnostics.thresholds.maximumOutlierFraction, 0.1);
        end

        function qualityDiagnosticsFlagShortAndUnstableRegions(testCase)
            short = repmat([-1, 1], 1, 3);
            [~, shortDiagnostics] = pds.preprocess.estimatePedestal( ...
                short, SampleIndices=1:6, Method="mean");
            testCase.verifyTrue( ...
                shortDiagnostics.qualityFlags.insufficientSamples);
            testCase.verifyFalse(shortDiagnostics.validEventMask);

            clean = repmat([-1, 1], 1, 20);
            stepped = [repmat([-1, 1], 1, 10), ...
                10 + repmat([-1, 1], 1, 10)];
            heteroscedastic = [repmat([-1, 1], 1, 10), ...
                repmat([-8, 8], 1, 10)];
            [~, diagnostics] = pds.preprocess.estimatePedestal( ...
                [clean; stepped; heteroscedastic], ...
                SampleIndices=1:40, Method="mean", ...
                QualityBlockCount=4, BlockLocationThreshold=3, ...
                BlockScaleRatioThreshold=3);

            testCase.verifyFalse(diagnostics.qualityFlags.unstableBlocks(1));
            testCase.verifyTrue(diagnostics.qualityFlags.unstableBlocks(2));
            testCase.verifyTrue(diagnostics.qualityFlags.unstableBlocks(3));
            testCase.verifySize(diagnostics.qualityBlockMeans, [3, 4]);
            testCase.verifySize(diagnostics.qualityBlockScales, [3, 4]);
            testCase.verifyGreaterThan( ...
                diagnostics.blockScaleRatio(3), 3);
            testCase.verifyEqual(diagnostics.thresholds.qualityBlockCount, 4);
        end

        function oneSamplePretriggerIsInsufficientButNumericallySafe(testCase)
            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                [12, 99], SampleIndices=1, Method="mean");

            testCase.verifyEqual(level, 12);
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.insufficientSamples);
            testCase.verifyFalse(diagnostics.validEventMask);
            testCase.verifyEqual(diagnostics.slopePerSample, 0);
            testCase.verifyEqual(diagnostics.nonstationarityScore, 0);
            testCase.verifyEqual(diagnostics.outlierFraction, 0);
            testCase.verifyEqual(diagnostics.effectiveQualityBlockCount, 1);
        end

        function broadPretriggerPulseIsFlaggedAsContamination(testCase)
            clean = repmat([-1, 1], 1, 20);
            broadPulse = clean;
            broadPulse(15:24) = broadPulse(15:24) + 12;
            [~, diagnostics] = pds.preprocess.estimatePedestal( ...
                [clean; broadPulse], SampleIndices=1:40, Method="median", ...
                OutlierThreshold=3.5, MaximumOutlierFraction=0.1);

            testCase.verifyFalse( ...
                diagnostics.qualityFlags.pretriggerContaminated(1));
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.pretriggerContaminated(2));
            testCase.verifyTrue( ...
                diagnostics.qualityFlags.excessiveOutliers(2));
            testCase.verifyFalse(diagnostics.validEventMask(2));
        end

        function invalidQualityThresholdsAreRejected(testCase)
            waveform = 1:16;
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                waveform, SampleIndices=1:16, NonstationarityThreshold=0), ...
                ['pds:preprocess:estimatePedestal:', ...
                'InvalidNonstationarityThreshold']);
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                waveform, SampleIndices=1:16, MaximumOutlierFraction=1.1), ...
                ['pds:preprocess:estimatePedestal:', ...
                'InvalidMaximumOutlierFraction']);
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                waveform, SampleIndices=1:16, QualityBlockCount=2.5), ...
                'pds:preprocess:estimatePedestal:InvalidQualityBlockCount');
        end

        function rejectsInexactIntegerQualityOptionsBeforeConversion(testCase)
            unsafe = uint64(flintmax) + uint64(2);
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                1:16, SampleIndices=1:16, ...
                MinimumQualitySampleCount=unsafe), ...
                ['pds:preprocess:estimatePedestal:', ...
                'InvalidMinimumQualitySampleCount']);
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                1:16, SampleIndices=1:16, QualityBlockCount=unsafe), ...
                'pds:preprocess:estimatePedestal:InvalidQualityBlockCount');
            testCase.verifyError(@() pds.preprocess.estimatePedestal( ...
                1:16, SampleIndices=1:16, OutlierThreshold=unsafe), ...
                'pds:preprocess:estimatePedestal:InvalidOutlierThreshold');
        end
    end
end
