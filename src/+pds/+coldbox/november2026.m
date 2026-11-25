function config = november2026(runRoot,module)
%NOVEMBER2026 Load the scan settings for a ColdBox module from its metadata.
arguments
    runRoot (1,1) string {mustBeFolder}
    module (1,1) string {mustBeMember(module,["M1","M2","M3","M4","M5","M6"])}
end
config.Campaign = "ColdBox November 2026";
config.ScanRoot = fullfile(runRoot,'runs','VGAIN_SCANS',module);
metadata = fileread(fullfile(config.ScanRoot,'scan_metadata.txt'));
config.ShaperFile = fullfile(fileparts(mfilename('fullpath')), ...
    'private','november2026_shaper.mat');
config.Vbias = readScanList(metadata,'bias_values');
gains = readScanList(metadata,'vgain_values');
config.Vgain = gains(gains>=500 & gains<=2500);
assert(~isempty(config.Vgain),'No VGAIN settings between 500 and 2500 DAC in %s.',config.ScanRoot);
config.ScanChannels = readScanList(metadata,'channels');
config.SamplePeriod = 16e-9;
config.AdcBits = 14;
end

function values = readScanList(metadata,key)
values = str2double(split(readAcquisitionParameter(metadata,key),",")).';
assert(all(isfinite(values) & values>=0 & values==fix(values)) && ...
    numel(unique(values))==numel(values),'Expected distinct nonnegative integers for %s.',key);
end
