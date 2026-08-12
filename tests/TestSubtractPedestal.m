classdef TestSubtractPedestal < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function rejectsNonmatrixEmptyAndColumnVectorWaveforms(testCase)
            testCase.verifyError(@() pds.preprocess.subtractPedestal( ...
                zeros(2, 2, 2), 0), ...
                'pds:preprocess:subtractPedestal:InvalidWaveforms');
            testCase.verifyError(@() pds.preprocess.subtractPedestal( ...
                [], 0), ...
                'pds:preprocess:subtractPedestal:InvalidWaveforms');
            testCase.verifyError(@() pds.preprocess.subtractPedestal( ...
                [1; 2; 3], [1; 2; 3]), ...
                'pds:preprocess:subtractPedestal:AmbiguousColumnVector');
            testCase.verifyError(@() pds.preprocess.subtractPedestal( ...
                zeros(4, 2), [1, 2; 3, 4]), ...
                'pds:preprocess:subtractPedestal:InvalidPedestalLevel');
        end

        function subtractsOneLevelPerIntegerWaveformWithoutUnderflow(testCase)
            waveforms = uint16([100, 101, 99; 200, 199, 201]);

            corrected = pds.preprocess.subtractPedestal( ...
                waveforms, [100; 200]);

            testCase.verifyClass(corrected, 'double');
            testCase.verifyEqual(corrected, [0, 1, -1; 0, -1, 1]);
        end
    end
end
