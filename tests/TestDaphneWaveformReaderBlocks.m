classdef TestDaphneWaveformReaderBlocks < matlab.unittest.TestCase
    methods (Test)
        function readsConsecutiveRowsWithoutAdvancingCursor(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'src')));
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(folder.Folder,'waveforms.dat');
            waves = uint16([101 102 103; 201 202 203; 301 302 303]);
            fid = fopen(file,'wb','ieee-le');
            testCase.assertGreaterThanOrEqual(fid,0);
            fwrite(fid,waves.','uint16');
            fclose(fid);

            reader = pds.io.DaphneWaveformReader(file,SamplesPerWaveform=3);
            testCase.addTeardown(@() reader.close());
            testCase.verifyEqual(reader.readBlock(2,2),waves(2:3,:));
            testCase.verifyEqual(reader.NextIndex,1);
            testCase.verifyEqual(reader.next(),waves(1,:));
            testCase.verifyEqual(reader.read(3),waves(3,:));
            testCase.verifyError(@() reader.readBlock(3,2), ...
                'pds:io:DaphneWaveformReader:IndexOutOfRange');
        end
    end
end
