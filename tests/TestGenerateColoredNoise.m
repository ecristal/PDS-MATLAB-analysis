classdef TestGenerateColoredNoise < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function whitePsdProducesRealReproducibleRowsWithoutGlobalRngMutation(testCase)
            sampleCount = 64;
            samplePeriod = 1 / 64;
            whitePsd = ones(1, sampleCount);
            rng(41, 'twister');
            callerState = rng;

            streamA = RandStream('mt19937ar', 'Seed', 7);
            [noiseA, diagnosticsA] = pds.simulation.generateColoredNoise( ...
                sampleCount, samplePeriod, NoisePsd=whitePsd, ...
                EventCount=3, RandomStream=streamA);
            stateAfter = rng;
            streamB = RandStream('mt19937ar', 'Seed', 7);
            noiseB = pds.simulation.generateColoredNoise( ...
                sampleCount, samplePeriod, NoisePsd=whitePsd, ...
                EventCount=3, RandomStream=streamB);

            testCase.verifyEqual(stateAfter, callerState);
            testCase.verifyEqual(noiseA, noiseB, AbsTol=0);
            testCase.verifySize(noiseA, [3, sampleCount]);
            testCase.verifyTrue(isreal(noiseA));
            testCase.verifyEqual(diagnosticsA.sampleCount, sampleCount);
            testCase.verifyEqual(diagnosticsA.eventCount, 3);
            testCase.verifyEqual(diagnosticsA.frequencyOrder, "fft");
            testCase.verifyEqual(diagnosticsA.psdSidedness, "bilateral");
        end

        function evenAndOddEnsemblesRecoverTargetPsdAndTargetRms(testCase)
            for sampleCount = [63, 64]
                sampleRateHz = 128;
                frequency = [0:floor(sampleCount / 2), ...
                    (-ceil(sampleCount / 2) + 1):-1] * ...
                    (sampleRateHz / sampleCount);
                targetPsd = 0.5 ./ (1 + (abs(frequency) / 12).^2);
                stream = RandStream('mt19937ar', 'Seed', sampleCount);
                [noise, diagnostics] = pds.simulation.generateColoredNoise( ...
                    sampleCount, 1 / sampleRateHz, NoisePsd=targetPsd, ...
                    EventCount=2000, RandomStream=stream);

                relativeAggregateError = norm( ...
                    diagnostics.realizedPsd - targetPsd) / norm(targetPsd);
                expectedVariance = sum(targetPsd) * ...
                    sampleRateHz / sampleCount;
                realizedVariance = mean(noise(:).^2);
                testCase.verifyLessThan(relativeAggregateError, 0.08);
                testCase.verifyEqual(realizedVariance, expectedVariance, ...
                    RelTol=0.03);
            end

            targetRms = 2.5;
            scaled = pds.simulation.generateColoredNoise( ...
                64, 1 / 64, NoisePsd=ones(1, 64), EventCount=12, ...
                TargetRms=targetRms, ...
                RandomStream=RandStream('mt19937ar', 'Seed', 99));
            testCase.verifyEqual(sqrt(mean(scaled.^2, 2)), ...
                repmat(targetRms, 12, 1), AbsTol=1e-12);
        end

        function explicitSeedIsReproducibleAndMutuallyExclusiveWithStream(testCase)
            first = pds.simulation.generateColoredNoise( ...
                32, 1 / 32, NoisePsd=ones(1, 32), EventCount=2, Seed=17);
            second = pds.simulation.generateColoredNoise( ...
                32, 1 / 32, NoisePsd=ones(1, 32), EventCount=2, Seed=17);
            testCase.verifyEqual(first, second, AbsTol=0);
            testCase.verifyError(@() pds.simulation.generateColoredNoise( ...
                32, 1 / 32, NoisePsd=ones(1, 32), Seed=17, ...
                RandomStream=RandStream('mt19937ar', 'Seed', 17)), ...
                'pds:simulation:generateColoredNoise:ConflictingRandomSource');
        end

        function ar1AndPowerLawEnsemblesRecoverSpectralShape(testCase)
            sampleCount = 128;
            sampleRateHz = 256;
            frequency = [0:64, -63:-1] * (sampleRateHz / sampleCount);

            arCoefficient = 0.85;
            omega = 2 * pi * frequency / sampleRateHz;
            arPsd = 0.2 ./ abs(1 - arCoefficient * exp(-1i * omega)).^2;
            [~, arDiagnostics] = pds.simulation.generateColoredNoise( ...
                sampleCount, 1 / sampleRateHz, NoisePsd=arPsd, ...
                EventCount=2500, Seed=81);
            arLogCorrelation = corr(log(arPsd(:)), ...
                log(arDiagnostics.realizedPsd(:)));
            testCase.verifyGreaterThan(arLogCorrelation, 0.995);

            protectedFrequency = max(abs(frequency), sampleRateHz / sampleCount);
            powerLawPsd = protectedFrequency.^(-1.5);
            powerLawPsd(1) = powerLawPsd(2);
            [~, powerLawDiagnostics] = ...
                pds.simulation.generateColoredNoise( ...
                sampleCount, 1 / sampleRateHz, NoisePsd=powerLawPsd, ...
                EventCount=2500, Seed=82);
            positive = 2:64;
            fittedSlope = polyfit(log10(abs(frequency(positive))), ...
                log10(powerLawDiagnostics.realizedPsd(positive)), 1);
            testCase.verifyEqual(fittedSlope(1), -1.5, AbsTol=0.08);
        end

        function longGenerationSupportsInteriorCrop(testCase)
            [cropped, diagnostics] = pds.simulation.generateColoredNoise( ...
                512, 1 / 64, NoisePsd=ones(1, 512), EventCount=4, ...
                OutputSampleCount=128, Seed=14);

            testCase.verifySize(cropped, [4, 128]);
            testCase.verifyEqual(diagnostics.generatedSampleCount, 512);
            testCase.verifyEqual(diagnostics.outputSampleCount, 128);
            testCase.verifyEqual(diagnostics.cropIndices, 193:320);
            testCase.verifyGreaterThan(diagnostics.cropIndices(1), 1);
            testCase.verifyLessThan(diagnostics.cropIndices(end), 512);
        end

        function targetRmsAppliesToDeliveredCropAndIsTraceable(testCase)
            targetRms = 2.25;
            [cropped, diagnostics] = pds.simulation.generateColoredNoise( ...
                512, 1 / 64, NoisePsd=ones(1, 512), EventCount=5, ...
                OutputSampleCount=128, TargetRms=targetRms, Seed=27);

            testCase.verifyEqual(sqrt(mean(cropped.^2, 2)), ...
                repmat(targetRms, 5, 1), AbsTol=1e-12);
            testCase.verifyEqual(diagnostics.realizedRms, ...
                repmat(targetRms, 5, 1), AbsTol=1e-12);
            testCase.verifyEqual(diagnostics.normalization, ...
                "per-delivered-event-rms");
            testCase.verifySize(diagnostics.normalizationScale, [5, 1]);
            testCase.verifySize(diagnostics.effectiveTargetPsd, [1, 512]);
            testCase.verifySize(diagnostics.deliveredRealizedPsd, [1, 128]);
            testCase.verifySize(diagnostics.deliveredFrequencyHz, [1, 128]);
        end

        function cropNormalizationDiagnosticsReconstructIndependently(testCase)
            sampleCount = 96;
            outputSampleCount = 32;
            eventCount = 6;
            sampleRateHz = 192;
            targetRms = 1.75;
            frequency = [0:48, -47:-1] * ...
                (sampleRateHz / sampleCount);
            targetPsd = 0.4 ./ (1 + (abs(frequency) / 18).^2);

            [cropped, diagnostics] = pds.simulation.generateColoredNoise( ...
                sampleCount, 1 / sampleRateHz, NoisePsd=targetPsd, ...
                EventCount=eventCount, OutputSampleCount=outputSampleCount, ...
                TargetRms=targetRms, Seed=91);
            unscaledParent = pds.simulation.generateColoredNoise( ...
                sampleCount, 1 / sampleRateHz, NoisePsd=targetPsd, ...
                EventCount=eventCount, Seed=91);

            parentCrop = unscaledParent(:, diagnostics.cropIndices);
            expectedScale = targetRms ./ sqrt(mean(parentCrop.^2, 2));
            expectedParent = unscaledParent .* expectedScale;
            expectedCrop = expectedParent(:, diagnostics.cropIndices);
            expectedParentPsdPerEvent = abs(fft(expectedParent, [], 2)).^2 / ...
                (sampleRateHz * sampleCount);
            expectedCropPsdPerEvent = abs(fft(expectedCrop, [], 2)).^2 / ...
                (sampleRateHz * outputSampleCount);
            expectedEffectiveTargetPsd = targetPsd * mean(expectedScale.^2);

            testCase.verifyEqual(cropped, expectedCrop, AbsTol=0);
            testCase.verifyEqual(diagnostics.normalizationScale, ...
                expectedScale, AbsTol=0);
            testCase.verifyEqual(diagnostics.effectiveTargetPsd, ...
                expectedEffectiveTargetPsd, AbsTol=1e-14);
            testCase.verifyEqual(diagnostics.realizedPsdPerEvent, ...
                expectedParentPsdPerEvent, AbsTol=1e-14);
            testCase.verifyEqual(diagnostics.realizedPsd, ...
                mean(expectedParentPsdPerEvent, 1), AbsTol=1e-14);
            testCase.verifyEqual(diagnostics.deliveredRealizedPsdPerEvent, ...
                expectedCropPsdPerEvent, AbsTol=1e-14);
            testCase.verifyEqual(diagnostics.deliveredRealizedPsd, ...
                mean(expectedCropPsdPerEvent, 1), AbsTol=1e-14);
        end

        function invalidPsdAndCropInputsAreRejected(testCase)
            testCase.verifyError(@() pds.simulation.generateColoredNoise( ...
                8, 1, NoisePsd=[1, 2, 3, 4, 5, 6, 7, 8]), ...
                'pds:simulation:generateColoredNoise:NonHermitianPsd');
            testCase.verifyError(@() pds.simulation.generateColoredNoise( ...
                8, 1, NoisePsd=[1, 1, 1, -1, 1, -1, 1, 1]), ...
                'pds:simulation:generateColoredNoise:InvalidNoisePsd');
            testCase.verifyError(@() pds.simulation.generateColoredNoise( ...
                8, 1, NoisePsd=zeros(1, 8)), ...
                'pds:simulation:generateColoredNoise:InvalidNoisePsd');
            testCase.verifyError(@() pds.simulation.generateColoredNoise( ...
                8, 1, NoisePsd=ones(1, 8), OutputSampleCount=9), ...
                'pds:simulation:generateColoredNoise:InvalidOutputSampleCount');
        end
    end
end