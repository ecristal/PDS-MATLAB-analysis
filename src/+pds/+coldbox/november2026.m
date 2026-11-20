function config = november2026(runRoot)
%NOVEMBER2026 Paths and settings for the November 2026 M3/M4 analysis.
arguments
    runRoot (1,1) string
end
config.Campaign = "ColdBox November 2026";
config.ScanRoot = fullfile(runRoot,'runs','VGAIN_SCANS','M3');
config.Vbias = [770 783 796 808 821 834 847 860];
config.Vgain = 500:100:2500;
config.ScanChannels = [8 9];
config.SamplePeriod = 16e-9;
config.AdcBits = 14;

noiseRoot = fullfile(runRoot,'runs','enoise');
config.NoiseLabels = ["M3_M4","M3_M4_ENOISE_N50000_L2048_CRP_OFF"];
config.NoiseFolders = [fullfile(noiseRoot,config.NoiseLabels(1),'AFE1_vbias_19p4v','vbias_500','vgain_500'), ...
    fullfile(noiseRoot,config.NoiseLabels(2),'vbias_500','vgain_500')];
config.NoiseChannels = 8:11;
config.NoiseChannelTitles = ["M3","M3","M4","M4"] + " DAPHNE CH " + string(config.NoiseChannels);
config.NoiseSubtitle = config.Campaign + " | Vbias 500 DAC | Vgain 500 DAC";
config.NoiseRoiMHz = 6;
end
