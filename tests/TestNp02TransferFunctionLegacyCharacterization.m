classdef TestNp02TransferFunctionLegacyCharacterization < matlab.unittest.TestCase
    properties (Constant, Access = private)
        ExpectedSha256 = ...
            'e5ebdfe276727602af6a67cc1759e16e111ad49221769523e232bcb8f6429302'
        ExpectedModelArtifactSha256 = ...
            'da4e0bafa131b03fb0b3dd05ea03ca55064fcf709459cdb96597812e899f4106'
    end

    properties (SetAccess = private)
        ScriptPath
        ScriptText
    end

    methods (TestMethodSetup)
        function loadPreservedScriptAsData(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.ScriptPath = fullfile(repositoryRoot, 'legacy', ...
                'np02', 'np02_tf_estimation_pds_algorithm.m');
            testCase.ScriptText = fileread(testCase.ScriptPath);
        end
    end

    methods (Test)
        function preservedModelArtifactReconstructsCanonicalIir(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            artifactPath = fullfile(repositoryRoot, 'legacy', 'np02', ...
                'np02_iir_model_element16.json');
            artifact = readVerifiedModelArtifact(artifactPath, ...
                testCase.ExpectedModelArtifactSha256);

            testCase.verifyEqual(artifact.sourceMatSha256, ...
                '89754d544c05a50ff593d49fd374c9b3741077de33b305a27e1a708a481c48cb');
            testCase.verifyEqual(artifact.sourceElement, 16);
            testCase.verifyEqual(artifact.sampleTimeSeconds, 16e-9, ...
                RelTol=eps);
            testCase.verifyEqual(artifact.variable, 'z^-1');
            testCase.verifyEqual(numel(artifact.numerator), 6);
            testCase.verifyEqual(numel(artifact.denominator), 6);
            testCase.verifyEqual(artifact.numerator(1), 0);

            model = tf(artifact.numerator(:).', ...
                artifact.denominator(:).', artifact.sampleTimeSeconds, ...
                'Variable', 'z^-1');
            testCase.verifyTrue(isstable(model));
            maximumPoleMagnitude = max(abs(pole(model)));
            testCase.verifyLessThan(maximumPoleMagnitude, 1);
            testCase.verifyEqual(maximumPoleMagnitude, ...
                artifact.observedMaximumPoleMagnitude, AbsTol=1e-14);
        end

        function rejectsModifiedModelArtifactCopy(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            artifactPath = fullfile(repositoryRoot, 'legacy', 'np02', ...
                'np02_iir_model_element16.json');
            modifiedPath = [tempname, '.json'];
            cleanup = onCleanup(@() deleteIfPresent(modifiedPath));
            artifactText = fileread(artifactPath);
            modifiedText = strrep(artifactText, ...
                '0.0088026439303778188', '0.1088026439303778188');
            testCase.assertNotEqual(modifiedText, artifactText);
            writeTextFile(modifiedPath, modifiedText);

            testCase.verifyError( ...
                @() readVerifiedModelArtifact(modifiedPath, ...
                testCase.ExpectedModelArtifactSha256), ...
                'TestNp02TransferFunctionLegacyCharacterization:ArtifactHashMismatch');
            clear cleanup
        end

        function preservedScriptMatchesCanonicalHashAndSize(testCase)
            fileInfo = dir(testCase.ScriptPath);
            testCase.verifyEqual(fileInfo.bytes, 6517);
            testCase.verifyEqual(sha256File(testCase.ScriptPath), ...
                testCase.ExpectedSha256);
        end

        function recordsHistoricalIdentificationContract(testCase)
            requiredFragments = { ...
                'number = 16', ...
                'starting_point = 250;', ...
                'Tm = 16e-9;', ...
                'order = 4', ...
                'circ_start = -10;', ...
                'circ_stop = 20;', ...
                'iddata(output_data'',circshift(input_data,i)'', Tm)', ...
                'tfest(data_to_est,ord+1,ord)', ...
                'c2d(tf_model,Tm,''zoh'')', ...
                'tf_model_d.Variable = ''z^-1'''};
            for index = 1:numel(requiredFragments)
                testCase.verifyNotEmpty(strfind( ... %#ok<STREMP>
                    testCase.ScriptText, requiredFragments{index}));
            end
        end

        function recordsHistoricalPreprocessingAndModelPersistence(testCase)
            requiredFragments = { ...
                'output_data = waveform/max(waveform);', ...
                'output_data = output_data - mean(output_data(1:50));', ...
                'filter(tf_model_d.Numerator,tf_model_d.Denominator', ...
                'spe_template_struct(number).tf = tf_model_d;', ...
                'spe_template_struct(number).num = tf_model_d.Numerator;', ...
                'spe_template_struct(number).den = tf_model_d.Denominator;'};
            for index = 1:numel(requiredFragments)
                testCase.verifyNotEmpty(strfind( ... %#ok<STREMP>
                    testCase.ScriptText, requiredFragments{index}));
            end
        end

        function exposesDestructiveAndInteractiveSideEffects(testCase)
            sideEffectFragments = { ...
                'load("templates_np02_large_pulses.mat")', ...
                'close all', ...
                'figure(1)', ...
                'figure(2)', ...
                'figure(3)', ...
                'generateFractionalZeroCompensator', ...
                'save("templates_np02_large_pulses.mat","spe_template_struct")'};
            for index = 1:numel(sideEffectFragments)
                testCase.verifyNotEmpty(strfind( ... %#ok<STREMP>
                    testCase.ScriptText, sideEffectFragments{index}));
            end
        end
    end
end

function digest = sha256File(filePath)
    fileIdentifier = fopen(filePath, 'rb');
    if fileIdentifier < 0
        error('TestNp02TransferFunctionLegacyCharacterization:OpenFailed', ...
            'Could not open preserved NP02 script.');
    end
    cleanup = onCleanup(@() fclose(fileIdentifier));
    bytes = fread(fileIdentifier, Inf, '*uint8');
    engine = java.security.MessageDigest.getInstance('SHA-256');
    engine.update(bytes);
    digestBytes = typecast(engine.digest(), 'uint8');
    digest = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
end

function artifact = readVerifiedModelArtifact(filePath, expectedSha256)
    actualSha256 = sha256File(filePath);
    if ~strcmp(actualSha256, expectedSha256)
        error( ...
            'TestNp02TransferFunctionLegacyCharacterization:ArtifactHashMismatch', ...
            'Preserved NP02 model artifact does not match its canonical SHA-256.');
    end
    artifact = jsondecode(fileread(filePath));
end

function writeTextFile(filePath, text)
    fileIdentifier = fopen(filePath, 'wt');
    if fileIdentifier < 0
        error('TestNp02TransferFunctionLegacyCharacterization:WriteFailed', ...
            'Could not create temporary modified artifact.');
    end
    cleanup = onCleanup(@() fclose(fileIdentifier));
    fwrite(fileIdentifier, text, 'char');
    clear cleanup
end

function deleteIfPresent(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end
