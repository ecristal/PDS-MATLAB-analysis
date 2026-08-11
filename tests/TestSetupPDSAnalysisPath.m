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
            expectedOptimalWrapper = string(fullfile(repositoryRoot, 'src', 'compat', ...
                'optimal_filter_for_daphne_gpessina_function.m'));
            expectedDftWrapper = string(fullfile(repositoryRoot, 'src', 'compat', 'mi_dft.m'));
            expectedInverseWrapper = string(fullfile(repositoryRoot, 'src', 'compat', 'mi_idtft.m'));
            legacyDirectories = string({ ...
                fullfile(repositoryRoot, 'legacy', 'functions', 'mi_dft'), ...
                fullfile(repositoryRoot, 'legacy', 'functions', 'mi_idtft'), ...
                fullfile(repositoryRoot, 'legacy', 'functions', ...
                    'optimal_filter_for_daphne_gpessina_function')});

            testCase.verifyTrue(any(addedPaths == sourceRoot));
            testCase.verifyTrue(any(addedPaths == compatibilityDirectory));
            testCase.verifyFalse(any(addedPaths == externalDirectory));
            testCase.verifyFalse(any(ismember(addedPaths, legacyDirectories)));
            testCase.verifyEqual(string(which('pds.signal.computeSpectrum')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'computeSpectrum.m')));
            testCase.verifyEqual(string(which('pds.signal.forwardDft')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'forwardDft.m')));
            testCase.verifyEqual(string(which('pds.signal.inverseDft')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'inverseDft.m')));
            testCase.verifyEqual(string(which('pds.signal.createWindow')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'createWindow.m')));
            testCase.verifyEqual(string(which('pds.signal.estimateNoisePsd')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'estimateNoisePsd.m')));
            testCase.verifyEqual(string(which('pds.signal.designOptimalFilter')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'designOptimalFilter.m')));
            testCase.verifyEqual(string(which('pds.signal.applyOptimalFilter')), ...
                string(fullfile(repositoryRoot, 'src', '+pds', '+signal', 'applyOptimalFilter.m')));
            testCase.verifyEqual(string(which('f_fourier')), expectedWrapper);
            testCase.verifyEqual(string(which('mi_dft')), expectedDftWrapper);
            testCase.verifyEqual(string(which('mi_idtft')), expectedInverseWrapper);
            testCase.verifyEqual(string(which( ...
                'optimal_filter_for_daphne_gpessina_function')), expectedOptimalWrapper);
        end
    end
end
