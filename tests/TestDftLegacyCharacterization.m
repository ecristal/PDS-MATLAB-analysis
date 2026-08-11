classdef TestDftLegacyCharacterization < matlab.unittest.TestCase
    methods (TestClassSetup)
        function exposePreservedLegacyImplementations(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            originalPath = path;
            testCase.addTeardown(@() restorePath(originalPath));
            addpath(fullfile(repositoryRoot, 'legacy', 'functions', 'mi_dft'), '-begin');
            addpath(fullfile(repositoryRoot, 'legacy', 'functions', 'mi_idtft'), '-begin');
            clear mi_dft mi_idtft;
        end
    end

    methods (Test)
        function directTransformMatchesHistoricalFormula(testCase)
            waveform = [1, -2, 3, 0, 4, -1];
            sampleRate = 12;
            sampleShift = 2;
            window = [0.5, 1, 1, 1, 1, 0.5];

            [frequencyHz, coefficients, psd] = mi_dft( ...
                waveform, window, sampleRate, sampleShift);
            k = 0:(numel(waveform) - 1);
            expectedCoefficients = fft(waveform) .* ...
                exp(-1i * 2 * pi * k * sampleShift / numel(waveform));

            testCase.verifyEqual(coefficients, expectedCoefficients, 'AbsTol', 1e-12);
            testCase.verifyEqual(frequencyHz, k * sampleRate / numel(waveform), ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(psd, abs(expectedCoefficients).^2 / ...
                (sampleRate * sum(window.^2)), 'AbsTol', 1e-12);
        end

        function legacyWindowOnlyChangesPsdDenominator(testCase)
            waveform = [1, 2, 3, 4];
            [~, rectangularCoefficients, rectangularPsd] = mi_dft( ...
                waveform, ones(1, 4), 8, 0);
            [~, taperedCoefficients, taperedPsd] = mi_dft( ...
                waveform, [0.25, 1, 1, 0.25], 8, 0);

            testCase.verifyEqual(taperedCoefficients, rectangularCoefficients, ...
                'AbsTol', 1e-12);
            testCase.verifyNotEqual(taperedPsd, rectangularPsd);
        end

        function inverseTransformReconstructsDirectTransform(testCase)
            waveform = [1, -2, 0.5, 4, 0, -1];
            [~, coefficients] = mi_dft(waveform, ones(size(waveform)), 12, 0);
            reconstructed = mi_idtft(coefficients);

            testCase.verifyEqual(reconstructed, waveform, 'AbsTol', 1e-12);
        end
    end
end

function restorePath(originalPath)
    path(originalPath);
    clear mi_dft mi_idtft;
end
