classdef TestEstimateNoisePsd < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function rectangularWindowSatisfiesBilateralParseval(testCase)
            sampleRateHz = 32;
            noise = [1:16; 16:-1:1];
            [psd, frequencyHz, info] = pds.signal.estimateNoisePsd( ...
                noise, 1 / sampleRateHz, Window="rectangular", RemoveMean=true);

            centered = noise - mean(noise, 2);
            deltaF = sampleRateHz / size(noise, 2);
            expectedPower = mean(mean(centered.^2, 2));
            testCase.verifyEqual(sum(psd) * deltaF, expectedPower, 'AbsTol', 1e-12);
            testCase.verifySize(psd, [1, 16]);
            testCase.verifyEqual(frequencyHz, [0:8, -7:-1] * 2, 'AbsTol', 1e-12);
            testCase.verifyEqual(info.windowName, "rectangular");
        end

        function tukeyWindowUsesWindowPowerNormalization(testCase)
            sampleRateHz = 64;
            noise = reshape(1:64, 2, 32);
            [psd, ~, info] = pds.signal.estimateNoisePsd( ...
                noise, 1 / sampleRateHz, Window="tukey", TukeyRatio=0.25, ...
                RemoveMean=false);

            window = pds.signal.createWindow(32, "tukey", TukeyRatio=0.25);
            expectedPower = mean(sum((noise .* window).^2, 2) / sum(window.^2));
            deltaF = sampleRateHz / 32;
            testCase.verifyEqual(sum(psd) * deltaF, expectedPower, 'AbsTol', 1e-10);
            testCase.verifyEqual(info.windowPower, sum(window.^2), 'AbsTol', 1e-12);
            testCase.verifyEqual(info.tukeyRatio, 0.25);
        end

        function fixedWhiteNoiseProducesFiniteNonnegativePsd(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));
            rng(7, "twister");
            noise = randn(128, 64);

            psd = pds.signal.estimateNoisePsd(noise, 1 / 62.5e6);

            testCase.verifyTrue(all(isfinite(psd)));
            testCase.verifyGreaterThanOrEqual(psd, zeros(size(psd)));
            nonDcPsd = psd(2:end);
            testCase.verifyLessThan(max(nonDcPsd) / min(nonDcPsd), 3);
        end

        function rowAndColumnVectorsRepresentSingleRecords(testCase)
            noise = 1:16;
            rowPsd = pds.signal.estimateNoisePsd(noise, 1);
            columnPsd = pds.signal.estimateNoisePsd(noise.', 1);
            testCase.verifyEqual(columnPsd, rowPsd, 'AbsTol', 1e-12);
        end

        function integerNoiseIsConvertedToFloatingPoint(testCase)
            noise = uint16([10:17; 20:27]);
            actual = pds.signal.estimateNoisePsd( ...
                noise, 0.25, Window="hann", RemoveMean=true);
            expected = pds.signal.estimateNoisePsd( ...
                double(noise), 0.25, Window="hann", RemoveMean=true);

            testCase.verifyClass(actual, 'double');
            testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12);
        end

        function integerScalarOptionsAreConvertedToFloatingPoint(testCase)
            noise = [1:8; 2:9];
            actual = pds.signal.estimateNoisePsd( ...
                noise, uint16(1), Window="tukey", ...
                TukeyRatio=uint8(1), RemoveMean=true);
            expected = pds.signal.estimateNoisePsd( ...
                noise, 1, Window="hann", RemoveMean=true);

            testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12);
        end

        function invalidInputsAreRejected(testCase)
            testCase.verifyError(@() pds.signal.estimateNoisePsd([1, NaN], 1), ...
                'pds:signal:estimateNoisePsd:NonfiniteNoise');
            testCase.verifyError(@() pds.signal.estimateNoisePsd([1, 1i], 1), ...
                'pds:signal:estimateNoisePsd:NonrealNoise');
            testCase.verifyError(@() pds.signal.estimateNoisePsd(zeros(2, 2, 2), 1), ...
                'pds:signal:estimateNoisePsd:NoiseDimensions');
        end
    end
end
