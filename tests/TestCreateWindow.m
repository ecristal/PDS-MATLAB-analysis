classdef TestCreateWindow < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function tukeyWindowIsSymmetricWithExpectedEndpoints(testCase)
            window = pds.signal.createWindow(21, "tukey", TukeyRatio=0.4);
            testCase.verifySize(window, [1, 21]);
            testCase.verifyEqual(window, fliplr(window), 'AbsTol', 1e-14);
            testCase.verifyEqual(window([1, end]), [0, 0], 'AbsTol', 1e-14);
            testCase.verifyEqual(window(11), 1, 'AbsTol', 1e-14);
        end

        function tukeyLimitsMatchRectangularAndHann(testCase)
            rectangular = pds.signal.createWindow(16, "tukey", TukeyRatio=0);
            tukeyHann = pds.signal.createWindow(16, "tukey", TukeyRatio=1);
            hannWindow = pds.signal.createWindow(16, "hann");

            testCase.verifyEqual(rectangular, ones(1, 16), 'AbsTol', 1e-14);
            testCase.verifyEqual(tukeyHann, hannWindow, 'AbsTol', 1e-14);
        end

        function namedAndNumericWindowsAreSupported(testCase)
            hammingWindow = pds.signal.createWindow(8, "hamming");
            numericWindow = pds.signal.createWindow(8, 1:8);

            testCase.verifyEqual(hammingWindow, fliplr(hammingWindow), 'AbsTol', 1e-14);
            testCase.verifyEqual(numericWindow, 1:8);
        end

        function integerCustomWindowIsConvertedToFloatingPoint(testCase)
            window = pds.signal.createWindow(8, uint16(1:8));

            testCase.verifyClass(window, 'double');
            testCase.verifyEqual(window, 1:8);
        end

        function integerScalarOptionsAreConvertedToFloatingPoint(testCase)
            window = pds.signal.createWindow( ...
                uint16(8), "tukey", TukeyRatio=uint8(1));
            expected = pds.signal.createWindow(8, "hann");

            testCase.verifyClass(window, 'double');
            testCase.verifyEqual(window, expected, 'AbsTol', 1e-12);
        end

        function invalidWindowRequestsAreRejected(testCase)
            testCase.verifyError(@() pds.signal.createWindow(1, "hann"), ...
                'pds:signal:createWindow:InvalidSampleCount');
            testCase.verifyError(@() pds.signal.createWindow(8, "blackman"), ...
                'pds:signal:createWindow:UnknownWindow');
            testCase.verifyError(@() pds.signal.createWindow(8, "tukey", TukeyRatio=1.1), ...
                'pds:signal:createWindow:InvalidTukeyRatio');
            testCase.verifyError(@() pds.signal.createWindow(8, ones(1, 7)), ...
                'pds:signal:createWindow:WindowLength');
        end
    end
end
