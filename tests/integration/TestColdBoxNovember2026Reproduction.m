classdef TestColdBoxNovember2026Reproduction < matlab.unittest.TestCase
    methods (Test)
        function savedScoresAndSpeReproduceTheFullRun(testCase)
            reference = string(getenv('PDS_COLDBOX_NOV2026_REFERENCE'));
            testCase.assumeTrue(isfolder(reference), ...
                'Set PDS_COLDBOX_NOV2026_REFERENCE to the saved November 2026 run.');
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'src')));
            expected = readtable(fullfile(reference,'summary.csv'),TextType='string');
            source = load(fullfile(reference,'pipeline.mat'),'pipeline');
            p = source.pipeline;
            shaper = load(fullfile(root,'src','+pds','+coldbox','private','november2026_shaper.mat'), ...
                'numz_planta_integrator','denz_planta_integrator');
            testCase.assertEqual(shaper.numz_planta_integrator,p.bHp);
            testCase.assertEqual(shaper.denz_planta_integrator,p.aHp);
            testCase.assertEqual(height(expected),336);
            resolved = 0;
            for k = 1:height(expected)
                row = expected(k,:);
                pointDir = fullfile(reference,sprintf('vbias_%d',row.VbiasDAC), ...
                    sprintf('vgain_%d',row.VgainDAC),sprintf('channel_%d',row.Channel));
                old = load(fullfile(pointDir,'point_results.mat'), ...
                    'events','pe','timing','row','speMeanRaw','speMean');
                e = old.events;
                evaluation = e.Accepted & ~e.Training;
                actual = pds.calibration.fitPhotoelectronPeaks(e.ScoreADU, ...
                    e.Accepted & e.Training,evaluation,~e.Training & ~e.Duplicate & ~e.Rail);
                expectedFit = old.pe;
                if ~isempty(expectedFit.fit)
                    % Bootstrap intervals are verified by the raw-data benchmark.
                    expectedFit.fit.snrCI95 = [NaN NaN];
                end
                testCase.assertTrue(isequaln(actual,expectedFit), ...
                    sprintf('Fit mismatch at %s.',pointDir));
                resolved = resolved + (actual.status=="resolved");
                baseline = median(e.RawPedestalADU(e.SinglePECandidate));
                [amplitude,dr,headroom,~,spe,rawAmplitude] = pds.calibration.measureSinglePe( ...
                    old.speMeanRaw,baseline,old.timing.polarity,old.timing.rawPeak, ...
                    FilterNumerator=p.bNotch,FilterDenominator=p.aNotch,AdcBits=p.adcBits);
                actualSpe = [amplitude,dr,headroom,rawAmplitude];
                oldSpe = old.row{:,{'SinglePEPeakToPeakADU','HistoricalDR', ...
                    'ADCHeadroomPE','RawSinglePEPeakToPeakADU'}};
                testCase.assertTrue(isequaln(spe,old.speMean) && isequaln(actualSpe,oldSpe), ...
                    sprintf('SPE mismatch at %s.',pointDir));
            end
            testCase.verifyEqual(resolved,316);
            fprintf('Verified 336 saved fits and SPE measurements, including 316 resolved points.\n');
        end
    end
end
