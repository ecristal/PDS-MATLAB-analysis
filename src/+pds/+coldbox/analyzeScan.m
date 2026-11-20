function [summary, outputFolder, performance] = analyzeScan(scanRoot,shaperFile,outputRoot,options)
%ANALYZESCAN Analyze a ColdBox-format, externally triggered Vbias/Vgain scan.
% Pass the module directory with scan_metadata.txt, the reference IIR MAT
% file and a root for the timestamped outputs. UseParallel enables threads.
arguments
    scanRoot (1,1) string {mustBeFolder}
    shaperFile (1,1) string {mustBeFile}
    outputRoot (1,1) string
    options.Vbias (1,:) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = []
    options.Vgain (1,:) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = []
    options.Channels (1,:) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = []
    options.BootstrapCount (1,1) double {mustBeNonnegative,mustBeInteger} = 100
    options.UseParallel (1,1) logical = false
    options.MaxWorkers (1,1) double {mustBeNonnegative,mustBeInteger} = 0
    options.LateDelayUs (1,1) double {mustBePositive} = 5.12
    options.LateOffsetSigma (1,1) double {mustBePositive} = 4
    options.LateExcursionSigma (1,1) double {mustBePositive} = 6
    options.SamplePeriod (1,1) double {mustBePositive,mustBeFinite} = 16e-9
    options.AdcBits (1,1) double {mustBePositive,mustBeInteger} = 14
    options.NotchFrequencyHz (1,1) double {mustBePositive,mustBeFinite} = 10.0098e6
    options.NotchQ (1,1) double {mustBePositive,mustBeFinite} = 15
    options.LowPassHz (1,1) double {mustBePositive,mustBeFinite} = 2e6
    options.BoxcarPastSamples (1,1) double {mustBeNonnegative,mustBeInteger} = 17
    options.BootstrapSeed (1,1) double {mustBeNonnegative,mustBeInteger} = 20261119
    options.Campaign (1,1) string = "ColdBox November 2026"
end

totalClock = tic;
[~,module] = fileparts(regexprep(scanRoot,'[\\/]+$',''));
assert(strlength(module)>0,'Pass the module directory containing scan_metadata.txt.');
figureTitle = options.Campaign + " - Module " + module;
assert(~isempty(options.Vbias) && ~isempty(options.Vgain) && ~isempty(options.Channels), ...
    'Select at least one Vbias, Vgain and channel.');

assert(all([numel(unique(options.Vbias)),numel(unique(options.Vgain)), ...
    numel(unique(options.Channels))] == [numel(options.Vbias),numel(options.Vgain), ...
    numel(options.Channels)]), 'Pilot coordinates must be unique.');

scanMeta = fileread(fullfile(scanRoot,'scan_metadata.txt'));
assert(contains(scanMeta,'status=complete') && contains(scanMeta,'set_as_dac=true'));
count = configNumber(scanMeta,'waveform_count');
lengthSamples = configNumber(scanMeta,'waveform_length');

fs = 1/options.SamplePeriod;
notchFrequency = options.NotchFrequencyHz;
notchQ = options.NotchQ;
notchCenter = notchFrequency/(fs/2);
[bNotch,aNotch] = iirnotch(notchCenter,notchCenter/notchQ);
[bLow,aLow] = butter(3,options.LowPassHz/(fs/2),'low');
shaper = load(shaperFile,'numz_planta_integrator','denz_planta_integrator');
pipeline = struct('sampleRateHz',fs,'adcBits',options.AdcBits, ...
    'notchFrequencyHz',notchFrequency,'notchQ',notchQ, ...
    'bNotch',bNotch,'aNotch',aNotch,'bLow',bLow,'aLow',aLow, ...
    'bHp',shaper.numz_planta_integrator,'aHp',shaper.denz_planta_integrator, ...
    'shaperFile',shaperFile,'boxcarPastSamples',options.BoxcarPastSamples,'lowPassHz',options.LowPassHz, ...
    'figureTitle',figureTitle,'campaign',options.Campaign,'module',module, ...
    'bootstrapSeed',options.BootstrapSeed, ...
    'lateDelayUs',options.LateDelayUs,'lateOffsetSigma',options.LateOffsetSigma, ...
    'lateExcursionSigma',options.LateExcursionSigma);
points = scanPoints(scanRoot,options.Vbias,options.Vgain, ...
    options.Channels,count,lengthSamples);
assert(~isempty(points),'Select at least one Vbias, Vgain and channel.');
stamp = string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
outputFolder = fullfile(outputRoot,module + "_" + stamp + "_UTC");
mkdir(outputFolder);
fprintf('Run output: %s\n',outputFolder);
save(fullfile(outputFolder,'pipeline.mat'),'pipeline');

cpuLimit = maxNumCompThreads;
poolStartup = 0;
memoryLimit = NaN;
hostGiB = NaN;
workers = 0;
mode = "serial";
if options.UseParallel
    assert(license('test','Distrib_Computing_Toolbox'), ...
        'UseParallel requires Parallel Computing Toolbox.');
    [workers,memoryLimit,hostGiB] = workerLimit(cpuLimit,options.MaxWorkers,numel(points),count,lengthSamples);
    poolClock = tic;
    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('Threads',workers);
        closePool = onCleanup(@() delete(pool));
    else
        assert(isa(pool,'parallel.ThreadPool'), ...
            'An existing process pool is active. Close it or call with UseParallel=false.');
        workers = min(workers,pool.NumWorkers);
    end
    poolStartup = toc(poolClock);
    mode = "threads";
    fprintf('Using %d thread workers; MATLAB core limit %d, RAM worker limit %g.\n', ...
        workers,cpuLimit,memoryLimit);
end

runClock = tic;
if options.UseParallel
    [summary,pointTimes] = runThreaded(points,outputFolder,pipeline,count,lengthSamples, ...
        options.BootstrapCount,pool,workers);
else
    [summary,pointTimes] = runSerial(points,outputFolder,pipeline,count,lengthSamples, ...
        options.BootstrapCount);
end
processingSeconds = toc(runClock);
summary = sortrows(summary,{'Channel','VbiasDAC','VgainDAC'});
pointTimes = sortrows(pointTimes,{'Channel','VbiasDAC','VgainDAC'});
writetable(summary,fullfile(outputFolder,'summary.csv'));
writetable(pointTimes,fullfile(outputFolder,'point_timing.csv'));
performance = table(mode,workers,cpuLimit,memoryLimit,hostGiB,height(summary),poolStartup, ...
    processingSeconds,toc(totalClock),sum(pointTimes.ReadSeconds), ...
    sum(pointTimes.ComputeSeconds),sum(pointTimes.ExportSeconds), ...
    'VariableNames',{'Mode','Workers','MATLABCoreLimit','RAMWorkerLimit','AvailableRAMGiB', ...
    'Points','PoolStartupSeconds','ProcessingSeconds','WallSeconds', ...
    'ReadSecondsSum','ComputeSecondsSum','ExportSecondsSum'});
writetable(performance,fullfile(outputFolder,'performance.csv'));
writeReport(outputFolder,summary,pipeline,performance);
fprintf('Completed %d points in %.1f seconds (%s).\n',height(summary),performance.WallSeconds,mode);
end

function points = scanPoints(scanRoot,biasValues,gainValues,channels,count,lengthSamples)
points = struct('archive',{},'channel',{},'offset',{},'vbias',{},'vgain',{});
for vbias = biasValues
    for vgain = gainValues
        point = fullfile(scanRoot,sprintf('vbias_%d',vbias),sprintf('vgain_%d',vgain));
        metadata = fileread(fullfile(point,'config.txt'));
        assert(configNumber(metadata,'bias_requested') == vbias && ...
            configNumber(metadata,'vgain_requested') == vgain && ...
            contains(metadata,'bias_units=DAC') && contains(metadata,'vgain_units=DAC') && ...
            configNumber(metadata,'number_of_waveforms') == count && ...
            configNumber(metadata,'waveform_length') == lengthSamples && ...
            contains(metadata,'trigger_source=external'), 'Configuration mismatch at %s.',point);
        marker = "===== verified final hardware configuration =====";
        fragments = splitlines(extractAfter(string(metadata),marker));
        readback = jsondecode(strtrim(fragments(find(strlength(strtrim(fragments))>0,1))));
        assert(readback.afes.bias == vbias && readback.afes.vgain == vgain, ...
            'Hardware readback mismatch at %s.',point);
        for channel = channels
            channelConfig = readback.channels([readback.channels.channel] == channel);
            assert(isscalar(channelConfig) && channelConfig.bias == vbias, ...
                'Missing or mismatched hardware readback for channel %d.',channel);
            points(end+1) = struct('archive',fullfile(point,sprintf('channel_%d.7z',channel)), ...
                'channel',channel,'offset',channelConfig.offset,'vbias',vbias,'vgain',vgain); %#ok<AGROW>
        end
    end
end
end

function [workers,memoryLimit,available] = workerLimit(cpuLimit,requested,nPoints,nSamples,lengthSamples)
workers = min(cpuLimit,nPoints);
if requested>0, workers = min(workers,requested); end
memoryLimit = NaN;
available = NaN;
if ispc
    [~,hostMemory] = memory;
    available = hostMemory.PhysicalMemory.Available/2^30;
    % Two full double matrices plus room for the raw input and batched filters.
    bytesPerPoint = 16*nSamples*lengthSamples+96*2^20;
    memoryLimit = max(1,floor((hostMemory.PhysicalMemory.Available-256*2^20)/bytesPerPoint));
    workers = min(workers,memoryLimit);
end
end

function [summary,times] = runSerial(points,folder,p,n,m,bootstrap)
summary = table();
times = table();
for k = 1:numel(points)
    point = points(k);
    [raw,readSeconds] = loadPoint(point,n,m);
    result = analyzePoint(raw,p,point,bootstrap);
    clear raw
    [summary,times] = publishPoint(folder,p,point,result,readSeconds,summary,times);
end
end

function [summary,times] = runThreaded(points,folder,p,n,m,bootstrap,pool,workers)
summary = table();
times = table();
futures = parallel.FevalFuture.empty(1,0);
indices = [];
readTimes = [];
next = 1;
try
    for slot = 1:workers
        [futures(slot),readTimes(slot)] = submitPoint(pool,points(next),p,n,m,bootstrap);
        indices(slot) = next;
        next = next+1;
    end
    while ~isempty(futures)
        [slot,result] = fetchNext(futures);
        point = points(indices(slot));
        readSeconds = readTimes(slot);
        if next<=numel(points)
            [futures(slot),readTimes(slot)] = submitPoint(pool,points(next),p,n,m,bootstrap);
            indices(slot) = next;
            next = next+1;
        else
            futures(slot) = [];
            indices(slot) = [];
            readTimes(slot) = [];
        end
        [summary,times] = publishPoint(folder,p,point,result,readSeconds,summary,times);
    end
catch exception
    cancel(futures);
    rethrow(exception);
end
end

function [future,readSeconds] = submitPoint(pool,point,p,n,m,bootstrap)
[raw,readSeconds] = loadPoint(point,n,m);
future = parfeval(pool,@analyzePoint,1,raw,p,point,bootstrap);
end

function [raw,readSeconds] = loadPoint(point,n,m)
readClock = tic;
fprintf('Reading Vbias %d | Vgain %d | CH %d\n',point.vbias,point.vgain,point.channel);
reader = pds.io.DaphneWaveformReader(point.archive);
closeReader = onCleanup(@() reader.close());
assert(reader.WaveformCount == n && reader.SamplesPerWaveform == m, ...
    'Waveform dimensions differ from scan metadata: %s',point.archive);
raw = zeros(n,m,'uint16');
blockSize = 1024;
for first = 1:blockSize:n
    last = min(n,first+blockSize-1);
    raw(first:last,:) = reader.readBlock(first,last-first+1);
end
clear closeReader
readSeconds = toc(readClock);
end

function [summary,times] = publishPoint(folder,p,point,result,readSeconds,summary,times)
exportClock = tic;
row = result.row;
destination = fullfile(folder,sprintf('vbias_%d',point.vbias), ...
    sprintf('vgain_%d',point.vgain),sprintf('channel_%d',point.channel));
mkdir(destination);
save(fullfile(destination,'point_results.mat'),'-struct','result', ...
    'row','timing','events','pe','rawMean','shapedMean','speMean','speMeanRaw', ...
    'spectrum','quartiles','fences','archive','late','audit');
save_coldbox_scan_figures(destination,row,result.timing,p,result.pe,result.evaluationScores, ...
    result.rawMean,result.shapedMean/result.scorePeak,result.speMean,result.extrema, ...
    result.spectrum,result.boxplotInputs);
saveColdBoxLatePedestalComparison(destination,row,result.timing,p,result.audit);
summary = [summary; row];
writetable(summary,fullfile(folder,'summary.csv'));
times = [times; table(point.channel,point.vbias,point.vgain,readSeconds,result.computeSeconds, ...
    toc(exportClock),'VariableNames',{'Channel','VbiasDAC','VgainDAC','ReadSeconds','ComputeSeconds','ExportSeconds'})];
fprintf('Finished %d/%d CH %d | %s | accepted %d / %d | SNR %.3f | DR %.1f\n', ...
    point.vbias,point.vgain,point.channel,row.Status,row.Accepted,row.Records,row.SNR,row.HistoricalDR);
end

function result = analyzePoint(raw,p,point,bootstrap)
computeClock = tic;
[n,m] = size(raw);
channel = point.channel;
offset = point.offset;
vbias = point.vbias;
vgain = point.vgain;
ids = (1:n).';
training = mod(ids,2) == 1;
rail = any(raw == 0 | raw >= 2^p.adcBits-1,2);
duplicate = [false; all(raw(2:end,:) == raw(1:end-1,:),2)];
eligible = ~rail & ~duplicate;
reference = eligible & training;
assert(nnz(reference)>100,'Too few intact training waveforms.');

% Locate the synchronized pulse in the central part of the raw record.
pulseWindow = 201:min(450,m);
profile = trimmean(double(raw(reference,:)),10,1);
profile = movmean(profile,5);
pulseBaseline = median(profile(180:205));
[peak,relativePeak] = max(abs(profile(pulseWindow)-pulseBaseline));
pp = pulseWindow(relativePeak);
assert(isfinite(peak) && peak>0,'No pulse found in the external trigger window.');
polarity = sign(profile(pp)-pulseBaseline);
pulse = polarity*(profile-pulseBaseline);
before = max(1,pp-60):pp-1;
onset = before(find(pulse(before)<=0.05*peak,1,'last'))+1;
assert(isscalar(onset) && onset>=118,'Cannot establish a 100-sample pre-pulse region.');
pre = onset-115:onset-16;
[baseline,quality] = pds.preprocess.estimatePedestal(raw(:,pre), ...
    SampleIndices=1:numel(pre),Method="median-of-means",BlockSize=10);
centered = polarity*pds.preprocess.subtractPedestal(raw,baseline);

% Measure diagnostics on the notch + low-pass copy, then select original IDs.
clear raw
diagnostic = diagnosticFilterBatches(centered,p);
diagnosticMean = mean(diagnostic(reference,:),1);
[~,diagnosticPeak] = max(diagnosticMean(pulseWindow));
diagnosticPeak = pulseWindow(diagnosticPeak);
preOffset = median(diagnostic(:,pre),2);
preExcursion = max(abs(diagnostic(:,pre)-preOffset),[],2);
preThreshold = robustFence(preExcursion(reference));
pedestalOutlier = abs(preOffset-median(preOffset(reference))) > ...
    robustFence(abs(preOffset(reference)-median(preOffset(reference))));
outOfTime = preExcursion>preThreshold;
beforeLate = eligible & ~outOfTime & ~pedestalOutlier;
late = pds.preprocess.vetLatePedestal(diagnostic,pre,pp,1/p.sampleRateHz,beforeLate & training, ...
    DelayUs=p.lateDelayUs,OffsetSigma=p.lateOffsetSigma,ExcursionSigma=p.lateExcursionSigma);
accepted = beforeLate & ~late.offsetVeto & ~late.excursionVeto;
lateOffset = late.representativeOffsetADU;
filteredPeak = diagnostic(:,diagnosticPeak);
clear raw diagnostic

% The late gate uses the untapered diagnostic copy. The Tukey taper is only
% part of pulse scoring, and stays flat across the prompt score window.
edge = floor((onset-1)/2);
alpha = 2*max(0,edge)/(m-1);
taper = pds.signal.createWindow(m,"tukey",TukeyRatio=alpha);
shaped = scoreFilterBatches(centered,taper,p);
train = accepted & training;
eval = accepted & ~training;
assert(nnz(train)>100 && nnz(eval)>100,'Too few events after pre-pulse quality gates.');
search = onset:min(pp+160,m);
referenceMean = mean(shaped(beforeLate & training,:),1);
[scorePeak,relativeSample] = max(referenceMean(search));
scoreSample = search(relativeSample);
assert(isfinite(scorePeak) && scorePeak>0 && scoreSample<m && ...
    all(taper(onset:scoreSample+1) == 1), 'Score window is outside the flat part of the Tukey taper.');
scores = 2*mean(shaped(:,scoreSample-1:scoreSample+1),2);
assert(all(isfinite(scores)),'Nonfinite event score.');
shapedMean = mean(shaped(eval,:),1);
spectrum = meanLegacySpectrum(shaped,eval,scorePeak);
clear shaped
seed = p.bootstrapSeed+100000*vbias+10*vgain+channel;
stream = RandStream('mt19937ar','Seed',seed);
pe = pds.calibration.fitPhotoelectronPeaks(scores,train,eval,eligible & ~training,bootstrap,stream);

beforeEval = beforeLate & ~training;
beforeFit = pds.calibration.fitPhotoelectronPeaks(scores,beforeLate & training,beforeEval,beforeEval,0);
audit = compareLatePedestalSelection(centered,scores,beforeEval,eval,late,beforeFit,pe);
rawMean = audit.afterMean;

spe = false(n,1);
speMeanRaw = nan(1,m);
if pe.status == "resolved"
    spe = eval & abs(scores-pe.fit.mu1)<=2*pe.fit.sigma1;
    if nnz(spe)>=50
        speMeanRaw = mean(centered(spe,:),1);
    end
end
[amplitude,range,headroom,extrema,speMean,rawAmplitude] = ...
    pds.calibration.measureSinglePe(speMeanRaw,median(baseline(spe)),polarity,pp, ...
        FilterNumerator=p.bNotch,FilterDenominator=p.aNotch,AdcBits=p.adcBits);
events = table(ids,training,rail,duplicate,outOfTime,pedestalOutlier,beforeLate, ...
    late.offsetVeto,late.excursionVeto,accepted,quality.validEventMask,baseline, ...
    preOffset,lateOffset,late.maxBlockOffsetADU,late.maxExcursionADU, ...
    preExcursion,filteredPeak,scores,spe, ...
    'VariableNames',{'EventID','Training','Rail','Duplicate','PrePulseExcursion', ...
    'PrePulseOffset','AcceptedBeforeLate','LateOffsetVeto','LateExcursionVeto', ...
    'Accepted','PdsRawPedestalQuality','RawPedestalADU','FilteredEarlyOffsetADU', ...
    'FilteredLateOffsetADU','LateMaxBlockOffsetADU','LateMaxExcursionADU', ...
    'PrePulseMaxADU','FilteredPeakADU','ScoreADU','SinglePECandidate'});
boxplotInputs = [filteredPeak preOffset lateOffset];
quartiles = [prctile(boxplotInputs(:,1:2),[25 50 75],1),nan(3,1)];
if isfinite(late.start)
    quartiles(:,3) = prctile(lateOffset,[25 50 75]);
end
fences = [quartiles(1,:)-1.5*(quartiles(3,:)-quartiles(1,:)); ...
    quartiles(3,:)+1.5*(quartiles(3,:)-quartiles(1,:))];
timing = struct('onset',onset,'rawPeak',pp,'diagnosticPeak',diagnosticPeak, ...
    'lateOnset',late.start,'lateBlockBounds',late.bounds,'preSamples',pre,'scoreSample',scoreSample,'polarity',polarity, ...
    'tukeyRatio',alpha,'prePulseExcursionLimitADU',preThreshold);
status = pe.status;
snr = NaN; ci = [NaN NaN]; delta = NaN; noise = NaN; singleWidth = NaN;
if status == "resolved"
    snr = pe.fit.snr;
    ci = pe.fit.snrCI95;
    delta = pe.fit.delta;
    noise = pe.fit.sigma0;
    singleWidth = pe.fit.sigma1;
end
row = table(channel,vbias,vgain,offset,status,n,nnz(accepted),nnz(train),nnz(eval), ...
    nnz(rail),nnz(duplicate),nnz(outOfTime),nnz(pedestalOutlier),nnz(spe),onset,pp, ...
    late.start,scoreSample,alpha,delta,noise,singleWidth,snr,ci(1),ci(2), ...
    pe.minimalVetoSNR,amplitude,range,headroom,rawAmplitude, ...
    pe.binWidthADU,pe.limitsADU(1),pe.limitsADU(2),pe.message, ...
    nnz(beforeLate),nnz(beforeLate & late.offsetVeto),nnz(beforeLate & late.excursionVeto), ...
    late.offsetLimitADU,late.excursionLimitADU,audit.meanLateADU(1),audit.meanLateADU(2), ...
    audit.singlePELateADU(1),audit.singlePELateADU(2), ...
    audit.zeroPEKeptFraction,audit.singlePEKeptFraction,audit.beforeSNR, ...
    'VariableNames',{'Channel','VbiasDAC','VgainDAC','OffsetReadback','Status', ...
    'Records','Accepted','TrainAccepted','EvalAccepted','RailCount','DuplicateCount', ...
    'PrePulseExcursionCount','PrePulseOffsetCount','SinglePECandidates','IP','PP', ...
    'LateWindowStart','ScoreSample','TukeyRatio','DeltaADU','Sigma0ADU','Sigma1ADU', ...
    'SNR','SNR_CI95_Low','SNR_CI95_High','MinimalVetoSNR','SinglePEPeakToPeakADU', ...
    'HistoricalDR','ADCHeadroomPE','RawSinglePEPeakToPeakADU','BinWidthADU','HistogramLowerADU','HistogramUpperADU','StatusReason', ...
    'AcceptedBeforeLate','LateOffsetVetoCount','LateExcursionVetoCount', ...
    'LateOffsetLimitADU','LateExcursionLimitADU','AverageLateBeforeADU','AverageLateAfterADU', ...
    'MatchedSPELateBeforeADU','MatchedSPELateAfterADU','ZeroPERetainedFraction', ...
    'OnePERetainedFraction','SNRBeforeLateVeto'});
result = struct('row',row,'timing',timing,'events',events,'pe',pe,'rawMean',rawMean, ...
    'shapedMean',shapedMean,'speMean',speMean,'speMeanRaw',speMeanRaw, ...
    'spectrum',spectrum,'quartiles',quartiles,'fences',fences,'archive',point.archive, ...
    'late',late,'audit',audit,'extrema',extrema,'boxplotInputs',boxplotInputs, ...
    'scorePeak',scorePeak,'evaluationScores',scores(eval),'computeSeconds',toc(computeClock));
end

function diagnostic = diagnosticFilterBatches(centered,p)
diagnostic = zeros(size(centered));
for first = 1:1024:size(centered,1)
    rows = first:min(first+1023,size(centered,1));
    diagnostic(rows,:) = diagnosticBandwidth(centered(rows,:),p);
end
end

function shaped = scoreFilterBatches(centered,taper,p)
shaped = zeros(size(centered));
window = reshape(taper,1,[]);
for first = 1:1024:size(centered,1)
    rows = first:min(first+1023,size(centered,1));
    x = diagnosticBandwidth(centered(rows,:).*window,p);
    x = filter(p.bHp,p.aHp,x,[],2);
    shaped(rows,:) = movmean(x,[p.boxcarPastSamples 0],2);
end
end

function filtered = diagnosticBandwidth(waveforms,p)
notched = filter(p.bNotch,p.aNotch,waveforms,[],2);
filtered = filter(p.bLow,p.aLow,notched,[],2);
end

function audit = compareLatePedestalSelection(centered,scores,before,after,late,beforeFit,afterFit)
% Match the SPE score window across selections to isolate the veto effect.
beforeMean = mean(centered(before,:),1);
afterMean = mean(centered(after,:),1);
lateSamples = late.start:size(centered,2);
audit = struct('beforeMean',beforeMean,'afterMean',afterMean, ...
    'meanLateADU',[mean(beforeMean(lateSamples)) mean(afterMean(lateSamples))], ...
    'beforeMatchedSPE',nan(size(beforeMean)),'afterMatchedSPE',nan(size(beforeMean)), ...
    'singlePELateADU',[NaN NaN],'zeroPEKeptFraction',NaN,'singlePEKeptFraction',NaN, ...
    'beforeSNR',NaN,'classReference',"none");
if beforeFit.status=="resolved"
    audit.beforeSNR = beforeFit.fit.snr;
end
cal = beforeFit.trainingFit;
if ~isempty(cal) && cal.valid
    audit.classReference = "training before late veto";
elseif ~isempty(afterFit.trainingFit) && afterFit.trainingFit.valid
    cal = afterFit.trainingFit;
    audit.classReference = "training after late veto";
else
    return
end
mid = (cal.mu0+cal.mu1)/2;
zero = abs(scores-cal.mu0)<=2*cal.sigma0 & scores<=mid;
one = abs(scores-cal.mu1)<=2*cal.sigma1 & scores>mid;
if any(before & zero)
    audit.zeroPEKeptFraction = nnz(after & zero)/nnz(before & zero);
end
if nnz(before & one)>=50 && nnz(after & one)>=50
    audit.singlePEKeptFraction = nnz(after & one)/nnz(before & one);
    audit.beforeMatchedSPE = mean(centered(before & one,:),1);
    audit.afterMatchedSPE = mean(centered(after & one,:),1);
    audit.singlePELateADU = [mean(audit.beforeMatchedSPE(lateSamples)) ...
        mean(audit.afterMatchedSPE(lateSamples))];
end
end
function limit = robustFence(x)
center = median(x);
limit = center + 8*max(1.4826*median(abs(x-center)),0.1);
end

function n = configNumber(contents,key)
n = str2double(readAcquisitionParameter(contents,key));
assert(isfinite(n) && n>=0 && n==fix(n),'Expected an unsigned integer for %s.',key);
end

function spectrum = meanLegacySpectrum(shaped,mask,normalization)
% Legacy figure uses the mean one-sided peak amplitude divided by full scale.
idx = find(mask);
m = size(shaped,2);
amplitude = zeros(1,floor(m/2)+1);
for first = 1:1000:numel(idx)
    batch = idx(first:min(first+999,numel(idx)));
    s = pds.signal.computeSpectrum(shaped(batch,:)/normalization,1,RemoveMean=false);
    amplitude = amplitude + numel(batch)*s.amplitudeMean;
end
spectrum = amplitude/numel(idx);
end

function writeReport(outputFolder,summary,p,performance)
fid = fopen(fullfile(outputFolder,'report.md'),'w');
assert(fid>=0,'Cannot write pilot report.');
closeReport = onCleanup(@() fclose(fid));
fprintf(fid,'# %s - Vbias / Vgain scan\n\n',p.figureTitle);
fprintf(fid,'Execution: %s, %d worker(s), %.2f s wall time (%.2f s pool setup).\n\n', ...
    performance.Mode,performance.Workers,performance.WallSeconds,performance.PoolStartupSeconds);
fprintf(fid,'Processed %d channel-points and %d records. %d points resolved 0 and 1 PE.\n\n', ...
    height(summary),sum(summary.Records),nnz(summary.Status=="resolved"));
fprintf(fid,['The SNR estimator uses pedestal subtraction, Tukey taper, a %.4f MHz notch (Q = %g), ' ...
    'a %g MHz third-order Butterworth low-pass, the reference integrator IIR, ' ...
    'and a causal %d-sample moving average.\n\n'], ...
    p.notchFrequencyHz/1e6,p.notchQ,p.lowPassHz/1e6,p.boxcarPastSamples+1);
fprintf(fid,['Odd IDs determine pulse and score windows, amplitude calibration and quality thresholds. ' ...
    'Even IDs estimate SNR and supply the original waveforms for the notch-filtered 1-PE average. The late gate is applied to the original event IDs before histogram fitting. ' ...
    'The comparison column uses the same score calibration after only rail and duplicate removal. ' ...
    'Bootstrap intervals condition on training and use independent evaluation record resamples.\n\n']);
fprintf(fid,['Historical DR uses %d divided by the notch-filtered 1-PE peak-to-peak amplitude. ' ...
    'ADC headroom uses the raw 1-PE average, measured pedestal and %d-bit rails. ' ...
    'A linearity measurement needs saturation data. The spectral plot shows the shaped waveform ' ...
    'in the legacy normalization.\n\n'],2^p.adcBits,p.adcBits);
fprintf(fid,'Each point has the Live Script layouts for the average waveform, integral histogram, spectrum and 1-PE waveform, plus a diagnostic boxplot panel. Figures accompany a point MAT file with event masks, estimated windows and fit diagnostics, and a separate histogram model file. Reference-layout PNGs use 700 by 525 pixels. A supplemental comparison shows the raw all-waveform averages and notch-filtered 1-PE averages before and after the late veto. Histograms stay in raw score ADU with per-point limits and a bin width chosen on training. The red overlay includes higher PE orders supported by local maxima near the common peak spacing. SNR is evaluated from a joint, bin-integrated 0- and 1-PE fit.\n\n');
fprintf(fid,['The late ROI starts %.2f us after the raw pulse peak. ' ...
    'The notch/low-pass diagnostic vetoes a block offset above %.1f robust early contrast scales ' ...
    'or an excursion above %.1f robust early sample scales. Both scales are learned on ' ...
    'odd records passing initial quality gates. The late raw baseline is not subtracted. ' ...
    'Both SPE comparison curves use the same training-defined 1-PE score interval.\n\n'], ...
    p.lateDelayUs,p.lateOffsetSigma,p.lateExcursionSigma);
fprintf(fid,'| CH | Vbias DAC | Vgain DAC | Before / after late veto | Raw late ADU before / after | Raw SPE late ADU before / after | 0/1 PE | SNR | Historical DR |\n');
fprintf(fid,'|---:|---:|---:|---:|---:|---:|:---|---:|---:|\n');
for k = 1:height(summary)
    s = summary(k,:);
    fprintf(fid,'| %d | %d | %d | %d / %d | %.2f / %.2f | %.2f / %.2f | %s | %.3f | %.1f |\n', ...
        s.Channel,s.VbiasDAC,s.VgainDAC,s.AcceptedBeforeLate,s.Accepted, ...
        s.AverageLateBeforeADU,s.AverageLateAfterADU,s.MatchedSPELateBeforeADU, ...
        s.MatchedSPELateAfterADU,s.Status,s.SNR,s.HistoricalDR);
end
end
