classdef TestSetupPDSAnalysisPath < matlab.unittest.TestCase
    methods (Test)
        function setupAddsNewApiAndCompatibilityWrapperWithoutLegacyImplementation(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            originalPath = path;
            testCase.addTeardown(@() path(originalPath));
            addpath(repositoryRoot);

            addedPaths = setupPDSAnalysisPath();

            sourceRoot = string(fullfile(repositoryRoot, 'src'));
            compatibilityDirectory = string(fullfile(repositoryRoot, 'src', 'compat'));
            externalDirectory = string(fullfile(repositoryRoot, ...
                'external', 'fiuna-pasantia-tesis-matlab'));
            expectedWrapper = string(fullfile(repositoryRoot, 'src', 'compat', 'f_fourier.m'));

            testCase.verifyTrue(any(addedPaths == sourceRoot));
            testCase.verifyTrue(any(addedPaths == compatibilityDirectory));
            testCase.verifyFalse(any(addedPaths == externalDirectory));
            testCase.verifyEqual(string(which('pds.signal.computeSpectrum')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'computeSpectrum.m')));
            testCase.verifyEqual(string(which('f_fourier')), expectedWrapper);
        end
    end
end
