function summary = reprocessScan(runFolder,outputFolder,options)
%REPROCESSSCAN Refit saved event scores or regenerate saved SPE measurements.
% Histogram mode rereads the channel archive only if the SPE selection changes.
% ScanRoot can point to a relocated module directory with the source archives.
arguments
    runFolder (1,1) string {mustBeFolder}
    outputFolder (1,1) string
    options.Mode (1,1) string {mustBeMember(options.Mode,["histogram","spe"])} = "histogram"
    options.ScanRoot (1,1) string = ""
    options.BootstrapCount (1,1) double {mustBeInteger,mustBeNonnegative} = 100
    options.Channels (1,:) double = []
    options.Vbias (1,:) double = []
    options.Vgain (1,:) double = []
end
source = load(fullfile(runFolder,'pipeline.mat'),'pipeline');
pipeline = source.pipeline;
if ~isfield(pipeline,'module')
    pipeline.module = scanModuleName(runFolder);
end
if ~isfield(pipeline,'campaign')
    pipeline.campaign = "ColdBox November 2026";
end
if ~isfield(pipeline,'figureTitle')
    pipeline.figureTitle = pipeline.campaign + " - Module " + pipeline.module;
end
if ~isfield(pipeline,'bootstrapSeed')
    pipeline.bootstrapSeed = 20261119;
end
points = dir(fullfile(runFolder,'vbias_*','vgain_*','channel_*','point_results.mat'));
assert(~isempty(points),'No saved scan points in %s.',runFolder);

% Require a fresh output directory to protect the original and avoid mixing runs.
assert(~isfolder(outputFolder),'Choose a new directory for the reprocessed outputs.');
[ok,message] = mkdir(outputFolder);
assert(ok,'Cannot create output directory: %s',message);
save(fullfile(outputFolder,'pipeline.mat'),'pipeline');
summary = table();
for k = 1:numel(points)
    file = fullfile(points(k).folder,points(k).name);
    metadata = load(file,'row');
    row = metadata.row;
    if (~isempty(options.Channels) && ~ismember(row.Channel,options.Channels)) || ...
            (~isempty(options.Vbias) && ~ismember(row.VbiasDAC,options.Vbias)) || ...
            (~isempty(options.Vgain) && ~ismember(row.VgainDAC,options.Vgain))
        continue
    end
    point = load(file);
    relative = fullfile(sprintf('vbias_%d',row.VbiasDAC),sprintf('vgain_%d',row.VgainDAC));
    destination = fullfile(outputFolder,relative,sprintf('channel_%d',row.Channel));
    mkdir(destination);
    events = point.events;
    oldSelection = events.SinglePECandidate;
    selected = oldSelection;
    if options.Mode=="histogram"
        evalMask = events.Accepted & ~events.Training;
        seed = pipeline.bootstrapSeed + 100000*row.VbiasDAC + 10*row.VgainDAC + row.Channel;
        stream = RandStream('mt19937ar','Seed',seed);
        point.pe = pds.calibration.fitPhotoelectronPeaks(events.ScoreADU, ...
            events.Accepted & events.Training,evalMask, ...
            ~events.Training & ~events.Duplicate & ~events.Rail,options.BootstrapCount,stream);
        [row,selected] = updateFit(row,point.pe,events.ScoreADU,evalMask);
        renderColdBoxScanHistogram(destination,row,point.pe,events.ScoreADU(evalMask),pipeline.figureTitle);
    end
    timing = point.timing;
    if nnz(selected)<50
        speMeanRaw = nan(size(point.rawMean));
    elseif isequal(selected,oldSelection) && isfield(point,'speMeanRaw')
        speMeanRaw = point.speMeanRaw;
    else
        archive = point.archive;
        if strlength(options.ScanRoot)>0
            archive = scanChannelFile(fullfile(options.ScanRoot,relative),row.Channel);
        end
        speMeanRaw = replaySinglePe(archive,events,selected,timing.polarity);
    end
    [row.SinglePEPeakToPeakADU,row.HistoricalDR,row.ADCHeadroomPE,extrema,speMean, ...
        row.RawSinglePEPeakToPeakADU] = pds.calibration.measureSinglePe( ...
        speMeanRaw,median(events.RawPedestalADU(selected)),timing.polarity,timing.rawPeak, ...
        FilterNumerator=pipeline.bNotch,FilterDenominator=pipeline.aNotch,AdcBits=pipeline.adcBits);
    row.SinglePECandidates = nnz(selected);
    singlePEIDs = events.EventID(selected);
    pe = point.pe;
    save(fullfile(destination,'reprocessed_point.mat'),'row','pe','timing','speMeanRaw', ...
        'speMean','extrema','singlePEIDs');
    saveColdBoxAverageSPE(destination,row,pipeline,speMean,extrema);
    if options.Mode=="spe"
        saveColdBoxLatePedestalComparison(destination,row,timing,pipeline,point.audit);
    end
    summary = [summary; row]; %#ok<AGROW>
end
assert(~isempty(summary),'The requested selection contains no saved points.');
summary = sortrows(summary,{'Channel','VbiasDAC','VgainDAC'});
writetable(summary,fullfile(outputFolder,'summary.csv'));
end

function [row,selected] = updateFit(row,pe,scores,evalMask)
row.Status = pe.status;
row.StatusReason = pe.message;
row.BinWidthADU = pe.binWidthADU;
row.HistogramLowerADU = pe.limitsADU(1);
row.HistogramUpperADU = pe.limitsADU(2);
row.MinimalVetoSNR = pe.minimalVetoSNR;
selected = false(size(evalMask));
fitValues = nan(1,6);
if pe.status=="resolved"
    fit = pe.fit;
    fitValues = [fit.delta,fit.sigma0,fit.sigma1,fit.snr,fit.snrCI95];
    selected = evalMask & abs(scores-fit.mu1)<=2*fit.sigma1;
end
row{:,{'DeltaADU','Sigma0ADU','Sigma1ADU','SNR','SNR_CI95_Low','SNR_CI95_High'}} = fitValues;
end

function average = replaySinglePe(archive,events,selected,polarity)
reader = pds.io.DaphneWaveformReader(archive);
cleanup = onCleanup(@() reader.close());
assert(reader.WaveformCount==height(events),'The archive does not match the saved event table.');
rows = find(selected);
waves = zeros(numel(rows),reader.SamplesPerWaveform,'uint16');
for k = 1:numel(rows)
    waves(k,:) = reader.read(events.EventID(rows(k)));
end
centered = polarity*pds.preprocess.subtractPedestal(waves,events.RawPedestalADU(selected));
average = mean(centered,1);
end
