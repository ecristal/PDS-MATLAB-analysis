classdef TestPlotSpectrum < matlab.unittest.TestCase
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
        function linearAmplitudeUsesProvidedAxesWithoutChangingData(testCase)
            spectrum = pds.signal.computeSpectrum([0, 1, 0, -1], 0.25);
            originalSpectrum = spectrum;
            figureHandle = figure('Visible', 'off');
            testCase.addTeardown(@() close(figureHandle));
            axesHandle = axes(figureHandle);

            lineHandle = pds.plotting.plotSpectrum(spectrum, Axes=axesHandle);

            testCase.verifyEqual(lineHandle.Parent, axesHandle);
            testCase.verifyEqual(lineHandle.XData, spectrum.frequencyHz);
            testCase.verifyEqual(lineHandle.YData, spectrum.amplitudeMean);
            testCase.verifyEqual(spectrum, originalSpectrum);
        end

        function amplitudeDecibelsUseTwentyLogAndExplicitReference(testCase)
            spectrum = struct( ...
                'frequencyHz', [0, 1, 2], ...
                'amplitudeMean', [0, 2, 4], ...
                'psdMean', [0, 4, 16], ...
                'inputUnit', "ADU");
            figureHandle = figure('Visible', 'off');
            testCase.addTeardown(@() close(figureHandle));
            axesHandle = axes(figureHandle);

            lineHandle = pds.plotting.plotSpectrum(spectrum, ...
                Axes=axesHandle, Scale="decibel", ReferenceValue=2, ...
                ReferenceLabel="dBFS", MinimumDecibels=-100);

            testCase.verifyEqual(lineHandle.YData, [-100, 0, 20 * log10(2)], 'AbsTol', 1e-12);
            testCase.verifySubstring(string(axesHandle.YLabel.String), "dBFS");
        end

        function psdDecibelsUseTenLogAndSquaredReference(testCase)
            spectrum = struct( ...
                'frequencyHz', [0, 1, 2], ...
                'amplitudeMean', [0, 2, 4], ...
                'psdMean', [0, 4, 16], ...
                'inputUnit', "ADU");
            figureHandle = figure('Visible', 'off');
            testCase.addTeardown(@() close(figureHandle));
            axesHandle = axes(figureHandle);

            lineHandle = pds.plotting.plotSpectrum(spectrum, ...
                Axes=axesHandle, Quantity="psd", Scale="decibel", ...
                ReferenceValue=2, ReferenceLabel="dBFS^2/Hz", ...
                MinimumDecibels=-100);

            testCase.verifyEqual(lineHandle.YData, [-100, 0, 10 * log10(4)], 'AbsTol', 1e-12);
            testCase.verifySubstring(string(axesHandle.YLabel.String), "dBFS^2/Hz");
        end

        function peakNormalizationOccursBeforePlotting(testCase)
            spectrum = struct( ...
                'frequencyHz', [0, 1, 2], ...
                'amplitudeMean', [0, 2, 4], ...
                'psdMean', [0, 4, 16], ...
                'inputUnit', "V");
            figureHandle = figure('Visible', 'off');
            testCase.addTeardown(@() close(figureHandle));
            axesHandle = axes(figureHandle);

            lineHandle = pds.plotting.plotSpectrum(spectrum, ...
                Axes=axesHandle, Normalize="peak");

            testCase.verifyEqual(lineHandle.YData, [0, 0.5, 1], 'AbsTol', 1e-12);
        end
    end
end
