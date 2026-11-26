classdef TestColdBoxScanFilters < matlab.unittest.TestCase
    methods (Test)
        function bypassesEveryStageInTheRawScan(testCase)
            runRoot = string(getenv('PDS_COLDBOX_NOV2026_RUN_ROOT'));
            testCase.assumeTrue(isfolder(fullfile(runRoot,'runs','VGAIN_SCANS','M3')), ...
                'Set PDS_COLDBOX_NOV2026_RUN_ROOT to the November 2026 data directory.');
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'src')));
            temp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = pds.coldbox.november2026(runRoot,"M3");
            [~,out] = pds.coldbox.analyzeScan(cfg.ScanRoot,"",temp.Folder, ...
                Vbias=860,Vgain=500,Channels=8,BootstrapCount=0, ...
                UseTukey=false,UseNotch=false,UseLowPass=false, ...
                UseIntegrator=false,UseBoxcar=false);

            saved = load(fullfile(out,'pipeline.mat'),'pipeline');
            p = saved.pipeline;
            testCase.verifyFalse(any([p.useTukey,p.useNotch,p.useLowPass,p.useIntegrator,p.useBoxcar]));
            testCase.verifyEqual([p.bNotch,p.aNotch,p.bLow,p.aLow,p.bHp,p.aHp],ones(1,6));
            point = load(fullfile(out,'vbias_860','vgain_500','channel_8','point_results.mat'));
            testCase.verifyEqual(point.timing.tukeyRatio,0);
            reader = pds.io.DaphneWaveformReader(point.archive);
            testCase.addTeardown(@() reader.close());
            ids = 1:24;
            raw = reader.readBlock(ids(1),numel(ids));
            centered = point.timing.polarity * pds.preprocess.subtractPedestal( ...
                raw,point.events.RawPedestalADU(ids));
            scoreWindow = point.timing.scoreSample+(-1:1);
            testCase.verifyEqual(point.events.ScoreADU(ids),2*mean(centered(:,scoreWindow),2));
            testCase.verifyEqual(point.events.FilteredEarlyOffsetADU(ids), ...
                median(centered(:,point.timing.preSamples),2));
            testCase.verifyTrue(isequaln(point.speMean,point.speMeanRaw));
            testCase.verifySubstring(string(fileread(fullfile(out,'report.md'))),"| Notch | off |");
        end
    end
end
