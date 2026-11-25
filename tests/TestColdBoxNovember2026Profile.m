classdef TestColdBoxNovember2026Profile < matlab.unittest.TestCase
    methods (Test)
        function readsEachModulesOwnScanMetadata(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'src')));
            campaign = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            scanBase = fullfile(campaign.Folder,'runs','VGAIN_SCANS');
            for k = 1:6
                scanRoot = fullfile(scanBase,"M"+string(k));
                mkdir(scanRoot);
                fid = fopen(fullfile(scanRoot,'scan_metadata.txt'),'wt');
                testCase.assertGreaterThanOrEqual(fid,0);
                fprintf(fid,'channels=%d,%d\nbias_values=%d,%d\nvgain_values=400,500,%d,2500,2600\n', ...
                    2*k-2,2*k-1,700+k,800+k,1000+k);
                fclose(fid);
            end

            for k = 1:6
                module = "M"+string(k);
                cfg = pds.coldbox.november2026(campaign.Folder,module);
                testCase.verifyEqual(cfg.ScanRoot,fullfile(scanBase,module));
                testCase.verifyEqual(cfg.ScanChannels,[2*k-2,2*k-1]);
                testCase.verifyEqual(cfg.Vbias,[700+k,800+k]);
                testCase.verifyEqual(cfg.Vgain,[500,1000+k,2500]);
                testCase.verifyTrue(isfile(cfg.ShaperFile));
            end
        end
    end
end
