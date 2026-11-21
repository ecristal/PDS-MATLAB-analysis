classdef TestDaqNpzReference < matlab.unittest.TestCase
    % Set PDS_DAQ_REFERENCE_DIR to the directory containing manifest.json.
    methods (TestClassSetup)
        function addSource(testCase)
            directory = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'src');
            addpath(directory);
            testCase.addTeardown(@() rmpath(directory));
            testCase.assumeTrue(isfolder(getenv('PDS_DAQ_REFERENCE_DIR')), ...
                'Set PDS_DAQ_REFERENCE_DIR to the November 2026 NPZ collection.');
        end
    end
    methods (Test)
        function importsEightChannelDarkAsOneChannel(testCase)
            path = fullfile(getenv('PDS_DAQ_REFERENCE_DIR'), 'step-005.npz');
            [data, average, Tm, info] = pds.io.readDaqNpz(path, 24);
            testCase.verifySize(data, [15000,256]);
            testCase.verifyEqual(average, mean(data,1));
            testCase.verifyEqual(Tm, 16e-9);
            testCase.verifyEqual(info.availableChannels, uint8([0;1;2;3;24;25;26;27]));
            testCase.verifyEqual(info.module, "M5_CH1");
            testCase.verifyEqual(info.panelChannel, 16);
            testCase.verifyEqual(info.metadata.receipt.label, 'g500-dark');
            testCase.verifyEqual(unique(info.streamIds), uint8(65));
            testCase.verifyEqual(unique(diff(info.timestamps)), uint64(1024));
            testCase.verifyFalse(any(info.continuation));
            [pedestal, ~] = pds.preprocess.estimatePedestal(data, SampleIndices=1:32);
            corrected = pds.preprocess.subtractPedestal(data, pedestal);
            testCase.verifySize(corrected, [15000,256]);
            testCase.verifyEqual(mean(corrected(:,1:32),2), zeros(15000,1), 'AbsTol',1e-10);
        end
        function importsInterleavedLightWithExactTimestamp(testCase)
            path = fullfile(getenv('PDS_DAQ_REFERENCE_DIR'), 'step-006.npz');
            [data, ~, ~, info] = pds.io.readDaqNpz(path, 2);
            testCase.verifySize(data, [15000,256]);
            expectedTick = uint64(112120987)*uint64(1000000000) + uint64(335365951);
            testCase.verifyEqual(info.timestamps(1), expectedTick);
            testCase.verifyEqual(info.sourceRows, (1:2:30000).');
            testCase.verifyEqual(info.module, "M1_CH1");
            testCase.verifyEqual(info.metadata.receipt.coordinates.led_bias_270nm, 780);
            testCase.verifyEqual(unique(diff(info.timestamps)), uint64(1024));
        end
        function importsAlignmentWithoutTreatingItAsPhysics(testCase)
            path = fullfile(getenv('PDS_DAQ_REFERENCE_DIR'), 'step-001.npz');
            [data, ~, ~, info] = pds.io.readDaqNpz(path, 0);
            testCase.verifySize(data, [512,256]);
            testCase.verifyEqual(info.metadata.receipt.role, 'pedestal_alignment');
            testCase.verifyEqual(info.module, "M2_CH1");
        end
    end
end
