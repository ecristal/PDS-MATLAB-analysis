classdef TestInverseDft < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function matchesIfftForComplexSpectrum(testCase)
            coefficients = [1, 2 + 1i, -3i, 4, -2 + 0.5i];
            actual = pds.signal.inverseDft(coefficients);

            testCase.verifySize(actual, [1, 5]);
            testCase.verifyEqual(actual, ifft(coefficients), 'AbsTol', 1e-12);
        end

        function forwardInverseRoundTripWorksForEvenAndOddLengths(testCase)
            evenWaveform = [1, 4, -2, 0, 3, 7, -1, 2];
            oddWaveform = [3, -1, 4, 1, 5, -9, 2];

            evenActual = pds.signal.inverseDft( ...
                pds.signal.forwardDft(evenWaveform, 0.1), RealOutput=true);
            oddActual = pds.signal.inverseDft( ...
                pds.signal.forwardDft(oddWaveform, 0.1), RealOutput=true);

            testCase.verifyEqual(evenActual, evenWaveform, 'AbsTol', 1e-12);
            testCase.verifyEqual(oddActual, oddWaveform, 'AbsTol', 1e-12);
        end

        function columnInputProducesCanonicalRowOutput(testCase)
            coefficients = fft([1, 2, 3, 4]);
            actual = pds.signal.inverseDft(coefficients.');
            testCase.verifySize(actual, [1, 4]);
        end

        function integerCoefficientsAreConvertedToFloatingPoint(testCase)
            coefficients = uint16([1, 2, 3, 4]);
            actual = pds.signal.inverseDft(coefficients);

            testCase.verifyClass(actual, 'double');
            testCase.verifyEqual(actual, ifft(double(coefficients)), 'AbsTol', 1e-12);
        end

        function realOutputRejectsNonHermitianSpectrum(testCase)
            coefficients = [1, 2 + 1i, 3, 4];
            testCase.verifyError( ...
                @() pds.signal.inverseDft(coefficients, RealOutput=true), ...
                'pds:signal:inverseDft:NonHermitianSpectrum');
        end

        function invalidInputsAreRejected(testCase)
            testCase.verifyError(@() pds.signal.inverseDft([1, NaN]), ...
                'pds:signal:inverseDft:NonfiniteCoefficients');
            testCase.verifyError(@() pds.signal.inverseDft(1), ...
                'pds:signal:inverseDft:TooFewBins');
            testCase.verifyError(@() pds.signal.inverseDft(zeros(2, 2)), ...
                'pds:signal:inverseDft:CoefficientDimensions');
        end
    end
end
