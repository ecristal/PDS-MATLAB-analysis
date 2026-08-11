classdef TestDesignOptimalFilter < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function whiteNoiseProducesUnitGainMatchedFilter(testCase)
            template = [0, 0, 1, 3, 2, 0, 0, 0];
            [coefficients, diagnostics] = pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="white", PedestalSampleCount=2);

            expectedWeights = template / dot(template, template);
            score = pds.signal.applyOptimalFilter( ...
                template, coefficients, PedestalSampleCount=2);

            testCase.verifyEqual(diagnostics.weights, expectedWeights, 'AbsTol', 1e-12);
            testCase.verifyEqual(coefficients, fliplr(expectedWeights), 'AbsTol', 1e-12);
            testCase.verifyEqual(score, 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(diagnostics.noiseSource, "white");
            testCase.verifyEqual(diagnostics.filterCoefficients, coefficients);
            testCase.verifySize(diagnostics.regularizedBinMask, size(template));
            testCase.verifyEqual(diagnostics.scoreIndex, numel(template));
            testCase.verifyEqual(diagnostics.latencySamples, numel(template) - 1);
            testCase.verifyEqual(diagnostics.predictedNoiseVariance, ...
                diagnostics.sampleRateHz / diagnostics.gainBeforeNormalization, ...
                'RelTol', 1e-12);
        end

        function autoWithoutNoiseDefaultsToWhite(testCase)
            template = [0, 1, 2, 1, 0, 0];
            [~, diagnostics] = pds.signal.designOptimalFilter( ...
                template, [], PedestalSampleCount=1);
            testCase.verifyEqual(diagnostics.noiseSource, "white");
            testCase.verifyEqual(diagnostics.noisePsd, ones(size(template)));
        end

        function integerReferenceAndNoiseAreConvertedToFloatingPoint(testCase)
            reference = uint16([100, 100, 101, 103, 102, 100, 100, 100]);
            noise = uint16([ ...
                100, 100, 101, 99, 100, 101, 100, 99; ...
                200, 200, 199, 201, 200, 199, 200, 201; ...
                300, 300, 301, 300, 299, 300, 301, 300; ...
                400, 400, 399, 400, 401, 400, 399, 400]);

            [coefficients, diagnostics] = pds.signal.designOptimalFilter( ...
                reference, noise, NoiseModel="measured", ...
                SamplePeriod=uint16(1), PedestalSampleCount=uint16(2), ...
                Window="rectangular", RegularizationFraction=uint8(1));
            score = pds.signal.applyOptimalFilter( ...
                reference, coefficients, PedestalSampleCount=uint16(2));

            testCase.verifyClass(coefficients, 'double');
            testCase.verifyClass(diagnostics.referenceTemplate, 'double');
            testCase.verifyEqual(score, 1, 'AbsTol', 1e-10);
        end

        function integerProvidedPsdAndParametricOptionsAreConverted(testCase)
            template = [0, 0, 1, 2, 1, 0, 0, 0];
            [providedCoefficients, providedInfo] = pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="provided", ...
                SamplePeriod=uint16(1), PedestalSampleCount=uint16(1), ...
                NoisePsd=uint16([1, 2, 3, 4, 5, 4, 3, 2]), ...
                RegularizationFraction=uint8(1));
            [parametricCoefficients, parametricInfo] = ...
                pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="parametric", ...
                ColoredNoiseModel="ar1", ArCoefficient=int8(0), ...
                SamplePeriod=uint16(1), NoiseSelectionSigma=uint8(2));
            [powerLawCoefficients, powerLawInfo] = ...
                pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="parametric", ...
                ColoredNoiseModel="powerlaw", ...
                PowerLawExponent=uint8(1), ...
                PowerLawCornerFrequencyHz=uint16(1), ...
                SamplePeriod=uint16(1));

            testCase.verifyTrue(all(isfinite(providedCoefficients)));
            testCase.verifyTrue(all(isfinite(parametricCoefficients)));
            testCase.verifyTrue(all(isfinite(powerLawCoefficients)));
            testCase.verifyClass(providedInfo.noisePsd, 'double');
            testCase.verifyClass(parametricInfo.noisePsd, 'double');
            testCase.verifyClass(powerLawInfo.noisePsd, 'double');
        end

        function measuredColoredNoiseUsesBilateralTukeyPsd(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));
            rng(11, "twister");
            template = [zeros(1, 4), 1, 2, 1, zeros(1, 9)];
            noise = filter(1, [1, -0.85], randn(200, 16), [], 2);

            [coefficients, diagnostics] = pds.signal.designOptimalFilter( ...
                template, noise, NoiseModel="measured", ...
                PedestalSampleCount=3, Window="tukey", TukeyRatio=0.25);

            testCase.verifySize(diagnostics.noisePsd, [1, 16]);
            testCase.verifyEqual(diagnostics.noiseSource, "measured");
            testCase.verifyEqual(diagnostics.windowName, "tukey");
            testCase.verifyTrue(all(isfinite(coefficients)));
            testCase.verifyEqual( ...
                pds.signal.applyOptimalFilter(template, coefficients, PedestalSampleCount=3), ...
                1, 'AbsTol', 1e-10);
        end

        function measuredPsdRetainsConfiguredPedestalCorrection(testCase)
            template = [zeros(1, 4), 1, 2, 1, zeros(1, 9)];
            noise = [ ...
                10 + (0:15); ...
                20 + (0:15).^2 / 20; ...
                30 + sin((0:15) / 3); ...
                40 + cos((0:15) / 4)];
            pedestalCount = 3;

            [~, diagnostics] = pds.signal.designOptimalFilter( ...
                template, noise, NoiseModel="measured", ...
                PedestalSampleCount=pedestalCount, Window="hann");
            centeredNoise = noise - mean(noise(:, 1:pedestalCount), 2);
            expectedPsd = pds.signal.estimateNoisePsd( ...
                centeredNoise, diagnostics.samplePeriod, ...
                Window="hann", RemoveMean=false);

            testCase.verifyEqual(diagnostics.noisePsd, expectedPsd, ...
                'AbsTol', 1e-12);
        end

        function providedColoredPsdIsAcceptedAndRegularized(testCase)
            template = [0, 0, 1, 2, 1, 0, 0, 0];
            providedPsd = [0, 2, 3, 4, 5, 4, 3, 2];
            [~, diagnostics] = pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="provided", NoisePsd=providedPsd, ...
                RegularizationFraction=0.1, PedestalSampleCount=2);

            testCase.verifyEqual(diagnostics.noisePsd, providedPsd);
            testCase.verifyEqual(diagnostics.psdFloor, 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(diagnostics.regularizedNoisePsd(1), 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(diagnostics.regularizedBinCount, 1);
            testCase.verifyEqual(diagnostics.noiseSource, "provided");
        end

        function ar1ParametricModelIsColoredAndSymmetric(testCase)
            template = [0, 0, 1, 2, 1, zeros(1, 11)];
            [coefficients, diagnostics] = pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="parametric", ColoredNoiseModel="ar1", ...
                ArCoefficient=0.9, PedestalSampleCount=2);

            psd = diagnostics.noisePsd;
            testCase.verifyGreaterThan(psd(1), psd(9));
            testCase.verifyEqual(psd, psd([1, end:-1:2]), 'AbsTol', 1e-12);
            testCase.verifyEqual(diagnostics.coloredNoiseModel, "ar1");
            testCase.verifyTrue(all(isfinite(coefficients)));
        end

        function powerLawParametricModelUsesFiniteDcCorner(testCase)
            template = [0, 0, 1, 2, 1, zeros(1, 11)];
            [~, diagnostics] = pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="parametric", ColoredNoiseModel="powerlaw", ...
                PowerLawExponent=1.5, PowerLawCornerFrequencyHz=1e5, ...
                SamplePeriod=1e-7, PedestalSampleCount=2);

            testCase.verifyTrue(all(isfinite(diagnostics.noisePsd)));
            testCase.verifyGreaterThan(diagnostics.noisePsd(1), diagnostics.noisePsd(9));
            testCase.verifyEqual(diagnostics.coloredNoiseModel, "powerlaw");
        end

        function estimatesColoredNoiseFromCandidatePedestalEvents(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));
            rng(21, "twister");
            sampleCount = 32;
            template = [zeros(1, 6), 0.5, 1, 2, 1, 0.5, zeros(1, 21)];
            noise = 0.15 * randn(400, sampleCount);
            signalEvents = 3 * template + 0.15 * randn(100, sampleCount);
            candidates = [noise; signalEvents];

            [~, diagnostics] = pds.signal.designOptimalFilter( ...
                template, [], NoiseModel="estimated", ...
                CandidateWaveforms=candidates, NoiseSelectionSigma=2, ...
                PedestalSampleCount=4, Window="hann");

            selected = diagnostics.selectedNoiseMask;
            trueNoiseSigma = std(diagnostics.preliminaryScores(1:400), 1);
            testCase.verifyEqual(diagnostics.noiseSource, "estimated");
            testCase.verifyEqual(diagnostics.selectedNoiseCount, sum(selected));
            testCase.verifyGreaterThan(sum(selected(1:400)), 350);
            testCase.verifyEqual(diagnostics.pedestalSigma, trueNoiseSigma, ...
                'RelTol', 0.15);
            testCase.verifyEqual(sum(selected(401:end)), 0);
            testCase.verifyTrue(all(abs( ...
                diagnostics.preliminaryScores(selected) - diagnostics.pedestalMean) ...
                <= 2 * diagnostics.pedestalSigma + 1e-12));
        end

        function invalidModelsAndPsdAreRejected(testCase)
            template = [0, 1, 2, 1];
            testCase.verifyError( ...
                @() pds.signal.designOptimalFilter(template, [], NoiseModel="provided", NoisePsd=ones(1, 3)), ...
                'pds:signal:designOptimalFilter:NoisePsdLength');
            testCase.verifyError( ...
                @() pds.signal.designOptimalFilter(template, [], NoiseModel="banana"), ...
                'pds:signal:designOptimalFilter:UnknownNoiseModel');
            testCase.verifyError( ...
                @() pds.signal.designOptimalFilter(template, [], NoiseModel="parametric", ...
                    ColoredNoiseModel="ar1", ArCoefficient=1), ...
                'pds:signal:designOptimalFilter:InvalidArCoefficient');
        end
    end
end
