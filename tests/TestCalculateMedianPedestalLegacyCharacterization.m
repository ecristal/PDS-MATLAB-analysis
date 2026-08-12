classdef TestCalculateMedianPedestalLegacyCharacterization < matlab.unittest.TestCase
    methods (TestClassSetup)
        function exposeLegacyPedestalFunction(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            legacyDirectory = fullfile(repositoryRoot, 'src', 'daphne');
            originalPath = path;
            testCase.addTeardown(@() restorePathAndFunction(originalPath));
            addpath(legacyDirectory, '-begin');
            clear calculateMedianPedestal;
        end
    end

    methods (Test)
        function matchesHistoricalRandomWindowFormula(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));

            waveform = 1:20;
            pedestalLimit = 8;
            averageWidth = 3;
            regionCount = 7;
            seed = 41;

            rng(seed, 'multFibonacci');
            expectedReturnedState = rng;
            starts = randi([1, pedestalLimit - averageWidth + 1], ...
                1, regionCount);
            means = arrayfun(@(index) mean( ...
                waveform(index:(index + averageWidth - 1))), starts);
            expectedQuantiles = quantile(means, [0.25, 0.5, 0.75]);

            [pedestal, q25, q75, returnedState] = ...
                calculateMedianPedestal(waveform, pedestalLimit, ...
                averageWidth, regionCount, seed);

            testCase.verifyEqual([q25, pedestal, q75], expectedQuantiles, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(returnedState.Type, expectedReturnedState.Type);
            testCase.verifyEqual(returnedState.State, expectedReturnedState.State);
        end

        function reseedsAndAdvancesGlobalRandomGenerator(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));

            rng(991, 'twister');
            stateBeforeCall = rng;
            [~, ~, ~, returnedState] = calculateMedianPedestal( ...
                1:30, 20, 4, 8, 17);
            stateAfterCall = rng;

            testCase.verifyNotEqual(stateAfterCall.Type, stateBeforeCall.Type);
            testCase.verifyNotEqual(stateAfterCall.State, returnedState.State);
        end

        function identicalSeedProducesIdenticalOutputs(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));
            waveform = sin(1:50) + 100;

            first = cell(1, 4);
            second = cell(1, 4);
            [first{:}] = calculateMedianPedestal(waveform, 30, 5, 12, 8);
            [second{:}] = calculateMedianPedestal(waveform, 30, 5, 12, 8);

            testCase.verifyEqual(first{1}, second{1});
            testCase.verifyEqual(first{2}, second{2});
            testCase.verifyEqual(first{3}, second{3});
            testCase.verifyEqual(first{4}.State, second{4}.State);
        end

        function constantWaveformProducesExactPedestal(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));

            [pedestal, q25, q75] = calculateMedianPedestal( ...
                123.5 * ones(1, 40), 25, 6, 15, 3);

            testCase.verifyEqual([q25, pedestal, q75], [123.5, 123.5, 123.5]);
        end

        function historicalValidationIdentifiersAreStable(testCase)
            waveform = 1:10;
            testCase.verifyError(@() calculateMedianPedestal( ...
                waveform, 0, 2, 3, 1), ...
                'calculateMedianPedestal:InvalidPedestalLimit');
            testCase.verifyError(@() calculateMedianPedestal( ...
                waveform, 5, 0, 3, 1), ...
                'calculateMedianPedestal:InvalidAverageWidth');
            testCase.verifyError(@() calculateMedianPedestal( ...
                waveform, 4, 5, 3, 1), ...
                'calculateMedianPedestal:WindowTooLong');
            testCase.verifyError(@() calculateMedianPedestal( ...
                waveform, 5, 2, 0, 1), ...
                'calculateMedianPedestal:InvalidNumberOfRegions');
        end
    end
end

function restorePathAndFunction(originalPath)
    path(originalPath);
    clear calculateMedianPedestal;
end
