classdef TestFFourierCompatibility < matlab.unittest.TestCase
    properties
        RepositoryRoot
    end

    methods (TestClassSetup)
        function configureProjectPath(testCase)
            testCase.RepositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));
            addpath(fullfile(testCase.RepositoryRoot, 'src'));
            compatibilityDirectory = fullfile(testCase.RepositoryRoot, 'src', 'compat');
            if isfolder(compatibilityDirectory)
                addpath(compatibilityDirectory);
            end
        end
    end

    methods (Test)
        function twoArgumentCallReturnsLinearLegacyOutputs(testCase)
            waveform = [0, 1, 0, -1];
            samplePeriod = 0.25;
            expected = pds.signal.computeSpectrum(waveform, samplePeriod);
            warningState = warning('off', 'PDS:f_fourier:Deprecated');
            testCase.addTeardown(@() warning(warningState));

            [frequencyHz, amplitude, complexMean, psd, rmsPerRecord] = ...
                f_fourier(waveform, samplePeriod);

            testCase.verifyEqual(frequencyHz, expected.frequencyHz, 'AbsTol', 1e-12);
            testCase.verifyEqual(amplitude, expected.amplitudeMean, 'AbsTol', 1e-12);
            testCase.verifyEqual(complexMean, expected.complexMean, 'AbsTol', 1e-12);
            testCase.verifyEqual(psd, expected.psdMean, 'AbsTol', 1e-12);
            testCase.verifyEqual(rmsPerRecord, expected.rmsPerRecord, 'AbsTol', 1e-12);
        end

        function threeToFiveArgumentCallsPreserveNonPlottingLegacyBehavior(testCase)
            waveform = [0, 2, 0, -2];
            samplePeriod = 0.25;
            expected = pds.signal.computeSpectrum(waveform, samplePeriod);
            warningState = warning('off', 'PDS:f_fourier:Deprecated');
            testCase.addTeardown(@() warning(warningState));

            [~, threeArgumentAmplitude] = ...
                f_fourier(waveform, samplePeriod, false);
            [~, fourArgumentAmplitude] = ...
                f_fourier(waveform, samplePeriod, false, "dBFS");
            [~, fiveArgumentAmplitude] = ...
                f_fourier(waveform, samplePeriod, false, "abs", true);

            testCase.verifyEqual(threeArgumentAmplitude, expected.amplitudeMean, 'AbsTol', 1e-12);
            testCase.verifyEqual(fourArgumentAmplitude, ...
                20 * log10(expected.amplitudeMean / 2^14), 'AbsTol', 1e-12);
            testCase.verifyEqual(fiveArgumentAmplitude, ...
                expected.amplitudeMean, 'AbsTol', 1e-12);
        end

        function multiRecordRmsKeepsLegacyRowOrientation(testCase)
            waveforms = [0, 1, 0, -1; 0, 2, 0, -2];
            warningState = warning('off', 'PDS:f_fourier:Deprecated');
            testCase.addTeardown(@() warning(warningState));

            [~, ~, ~, ~, rmsPerRecord] = ...
                f_fourier(waveforms, 0.25, false, "abs", false);

            testCase.verifySize(rmsPerRecord, [1, 2]);
            testCase.verifyEqual(rmsPerRecord, [1, 2] / sqrt(2), 'AbsTol', 1e-12);
        end

        function numericZeroAndOneFlagsRemainAccepted(testCase)
            waveform = [0, 1, 0, -1];
            warningState = warning('off', 'PDS:f_fourier:Deprecated');
            testCase.addTeardown(@() warning(warningState));

            [~, normalizedAmplitude] = ...
                f_fourier(waveform, 0.25, 0, "abs", 1);

            testCase.verifyEqual(max(normalizedAmplitude), 1, 'AbsTol', 1e-12);
        end

        function normalizedPlotKeepsLegacyDecibelDisplay(testCase)
            waveform = [1, zeros(1, 7)];
            warningState = warning('off', 'PDS:f_fourier:Deprecated');
            testCase.addTeardown(@() warning(warningState));
            previousVisibility = get(groot, 'defaultFigureVisible');
            set(groot, 'defaultFigureVisible', 'off');
            testCase.addTeardown(@() set(groot, 'defaultFigureVisible', previousVisibility));
            existingFigure = findobj(groot, 'Type', 'figure', 'Number', 3);
            if ~isempty(existingFigure)
                close(existingFigure);
            end
            testCase.addTeardown(@() close(findobj(groot, 'Type', 'figure', 'Number', 3)));

            [~, normalizedAmplitude] = ...
                f_fourier(waveform, 1 / 8, true, "abs", true);

            figureHandle = findobj(groot, 'Type', 'figure', 'Number', 3);
            testCase.assertNotEmpty(figureHandle);
            lineHandle = findobj(figureHandle, 'Type', 'line');
            testCase.assertNumElements(lineHandle, 1);
            axesHandle = ancestor(lineHandle, 'axes');
            testCase.verifyEqual(axesHandle.YLabel.String, 'abs');
            testCase.verifyEqual(normalizedAmplitude, ...
                [0.5, 1, 1, 1, 0.5], 'AbsTol', 1e-12);
            testCase.verifyEqual(lineHandle.YData, ...
                20 * log10(normalizedAmplitude), 'AbsTol', 1e-12);
        end
    end
end
