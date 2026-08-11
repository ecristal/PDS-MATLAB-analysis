classdef TestForwardDft < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function matchesFftAndReturnsFftOrderFrequencies(testCase)
            waveform = [1, 2, -1, 0, 3, 1, 0, -2];
            [coefficients, frequencyHz] = pds.signal.forwardDft(waveform, 0.125);

            testCase.verifyEqual(coefficients, fft(waveform), 'AbsTol', 1e-12);
            testCase.verifyEqual(frequencyHz, [0, 1, 2, 3, 4, -3, -2, -1], ...
                'AbsTol', 1e-12);
        end

        function rowAndColumnInputsAreEquivalent(testCase)
            waveform = (1:7) - 2i * (7:-1:1);
            rowResult = pds.signal.forwardDft(waveform, 0.25);
            columnResult = pds.signal.forwardDft(waveform.', 0.25);

            testCase.verifySize(rowResult, [1, 7]);
            testCase.verifyEqual(columnResult, rowResult, 'AbsTol', 1e-12);
        end

        function numericWindowIsAppliedToWaveform(testCase)
            waveform = [1, 2, 3, 4, 3, 2, 1, 0];
            window = [0, 0.25, 0.75, 1, 1, 0.75, 0.25, 0];
            actual = pds.signal.forwardDft(waveform, 1, Window=window);

            testCase.verifyEqual(actual, fft(waveform .* window), 'AbsTol', 1e-12);
        end

        function sampleShiftMatchesCircularShift(testCase)
            waveform = [1, 2, 3, 4, 5, 6, 7];
            shifted = pds.signal.forwardDft(waveform, 1, SampleShift=2);
            shiftedNegative = pds.signal.forwardDft(waveform, 1, SampleShift=-3);

            testCase.verifyEqual(shifted, fft(circshift(waveform, 2)), 'AbsTol', 1e-11);
            testCase.verifyEqual(shiftedNegative, fft(circshift(waveform, -3)), 'AbsTol', 1e-11);
        end

        function integerWaveformIsConvertedToFloatingPoint(testCase)
            waveform = uint16([10, 11, 13, 12, 10, 9, 10, 11]);
            actual = pds.signal.forwardDft(waveform, 0.5);
            expected = fft(double(waveform));

            testCase.verifyClass(actual, 'double');
            testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12);
        end

        function integerScalarOptionsAreConvertedToFloatingPoint(testCase)
            waveform = 1:8;
            actual = pds.signal.forwardDft( ...
                waveform, uint16(1), Window=uint16(1:8), ...
                SampleShift=int8(1));
            expected = fft(circshift(waveform .* (1:8), 1));

            testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12);
        end

        function invalidInputsAreRejected(testCase)
            testCase.verifyError(@() pds.signal.forwardDft([1, NaN], 1), ...
                'pds:signal:forwardDft:NonfiniteWaveform');
            testCase.verifyError(@() pds.signal.forwardDft(1, 1), ...
                'pds:signal:forwardDft:TooFewSamples');
            testCase.verifyError(@() pds.signal.forwardDft([1, 2, 3], 0), ...
                'pds:signal:forwardDft:InvalidSamplePeriod');
            testCase.verifyError(@() pds.signal.forwardDft([1, 2, 3], 1, Window=[1, 1]), ...
                'pds:signal:forwardDft:WindowLength');
            testCase.verifyError(@() pds.signal.forwardDft([1, 2, 3], 1, Window=[1, NaN, 1]), ...
                'pds:signal:forwardDft:InvalidWindow');
            testCase.verifyError(@() pds.signal.forwardDft([1, 2, 3], 1, SampleShift=0.5), ...
                'pds:signal:forwardDft:InvalidSampleShift');
        end
    end
end
