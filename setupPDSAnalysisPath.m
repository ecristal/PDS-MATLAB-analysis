function addedPaths = setupPDSAnalysisPath()
%SETUPPDSANALYSISPATH Add staged analysis_daphne_data sources to MATLABPATH.
%
% Usage:
%   addpath('C:\Users\e_cri\Documents\Proyectos\PDS-MATLAB-analysis');
%   setupPDSAnalysisPath;
%
% This function adds only the directories that currently contain the staged
% Live Script dependencies. It intentionally does not add inventory, tests,
% raw-data, aging-test, or backup directories.

repoRoot = fileparts(mfilename('fullpath'));
relativeDirectories = {
    fullfile('legacy', 'live-scripts')
    fullfile('src', 'data')
    fullfile('src', 'daphne')
    fullfile('external', 'fiuna-pasantia-tesis-matlab')
};

addedPaths = strings(0, 1);
for index = 1:numel(relativeDirectories)
    directory = fullfile(repoRoot, relativeDirectories{index});
    if ~isfolder(directory)
        warning('PDSAnalysis:MissingDirectory', ...
            'Staged dependency directory was not found: %s', directory);
        continue;
    end

    addpath(directory);
    addedPaths(end + 1, 1) = string(directory); %#ok<AGROW>
end

fprintf('PDS MATLAB analysis path configured: %d directories added.\n', numel(addedPaths));
end
