classdef TestPrepareSinglePeTemplate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function subtractsBaselinePreservesPolarityAndNormalizesPeak(testCase)
            positive = [10, 10, 10, 12, 15, 11, 9];
            [preparedPositive, diagnosticsPositive] = ...
                pds.identification.prepareSinglePeTemplate( ...
                positive, BaselineIndices=1:3, Polarity="positive");

            testCase.verifyEqual(preparedPositive, ...
                [0, 0, 0, 0.4, 1, 0.2, -0.2], AbsTol=1e-12);
            testCase.verifyEqual(diagnosticsPositive.baseline, 10);
            testCase.verifyEqual(diagnosticsPositive.baselineIndices, 1:3);
            testCase.verifyEqual(diagnosticsPositive.requestedPolarity, ...
                "positive");
            testCase.verifyEqual(diagnosticsPositive.detectedPolarity, ...
                "positive");
            testCase.verifyEqual(diagnosticsPositive.polarity, "positive");
            testCase.verifyEqual(diagnosticsPositive.peakIndex, 5);
            testCase.verifyEqual( ...
                diagnosticsPositive.peakAmplitudeBeforeNormalization, 5);
            testCase.verifyEqual(diagnosticsPositive.normalizationScale, 1 / 5);
            testCase.verifyEqual(diagnosticsPositive.sampleCount, 7);
            testCase.verifyEqual(diagnosticsPositive.peakMagnitudeBeforeNormalization, 5);

            negative = 20 - [0, 0, 0, 1, 4, 2, -0.5];
            [preparedNegative, diagnosticsNegative] = ...
                pds.identification.prepareSinglePeTemplate( ...
                negative, BaselineIndices=1:3, Polarity="auto");
            testCase.verifyEqual(min(preparedNegative), -1, AbsTol=1e-12);
            testCase.verifyEqual(diagnosticsNegative.baseline, 20);
            testCase.verifyEqual(diagnosticsNegative.baselineIndices, 1:3);
            testCase.verifyEqual(diagnosticsNegative.requestedPolarity, "auto");
            testCase.verifyEqual(diagnosticsNegative.detectedPolarity, "negative");
            testCase.verifyEqual(diagnosticsNegative.polarity, "negative");
            testCase.verifyEqual(diagnosticsNegative.normalization, "peak-magnitude");
            testCase.verifyEqual(diagnosticsNegative.peakIndex, 5);
            testCase.verifyEqual( ...
                diagnosticsNegative.peakAmplitudeBeforeNormalization, -4);
            testCase.verifyEqual( ...
                diagnosticsNegative.peakMagnitudeBeforeNormalization, 4);
            testCase.verifyEqual(diagnosticsNegative.normalizationScale, 1 / 4);
            testCase.verifyEqual(diagnosticsNegative.sampleCount, 7);
        end
    end
end
