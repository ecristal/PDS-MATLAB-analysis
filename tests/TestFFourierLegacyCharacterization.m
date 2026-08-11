classdef TestFFourierLegacyCharacterization < matlab.unittest.TestCase
    properties
        LegacyDirectory
    end

    methods (TestClassSetup)
        function selectPreservedLegacyImplementation(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.LegacyDirectory = fullfile(repositoryRoot, ...
                'legacy', 'functions', 'f_fourier');
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));
            addpath(testCase.LegacyDirectory, '-begin');
            clear f_fourier;
            testCase.verifyEqual(string(which('f_fourier')), ...
                string(fullfile(testCase.LegacyDirectory, 'f_fourier.m')));
        end
    end

    methods (Test)
        function twoArgumentCallFailsAtTheLegacyDisplayArgument(testCase)
            testCase.verifyError( ...
                @() f_fourier([0, 1, 0, -1], 0.25), ...
                'MATLAB:minrhs');
        end

        function legacyRmsExcludesDcAfterReportingItsAmplitude(testCase)
            waveform = 3 * ones(1, 8);

            [~, amplitude, ~, psd, rmsPerRecord] = ...
                f_fourier(waveform, 1 / 8, false, "abs", false);

            testCase.verifyEqual(amplitude(1), 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(psd(1), 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(rmsPerRecord, 0, 'AbsTol', 1e-12);
        end

        function legacyOddLengthLastPositiveBinIsNotDoubled(testCase)
            sampleCount = 15;
            toneBin = 7;
            peakAmplitude = 1.7;
            sampleIndex = 0:(sampleCount - 1);
            waveform = peakAmplitude * cos(2 * pi * toneBin * sampleIndex / sampleCount);

            [~, amplitude] = ...
                f_fourier(waveform, 1 / sampleCount, false, "abs", false);

            testCase.verifyEqual(amplitude(toneBin + 1), peakAmplitude / 2, ...
                'AbsTol', 1e-12);
        end
    end
end
