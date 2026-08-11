classdef TestOptimalFilterCompatibility < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSources(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            compatibilityDirectory = fullfile(sourceDirectory, 'compat');
            addpath(sourceDirectory);
            addpath(compatibilityDirectory);
            testCase.addTeardown(@() rmpath(compatibilityDirectory));
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function miDftDelegatesToNamespacedTransformAndPsdConvention(testCase)
            waveform = [1, 2, 3, 4, 3, 2, 1, 0];
            window = pds.signal.createWindow(8, "tukey", TukeyRatio=0.5);
            sampleRateHz = 8;

            testCase.verifyWarning( ...
                @() callMiDft(waveform, window, sampleRateHz), ...
                'PDS:mi_dft:Deprecated');
            warning('off', 'PDS:mi_dft:Deprecated');
            testCase.addTeardown(@() warning('on', 'PDS:mi_dft:Deprecated'));
            [frequencyHz, coefficients, psd] = mi_dft( ...
                waveform, window, sampleRateHz, 0);

            expected = fft(waveform .* window);
            testCase.verifyEqual(coefficients, expected, 'AbsTol', 1e-12);
            testCase.verifyEqual(frequencyHz, 0:7);
            testCase.verifyEqual(psd, abs(expected).^2 / ...
                (sampleRateHz * sum(window.^2)), 'AbsTol', 1e-12);
        end

        function miIdtftDelegatesToInverseDft(testCase)
            coefficients = fft([1, 2, 3, 4, 5]);
            testCase.verifyWarning(@() mi_idtft(coefficients), ...
                'PDS:mi_idtft:Deprecated');
            warning('off', 'PDS:mi_idtft:Deprecated');
            testCase.addTeardown(@() warning('on', 'PDS:mi_idtft:Deprecated'));
            testCase.verifyEqual(mi_idtft(coefficients), ifft(coefficients), ...
                'AbsTol', 1e-12);
        end

        function historicalOptimalFilterSignatureReturnsUnitGainFilter(testCase)
            reference = [10, 10, 11, 13, 12, 10, 10, 10];
            signalWaveforms = [reference; reference];
            warning('off', 'PDS:optimal_filter:Deprecated');
            testCase.addTeardown(@() warning('on', 'PDS:optimal_filter:Deprecated'));

            coefficients = optimal_filter_for_daphne_gpessina_function( ...
                signalWaveforms, [], false, 1, false, false, false, 2);
            score = pds.signal.applyOptimalFilter( ...
                mean(signalWaveforms, 1), coefficients, PedestalSampleCount=2);

            testCase.verifyEqual(score, 1, 'AbsTol', 1e-12);
            testCase.verifySize(coefficients, [1, 8]);
        end

        function historicalFiveThroughEightArgumentFormsAreAccepted(testCase)
            rng(31, 'twister');
            sampleCount = 256;
            reference = 100 + [zeros(1, 210), 1, 2, 1, zeros(1, 43)];
            signals = [reference; reference];
            noise = 100 + 0.1 * randn(12, sampleCount);
            warning('off', 'PDS:optimal_filter:Deprecated');
            testCase.addTeardown(@() warning('on', 'PDS:optimal_filter:Deprecated'));

            coefficients5 = optimal_filter_for_daphne_gpessina_function( ...
                signals, noise, false, 1, false);
            coefficients6 = optimal_filter_for_daphne_gpessina_function( ...
                signals, noise, false, 1, false, false);
            coefficients7 = optimal_filter_for_daphne_gpessina_function( ...
                signals, noise, false, 1, false, false, false);
            coefficients8 = optimal_filter_for_daphne_gpessina_function( ...
                signals, noise, false, 1, false, false, false, 200);

            testCase.verifySize(coefficients5, [1, sampleCount]);
            testCase.verifyEqual(coefficients5, coefficients6, 'AbsTol', 1e-12);
            testCase.verifyEqual(coefficients7, coefficients8, 'AbsTol', 1e-12);
        end

        function unsupportedLegacyPreprocessingIsRejected(testCase)
            reference = [10, 10, 11, 13, 12, 10, 10, 10];
            testCase.verifyError(@() optimal_filter_for_daphne_gpessina_function( ...
                reference, [], true, 2, false, false, false, 2), ...
                'PDS:optimal_filter:UnsupportedDecimation');
            testCase.verifyError(@() optimal_filter_for_daphne_gpessina_function( ...
                reference, [], false, 1, false, true, false, 2), ...
                'PDS:optimal_filter:UnsupportedLowPass');
        end
    end
end

function callMiDft(waveform, window, sampleRateHz)
    [~, ~, ~] = mi_dft(waveform, window, sampleRateHz, 0);
end
