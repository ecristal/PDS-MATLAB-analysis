classdef TestEstimateDiscreteTransferFunction < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function noFiniteAiccUsesApiIdentifierAndRestoresRng(testCase)
            warningState = warning('off', 'all');
            warningCleanup = onCleanup(@() warning(warningState));
            rng(123, 'twister');
            inputSignal = randn(8, 1);
            outputSignal = randn(8, 1);
            callerState = rng;

            testCase.verifyError(@() ...
                pds.identification.estimateDiscreteTransferFunction( ...
                inputSignal, outputSignal, SampleTime=0.1, MaxOrder=4, ...
                DelayRange=0, SelectionCriterion="aicc"), ...
                ['pds:identification:estimateDiscreteTransferFunction:' ...
                'NoFiniteSelectionScore']);
            testCase.verifyEqual(rng, callerState);
        end

        function bestFitDoesNotRequireFiniteAicc(testCase)
            sampleTime = 0.1;
            rng(2, 'twister');
            inputSignal = randn(8, 1);
            outputSignal = randn(8, 1);
            warningState = warning('off', 'all');
            warningCleanup = onCleanup(@() warning(warningState));

            [~, diagnostics] = ...
                pds.identification.estimateDiscreteTransferFunction( ...
                inputSignal, outputSignal, SampleTime=sampleTime, ...
                MaxOrder=5, DelayRange=0, ...
                SelectionCriterion="best-fit");

            candidates = diagnostics.candidateTable;
            eligible = candidates.stable & ...
                isfinite(candidates.fitPercent) & ...
                isfinite(candidates.rmse) & ...
                isfinite(candidates.nrmse);
            expectedFit = max(candidates.fitPercent(eligible));

            testCase.verifyEqual( ...
                diagnostics.selectedFitPercent, expectedFit, AbsTol=1e-10);
            selected = candidates.poleOrder == ...
                diagnostics.selectedPoleOrder & ...
                candidates.delaySamples == ...
                diagnostics.selectedDelaySamples;
            testCase.verifyTrue(isinf(candidates.aicc(selected)));
            clear warningCleanup
        end

        function informationCriteriaCountDiscreteFreeCoefficients(testCase)
            sampleTime = 0.1;
            sampleIndex = (0:39).';
            inputSignal = sin(0.21 * sampleIndex) + ...
                0.2 * cos(0.47 * sampleIndex);
            outputSignal = filter([0, 0.3], [1, -0.7], inputSignal);

            [~, diagnostics] = ...
                pds.identification.estimateDiscreteTransferFunction( ...
                inputSignal, outputSignal, SampleTime=sampleTime, ...
                MaxOrder=2, DelayRange=0, ...
                SelectionCriterion="best-fit");

            candidates = diagnostics.candidateTable;
            sampleCount = numel(inputSignal);
            for row = 1:height(candidates)
                if candidates.zeroOrder(row) == 0
                    parameterCount = candidates.poleOrder(row) + 1;
                else
                    parameterCount = candidates.poleOrder(row) + ...
                        candidates.zeroOrder(row);
                end
                protectedMse = max(candidates.rmse(row) ^ 2, ...
                    realmin('double'));
                expectedBic = sampleCount * log(protectedMse) + ...
                    parameterCount * log(sampleCount);
                expectedAic = sampleCount * log(protectedMse) + ...
                    2 * parameterCount;
                expectedAicc = expectedAic + ...
                    2 * parameterCount * (parameterCount + 1) / ...
                    (sampleCount - parameterCount - 1);

                testCase.verifyEqual( ...
                    candidates.bic(row), expectedBic, AbsTol=1e-10);
                testCase.verifyEqual( ...
                    candidates.aicc(row), expectedAicc, AbsTol=1e-10);
            end
        end

        function recoversDiscreteDelayAndExposesCandidateMetrics(testCase)
            sampleTime = 0.1;
            sampleCount = 250;
            inputSignal = zeros(sampleCount, 1);
            inputSignal(25) = 1;
            delayedInput = [zeros(4, 1); inputSignal(1:end-4)];
            outputSignal = filter(0.25, [1, -0.8], delayedInput);

            [~, diagnostics] = ...
                pds.identification.estimateDiscreteTransferFunction( ...
                inputSignal, outputSignal, SampleTime=sampleTime, ...
                MaxOrder=2, DelayRange=0:5, FitTolerance=0.1);

            testCase.verifyEqual(diagnostics.selectedDelaySamples, 4);
            testCase.verifyTrue(all(ismember( ...
                ["fitPercent", "rmse", "nrmse", "bic", "aicc", ...
                "stable", "valid", "failureMessage"], ...
                string(diagnostics.candidateTable.Properties.VariableNames))));
        end

        function identifiesDirectStableIirInInverseZ(testCase)
            sampleTime = 0.1;
            sampleIndex = (0:299).';
            inputSignal = sin(0.17 * sampleIndex) + ...
                0.35 * sin(0.53 * sampleIndex);
            outputSignal = filter([0, 0.3], [1, -0.7], inputSignal);

            [model, diagnostics] = ...
                pds.identification.estimateDiscreteTransferFunction( ...
                inputSignal, outputSignal, SampleTime=sampleTime, ...
                MaxOrder=2, DelayRange=0, FitTolerance=0.5);

            testCase.verifyEqual(model.Ts, sampleTime);
            testCase.verifyEqual(string(model.Variable), "z^-1");
            testCase.verifyTrue(isstable(model));
            testCase.verifyEqual(diagnostics.domain, "discrete");
            testCase.verifyLessThanOrEqual(diagnostics.selectedPoleOrder, 2);
            testCase.verifyGreaterThan(diagnostics.selectedFitPercent, 95);

            numerator = model.Numerator;
            denominator = model.Denominator;
            reconstructed = filter(numerator, denominator, inputSignal);
            transientEnd = 30;
            testCase.verifyLessThan( ...
                norm(reconstructed(transientEnd:end) - ...
                outputSignal(transientEnd:end)) / ...
                norm(outputSignal(transientEnd:end)), 0.05);
        end
    end
end
