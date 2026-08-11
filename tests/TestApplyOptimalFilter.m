classdef TestApplyOptimalFilter < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function scoreEqualsFinalFilteredSampleAndDotProduct(testCase)
            weights = [0.1, 0.2, 0.4, 0.2, 0.1];
            coefficients = fliplr(weights);
            waveform = [1, 2, 3, 4, 5];

            [score, filtered] = pds.signal.applyOptimalFilter( ...
                waveform, coefficients, PedestalSampleCount=0);

            testCase.verifyEqual(score, dot(weights, waveform), 'AbsTol', 1e-12);
            testCase.verifyEqual(score, filtered(end), 'AbsTol', 1e-12);
        end

        function matricesUseRowsAsRecordsAndRemovePerRecordPedestal(testCase)
            weights = [0, 0, 0.5, 0.5];
            coefficients = fliplr(weights);
            waveforms = [10, 10, 12, 14; -3, -3, 1, 3];

            scores = pds.signal.applyOptimalFilter( ...
                waveforms, coefficients, PedestalSampleCount=2);

            testCase.verifyEqual(scores, [3; 5], 'AbsTol', 1e-12);
        end

        function integerWaveformsAreConvertedToFloatingPoint(testCase)
            waveforms = uint16([10, 10, 12, 14; 20, 20, 24, 26]);
            coefficients = [0.5, 0.5, 0, 0];

            [scores, filtered] = pds.signal.applyOptimalFilter( ...
                waveforms, coefficients, PedestalSampleCount=uint16(2));

            expectedScores = pds.signal.applyOptimalFilter( ...
                double(waveforms), coefficients, PedestalSampleCount=2);
            testCase.verifyClass(scores, 'double');
            testCase.verifyClass(filtered, 'double');
            testCase.verifyEqual(scores, expectedScores, 'AbsTol', 1e-12);
        end

        function invalidDimensionsAreRejected(testCase)
            testCase.verifyError( ...
                @() pds.signal.applyOptimalFilter(zeros(2, 4), ones(1, 3)), ...
                'pds:signal:applyOptimalFilter:LengthMismatch');
            testCase.verifyError( ...
                @() pds.signal.applyOptimalFilter([1, NaN], [1, 1]), ...
                'pds:signal:applyOptimalFilter:NonfiniteWaveforms');
        end
    end
end
