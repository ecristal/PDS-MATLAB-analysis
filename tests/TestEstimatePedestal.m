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

        function medianRejectsSingleLargePretriggerOutlier(testCase)
            waveforms = [10, 10, 1000, 10, 40; 20, 20, 20, -900, 50];

            [level, diagnostics] = pds.preprocess.estimatePedestal( ...
                waveforms, SampleIndices=1:4, Method="median");

            testCase.verifyEqual(level, [10; 20]);
            testCase.verifyEqual(diagnostics.method, "median");
            testCase.verifyEqual(diagnostics.sampleIndices, 1:4);
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
            testCase.verifyEqual( ...
                diagnostics.pedestalStandardError, ...
                sqrt(pi / 2) * diagnostics.sampleNoiseSigma / sqrt(12), ...
                AbsTol=10 * eps);
        end
    end
end
