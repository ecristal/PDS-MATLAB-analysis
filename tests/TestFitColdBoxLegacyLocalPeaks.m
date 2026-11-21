classdef TestFitColdBoxLegacyLocalPeaks < matlab.unittest.TestCase
    methods (Test)
        function fitsPedestalAndFirstPhotoelectronLocally(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            helperDirectory = fullfile(repositoryRoot, 'tests', 'helpers');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                helperDirectory));
            randomStream = RandStream('mt19937ar', 'Seed', 814);
            scores = [ ...
                0.02 + 0.15 * randn(randomStream, 10000, 1); ...
                1.01 + 0.18 * randn(randomStream, 8000, 1); ...
                2.00 + 0.22 * randn(randomStream, 4000, 1)];

            result = fitColdBoxLegacyLocalPeaksForTest(scores, 0.03);

            testCase.verifyTrue(result.completed);
            testCase.verifyTrue(result.valid);
            testCase.verifyEqual(result.mu0, 0.02, 'AbsTol', 0.03);
            testCase.verifyEqual(result.mu1, 1.01, 'AbsTol', 0.04);
            testCase.verifyEqual(result.sigma0, 0.15, 'AbsTol', 0.03);
            testCase.verifyGreaterThan(result.snr, 5.5);
            testCase.verifyGreaterThan(result.rSquare0, 0.95);
            testCase.verifyGreaterThan(result.rSquare1, 0.95);
            testCase.verifyGreaterThan(result.rSquare, 0.95);

        end
    end
end
