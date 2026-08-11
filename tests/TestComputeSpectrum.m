classdef TestComputeSpectrum < matlab.unittest.TestCase
    properties
        SourceDirectory
    end

    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.SourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(testCase.SourceDirectory);
            testCase.addTeardown(@() rmpath(testCase.SourceDirectory));
        end
    end

    methods (Test)
        function rowAndColumnVectorsHaveTheSameFrequencyAxis(testCase)
            samplePeriod = 1 / 8;
            rowResult = pds.signal.computeSpectrum(zeros(1, 8), samplePeriod);
            columnResult = pds.signal.computeSpectrum(zeros(8, 1), samplePeriod);

            expectedFrequencyHz = 0:1:4;
            testCase.verifyEqual(rowResult.frequencyHz, expectedFrequencyHz, 'AbsTol', 1e-12);
            testCase.verifyEqual(columnResult.frequencyHz, expectedFrequencyHz, 'AbsTol', 1e-12);
            testCase.verifyEqual(rowResult.recordCount, 1);
            testCase.verifyEqual(columnResult.recordCount, 1);
            testCase.verifyEqual(rowResult.sampleCount, 8);
            testCase.verifyEqual(columnResult.sampleCount, 8);
        end

        function evenLengthBinCenteredToneHasCorrectAmplitude(testCase)
            sampleCount = 16;
            sampleRateHz = 16;
            toneBin = 3;
            peakAmplitude = 2.5;
            sampleIndex = 0:(sampleCount - 1);
            waveform = peakAmplitude * cos(2 * pi * toneBin * sampleIndex / sampleCount);

            result = pds.signal.computeSpectrum(waveform, 1 / sampleRateHz);

            expectedAmplitude = zeros(1, sampleCount / 2 + 1);
            expectedAmplitude(toneBin + 1) = peakAmplitude;
            testCase.verifyEqual(result.amplitudeMean, expectedAmplitude, 'AbsTol', 1e-12);
        end

        function oddLengthLastPositiveBinHasCorrectAmplitude(testCase)
            sampleCount = 15;
            sampleRateHz = 15;
            toneBin = 7;
            peakAmplitude = 1.7;
            sampleIndex = 0:(sampleCount - 1);
            waveform = peakAmplitude * cos(2 * pi * toneBin * sampleIndex / sampleCount);

            result = pds.signal.computeSpectrum(waveform, 1 / sampleRateHz);

            expectedAmplitude = zeros(1, floor(sampleCount / 2) + 1);
            expectedAmplitude(toneBin + 1) = peakAmplitude;
            testCase.verifyEqual(result.amplitudeMean, expectedAmplitude, 'AbsTol', 1e-12);
        end

        function oneSidedPsdAndRmsSatisfyParseval(testCase)
            sampleCount = 32;
            sampleRateHz = 32;
            sampleIndex = 0:(sampleCount - 1);
            waveforms = [ ...
                3 + cos(2 * pi * 4 * sampleIndex / sampleCount); ...
                -2 + 2 * sin(2 * pi * 7 * sampleIndex / sampleCount)];

            result = pds.signal.computeSpectrum(waveforms, 1 / sampleRateHz);

            expectedRms = sqrt(mean(abs(waveforms).^2, 2));
            df = sampleRateHz / sampleCount;
            testCase.verifyEqual(result.rmsPerRecord, expectedRms, 'AbsTol', 1e-12);
            testCase.verifyEqual(sum(result.psdMean) * df, mean(expectedRms.^2), 'AbsTol', 1e-12);
        end

        function removeMeanRemovesDcBeforeTheTransform(testCase)
            sampleCount = 32;
            sampleIndex = 0:(sampleCount - 1);
            waveform = 5 + 2 * cos(2 * pi * 3 * sampleIndex / sampleCount);

            result = pds.signal.computeSpectrum(waveform, 1 / sampleCount, RemoveMean=true);

            expectedAcRms = sqrt(mean((waveform - mean(waveform)).^2));
            testCase.verifyEqual(result.amplitudeMean(1), 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(result.rmsPerRecord, expectedAcRms, 'AbsTol', 1e-12);
            testCase.verifyTrue(result.meanRemoved);
        end

        function twoSidedSpectrumUsesFftOrderAndSatisfiesParseval(testCase)
            sampleCount = 8;
            sampleRateHz = 8;
            sampleIndex = 0:(sampleCount - 1);
            waveform = 2 * cos(2 * pi * 2 * sampleIndex / sampleCount);

            result = pds.signal.computeSpectrum( ...
                waveform, 1 / sampleRateHz, Sidedness="two-sided");

            expectedFrequencyHz = [0, 1, 2, 3, 4, -3, -2, -1];
            expectedAmplitude = zeros(1, sampleCount);
            expectedAmplitude([3, 7]) = 1;
            testCase.verifyEqual(result.frequencyHz, expectedFrequencyHz, 'AbsTol', 1e-12);
            testCase.verifyEqual(result.amplitudeMean, expectedAmplitude, 'AbsTol', 1e-12);
            testCase.verifyEqual(sum(result.psdMean), mean(waveform.^2), 'AbsTol', 1e-12);
            testCase.verifyEqual(result.rmsPerRecord, sqrt(mean(waveform.^2)), 'AbsTol', 1e-12);
        end

        function zeroConstantAndImpulseSignalsHaveExpectedSpectra(testCase)
            sampleCount = 8;
            sampleRateHz = 8;

            zeroResult = pds.signal.computeSpectrum(zeros(1, sampleCount), 1 / sampleRateHz);
            constantResult = pds.signal.computeSpectrum(3 * ones(1, sampleCount), 1 / sampleRateHz);
            impulse = [1, zeros(1, sampleCount - 1)];
            impulseResult = pds.signal.computeSpectrum(impulse, 1 / sampleRateHz);

            testCase.verifyEqual(zeroResult.amplitudeMean, zeros(1, 5), 'AbsTol', 1e-12);
            testCase.verifyEqual(zeroResult.psdMean, zeros(1, 5), 'AbsTol', 1e-12);
            testCase.verifyEqual(zeroResult.rmsPerRecord, 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(constantResult.amplitudeMean, [3, 0, 0, 0, 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(constantResult.rmsPerRecord, 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(impulseResult.amplitudeMean, ...
                [1, 2, 2, 2, 1] / sampleCount, 'AbsTol', 1e-12);
            testCase.verifyEqual(impulseResult.rmsPerRecord, 1 / sqrt(sampleCount), 'AbsTol', 1e-12);
        end

        function fixedNoiseSatisfiesParsevalForOddRecordLength(testCase)
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));
            rng(42, "twister");
            waveforms = randn(4, 31);
            sampleRateHz = 62.5e6;

            result = pds.signal.computeSpectrum(waveforms, 1 / sampleRateHz);

            expectedRms = sqrt(mean(waveforms.^2, 2));
            testCase.verifyEqual(result.rmsPerRecord, expectedRms, 'AbsTol', 1e-12);
        end

        function offBinToneSpreadsAcrossBinsButPreservesPower(testCase)
            sampleCount = 64;
            sampleRateHz = 64;
            sampleIndex = 0:(sampleCount - 1);
            waveform = 2 * cos(2 * pi * 5.5 * sampleIndex / sampleCount);

            result = pds.signal.computeSpectrum(waveform, 1 / sampleRateHz);

            significantBins = sum(result.amplitudeMean > 0.05);
            testCase.verifyGreaterThan(significantBins, 2);
            testCase.verifyEqual(result.rmsPerRecord, ...
                sqrt(mean(waveform.^2)), 'AbsTol', 1e-12);
        end

        function invalidWaveformContentAndDimensionsAreRejected(testCase)
            testCase.verifyError( ...
                @() pds.signal.computeSpectrum([1, NaN], 1), ...
                'pds:signal:computeSpectrum:NonfiniteWaveforms');
            testCase.verifyError( ...
                @() pds.signal.computeSpectrum([1, 1i], 1), ...
                'pds:signal:computeSpectrum:NonrealWaveforms');
            testCase.verifyError( ...
                @() pds.signal.computeSpectrum(1, 1), ...
                'pds:signal:computeSpectrum:TooFewSamples');
            testCase.verifyError( ...
                @() pds.signal.computeSpectrum(zeros(2, 4, 2), 1), ...
                'pds:signal:computeSpectrum:WaveformDimensions');
        end

        function oppositePhasesCancelOnlyInTheCoherentMean(testCase)
            sampleCount = 16;
            toneBin = 3;
            sampleIndex = 0:(sampleCount - 1);
            firstRecord = cos(2 * pi * toneBin * sampleIndex / sampleCount);
            waveforms = [firstRecord; -firstRecord];

            result = pds.signal.computeSpectrum(waveforms, 1 / sampleCount);

            testCase.verifyEqual(result.amplitudeMean(toneBin + 1), 1, 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(result.psdMean(toneBin + 1), 0);
            testCase.verifyEqual(result.complexMean(toneBin + 1), 0, 'AbsTol', 1e-12);
            testCase.verifySize(result.complexMean, [1, sampleCount]);
            testCase.verifyEqual(result.recordCount, 2);
        end
    end
end
