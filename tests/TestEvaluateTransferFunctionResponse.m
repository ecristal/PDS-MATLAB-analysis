classdef TestEvaluateTransferFunctionResponse < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function reportsPeakUndershootAreaTailAndReturn(testCase)
            target = [0, 0, 1, 0.4, -0.2, -0.1, 0.02, 0.005, 0.001, 0];
            predicted = [0, 0, 0.9, 0.35, -0.1, -0.04, 0.015, 0.004, 0.001, 0];
            metrics = pds.identification.evaluateTransferFunctionResponse( ...
                target, predicted, SampleTime=2, TailStartIndex=5, ...
                ReturnBand=0.01, ReturnConsecutiveSamples=3);

            testCase.verifyEqual(metrics.targetPeakAmplitude, 1);
            testCase.verifyEqual(metrics.predictedPeakAmplitude, 0.9);
            testCase.verifyEqual(metrics.peakTimingErrorSamples, 0);
            testCase.verifyEqual(metrics.targetUndershootAmplitude, -0.2);
            testCase.verifyEqual(metrics.targetUndershootIndex, 5);
            testCase.verifyEqual(metrics.targetNegativeArea, 0.6, AbsTol=1e-12);
            testCase.verifyEqual(metrics.predictedNegativeArea, 0.28, AbsTol=1e-12);
            testCase.verifyTrue(metrics.targetReturnedToBand);
            testCase.verifyEqual(metrics.targetReturnIndex, 8);
            testCase.verifyEqual(metrics.targetReturnTime, 14);
            testCase.verifyTrue(metrics.targetSettledToBand);
            testCase.verifyEqual(metrics.targetSettlingIndex, 8);
            testCase.verifyGreaterThan(metrics.tailRmse, 0);
        end

        function distinguishesNoObservedReturn(testCase)
            target = [0, 1, -0.2, -0.1, -0.05];
            metrics = pds.identification.evaluateTransferFunctionResponse( ...
                target, target, SampleTime=1, TailStartIndex=3, ...
                ReturnBand=0.01, ReturnConsecutiveSamples=2);
            testCase.verifyFalse(metrics.targetReturnedToBand);
            testCase.verifyTrue(isnan(metrics.targetReturnIndex));
            testCase.verifyFalse(metrics.targetSettledToBand);
            testCase.verifyTrue(isnan(metrics.targetSettlingIndex));
            testCase.verifyEqual(metrics.rmse, 0);
        end

        function negativeAreaSeparatesPrepeakResidualFromPostpeakUndershoot(testCase)
            target = [-0.4, 0, 1, -0.2, -0.1];
            predicted = [-0.3, 0, 0.9, -0.1, 0];
            metrics = pds.identification.evaluateTransferFunctionResponse( ...
                target, predicted, SampleTime=2, TailStartIndex=4);

            testCase.verifyEqual(metrics.targetNegativeArea, 0.6, ...
                AbsTol=1e-12);
            testCase.verifyEqual(metrics.predictedNegativeArea, 0.2, ...
                AbsTol=1e-12);
            testCase.verifyEqual(metrics.targetTotalNegativeArea, 1.4, ...
                AbsTol=1e-12);
            testCase.verifyEqual(metrics.predictedTotalNegativeArea, 0.8, ...
                AbsTol=1e-12);
            testCase.verifyEqual(metrics.negativeAreaStartIndex, 3);
        end

        function distinguishesTransientBandEntryFromFinalSettling(testCase)
            target = [0, 1, 0.005, 0.004, 0.03, 0.004, 0.003];
            metrics = pds.identification.evaluateTransferFunctionResponse( ...
                target, target, SampleTime=1, TailStartIndex=3, ...
                ReturnBand=0.01, ReturnConsecutiveSamples=2);

            testCase.verifyTrue(metrics.targetReturnedToBand);
            testCase.verifyEqual(metrics.targetReturnIndex, 3);
            testCase.verifyTrue(metrics.targetSettledToBand);
            testCase.verifyEqual(metrics.targetSettlingIndex, 6);
            testCase.verifyEqual(metrics.targetSettlingTime, 5);
        end

        function rejectsInexactIntegerSignalsAndOptions(testCase)
            unsafe = uint64(flintmax) + uint64(2);
            testCase.verifyError(@() ...
                pds.identification.evaluateTransferFunctionResponse( ...
                [uint64(0), unsafe], [0, 1], SampleTime=1), ...
                ['pds:identification:evaluateTransferFunctionResponse:', ...
                'InvalidSignals']);
            testCase.verifyError(@() ...
                pds.identification.evaluateTransferFunctionResponse( ...
                [0, 1], [0, 1], SampleTime=unsafe), ...
                ['pds:identification:evaluateTransferFunctionResponse:', ...
                'InvalidSampleTime']);
            testCase.verifyError(@() ...
                pds.identification.evaluateTransferFunctionResponse( ...
                [0, 1], [0, 1], SampleTime=1, ...
                ReturnConsecutiveSamples=unsafe), ...
                ['pds:identification:evaluateTransferFunctionResponse:', ...
                'InvalidReturnConsecutiveSamples']);
        end
    end
end
