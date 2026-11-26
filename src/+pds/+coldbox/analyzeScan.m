function [summary, outputFolder, performance] = analyzeScan(scanRoot,shaperFile,outputRoot,options)
%ANALYZESCAN Analyze a ColdBox-format, externally triggered Vbias/Vgain scan.
% Pass the module directory with scan_metadata.txt, the reference IIR MAT
% file and a root for the timestamped outputs. UseParallel enables threads.
% UseTukey, UseNotch, UseLowPass, UseIntegrator and UseBoxcar select stages.
% LowPassHz is in Hz. BoxcarLength counts the current sample.
arguments
    scanRoot (1,1) string {mustBeFolder}
    shaperFile (1,1) string
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
    options.UseTukey (1,1) logical = true
    options.UseNotch (1,1) logical = true
    options.NotchFrequencyHz (1,1) double {mustBePositive,mustBeFinite} = 10.0098e6
    options.NotchQ (1,1) double {mustBePositive,mustBeFinite} = 15
    options.UseLowPass (1,1) logical = true
    options.LowPassHz (1,1) double {mustBePositive,mustBeFinite} = 2e6
    options.UseIntegrator (1,1) logical = true
    options.UseBoxcar (1,1) logical = true
    options.BoxcarLength (1,:) double {mustBePositive,mustBeInteger,mustBeFinite} = []
    options.BoxcarPastSamples (1,:) double {mustBeNonnegative,mustBeInteger,mustBeFinite} = []
    options.SweepLowPassHz (1,:) double {mustBePositive,mustBeFinite} = []
    options.SweepBoxcarLengths (1,:) double {mustBePositive,mustBeInteger,mustBeFinite} = []
    options.BootstrapSeed (1,1) double {mustBeNonnegative,mustBeInteger} = 20261119
    options.Campaign (1,1) string = "ColdBox November 2026"
end

totalClock = tic;
module = scanModuleName(scanRoot);
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
isSweep = ~isempty(options.SweepLowPassHz) || ~isempty(options.SweepBoxcarLengths);
analyzer = @analyzePoint;
publisher = @publishPoint;
runTag = module;
if isSweep
    assert(~isempty(options.SweepLowPassHz) && ~isempty(options.SweepBoxcarLengths), ...
        'Supply both the low-pass and boxcar sweep axes.');
    assert(options.UseLowPass && options.UseBoxcar,'The sweep requires the low-pass and boxcar stages.');
    assert(module~="M3" || options.UseNotch,'The M3 SNR sweep requires the notch.');
    assert(all(options.SweepLowPassHz<fs/2),'All sweep cutoffs must be below Nyquist (%g Hz).',fs/2);
    analyzer = @sweepPoint;
    publisher = @publishSweepPoint;
    runTag = module + "_snr_sweep";
end
boxcarLength = [options.BoxcarLength,options.BoxcarPastSamples+1];
assert(numel(boxcarLength)<=1,'Specify one scalar value for BoxcarLength or BoxcarPastSamples.');
if isempty(boxcarLength), boxcarLength = 18; end

bNotch = 1; aNotch = 1;
if options.UseNotch
    assert(options.NotchFrequencyHz<fs/2, ...
        'pds:coldbox:analyzeScan:NotchNyquist','NotchFrequencyHz must be below Nyquist (%g Hz).',fs/2);
    notchCenter = options.NotchFrequencyHz/(fs/2);
    [bNotch,aNotch] = iirnotch(notchCenter,notchCenter/options.NotchQ);
end
bLow = 1; aLow = 1;
if options.UseLowPass && ~isSweep
    assert(options.LowPassHz<fs/2, ...
        'pds:coldbox:analyzeScan:LowPassNyquist','LowPassHz must be below Nyquist (%g Hz).',fs/2);
    [bLow,aLow] = butter(3,options.LowPassHz/(fs/2),'low');
end
bHp = 1; aHp = 1;
if options.UseIntegrator
    mustBeFile(shaperFile);
    shaper = load(shaperFile,'numz_planta_integrator','denz_planta_integrator');
    bHp = shaper.numz_planta_integrator;
    aHp = shaper.denz_planta_integrator;
end
pipeline = struct('sampleRateHz',fs,'adcBits',options.AdcBits, ...
    'useTukey',options.UseTukey,'useNotch',options.UseNotch, ...
    'notchFrequencyHz',options.NotchFrequencyHz,'notchQ',options.NotchQ,'bNotch',bNotch,'aNotch',aNotch, ...
    'useLowPass',options.UseLowPass,'lowPassHz',options.LowPassHz,'bLow',bLow,'aLow',aLow, ...
    'useIntegrator',options.UseIntegrator,'shaperFile',shaperFile,'bHp',bHp,'aHp',aHp, ...
    'useBoxcar',options.UseBoxcar,'boxcarLength',boxcarLength,'boxcarPastSamples',boxcarLength-1, ...
    'figureTitle',figureTitle,'campaign',options.Campaign,'module',module, ...
    'bootstrapSeed',options.BootstrapSeed, ...
    'lateDelayUs',options.LateDelayUs,'lateOffsetSigma',options.LateOffsetSigma, ...
    'lateExcursionSigma',options.LateExcursionSigma);
if isSweep
    pipeline.sweepLowPassHz = unique(options.SweepLowPassHz);
    pipeline.sweepBoxcarLengths = unique(options.SweepBoxcarLengths);
    pipeline.sweepBLow = zeros(numel(pipeline.sweepLowPassHz),4);
    pipeline.sweepALow = zeros(size(pipeline.sweepBLow));
    for i = 1:numel(pipeline.sweepLowPassHz)
        [pipeline.sweepBLow(i,:),pipeline.sweepALow(i,:)] = ...
            butter(3,pipeline.sweepLowPassHz(i)/(fs/2),'low');
    end
end
points = scanPoints(scanRoot,options.Vbias,options.Vgain, ...
    options.Channels,count,lengthSamples);
assert(~isempty(points),'Select at least one Vbias, Vgain and channel.');
stamp = string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
outputFolder = fullfile(outputRoot,runTag + "_" + stamp + "_UTC");
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
    [workers,memoryLimit,hostGiB] = workerLimit(cpuLimit,options.MaxWorkers,numel(points),count,lengthSamples,isSweep);
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
        options.BootstrapCount,pool,workers,analyzer,publisher);
else
    [summary,pointTimes] = runSerial(points,outputFolder,pipeline,count,lengthSamples, ...
        options.BootstrapCount,analyzer,publisher);
end
processingSeconds = toc(runClock);
summary = sortrows(summary,{'Channel','VbiasDAC','VgainDAC'});
pointTimes = sortrows(pointTimes,{'Channel','VbiasDAC','VgainDAC'});
if isSweep
    writetable(summary,fullfile(outputFolder,'snr_grid.csv'));
    summary = pds.coldbox.plotSNRSweep(outputFolder);
else
    writetable(summary,fullfile(outputFolder,'summary.csv'));
end
writetable(pointTimes,fullfile(outputFolder,'point_timing.csv'));
performance = table(mode,workers,cpuLimit,memoryLimit,hostGiB,height(summary),poolStartup, ...
    processingSeconds,toc(totalClock),sum(pointTimes.ReadSeconds), ...
    sum(pointTimes.ComputeSeconds),sum(pointTimes.ExportSeconds), ...
    'VariableNames',{'Mode','Workers','MATLABCoreLimit','RAMWorkerLimit','AvailableRAMGiB', ...
    'Points','PoolStartupSeconds','ProcessingSeconds','WallSeconds', ...
    'ReadSecondsSum','ComputeSecondsSum','ExportSecondsSum'});
writetable(performance,fullfile(outputFolder,'performance.csv'));
if ~isSweep, writeReport(outputFolder,summary,pipeline,performance); end
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
            points(end+1) = struct('archive',scanChannelFile(point,channel), ...
                'channel',channel,'offset',channelConfig.offset,'vbias',vbias,'vgain',vgain); %#ok<AGROW>
        end
    end
end
end

function [workers,memoryLimit,available] = workerLimit(cpuLimit,requested,nPoints,nSamples,lengthSamples,isSweep)
workers = min(cpuLimit,nPoints);
if requested>0, workers = min(workers,requested); end
memoryLimit = NaN;
available = NaN;
if ispc
    [~,hostMemory] = memory;
    available = hostMemory.PhysicalMemory.Available/2^30;
    % The sweep also retains both notch prefixes and an intermediate waveform.
    bytesPerPoint = (16+24*isSweep)*nSamples*lengthSamples+96*2^20;
    memoryLimit = max(1,floor((hostMemory.PhysicalMemory.Available-256*2^20)/bytesPerPoint));
    workers = min(workers,memoryLimit);
end
end

function [summary,times] = runSerial(points,folder,p,n,m,bootstrap,analyzer,publisher)
summary = table();
times = table();
for k = 1:numel(points)
    point = points(k);
    [raw,readSeconds] = loadPoint(point,n,m);
    result = analyzer(raw,p,point,bootstrap);
    clear raw
    [summary,times] = publisher(folder,p,point,result,readSeconds,summary,times);
end
end

function [summary,times] = runThreaded(points,folder,p,n,m,bootstrap,pool,workers,analyzer,publisher)
summary = table();
times = table();
futures = parallel.FevalFuture.empty(1,0);
indices = [];
readTimes = [];
next = 1;
try
    for slot = 1:workers
        [futures(slot),readTimes(slot)] = submitPoint(pool,points(next),p,n,m,bootstrap,analyzer);
        indices(slot) = next;
        next = next+1;
    end
    while ~isempty(futures)
        [slot,result] = fetchNext(futures);
        point = points(indices(slot));
        readSeconds = readTimes(slot);
        if next<=numel(points)
            [futures(slot),readTimes(slot)] = submitPoint(pool,points(next),p,n,m,bootstrap,analyzer);
            indices(slot) = next;
            next = next+1;
        else
            futures(slot) = [];
            indices(slot) = [];
            readTimes(slot) = [];
        end
        [summary,times] = publisher(folder,p,point,result,readSeconds,summary,times);
    end
catch exception
    cancel(futures);
    rethrow(exception);
end
end

function [future,readSeconds] = submitPoint(pool,point,p,n,m,bootstrap,analyzer)
[raw,readSeconds] = loadPoint(point,n,m);
future = parfeval(pool,analyzer,1,raw,p,point,bootstrap);
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
times = [times; timingRow(point,readSeconds,result.computeSeconds,toc(exportClock))];
fprintf('Finished %d/%d CH %d | %s | accepted %d / %d | SNR %.3f | DR %.1f\n', ...
    point.vbias,point.vgain,point.channel,row.Status,row.Accepted,row.Records,row.SNR,row.HistoricalDR);
end

function [summary,times] = publishSweepPoint(folder,~,point,result,readSeconds,summary,times)
exportClock = tic;
destination = fullfile(folder,'point_grids');
if ~isfolder(destination), mkdir(destination); end
name = sprintf('snr_grid_vbias_%d_vgain_%d_ch_%d.csv',point.vbias,point.vgain,point.channel);
writetable(result.grid,fullfile(destination,name));
summary = [summary; result.grid];
times = [times; timingRow(point,readSeconds,result.computeSeconds,toc(exportClock))];
fprintf('Finished sweep Vbias %d | Vgain %d | CH %d | resolved %d / %d\n', ...
    point.vbias,point.vgain,point.channel,nnz(isfinite(result.grid.SNR)),height(result.grid));
end

function row = timingRow(point,readSeconds,computeSeconds,exportSeconds)
row = table(point.channel,point.vbias,point.vgain,readSeconds,computeSeconds,exportSeconds, ...
    'VariableNames',{'Channel','VbiasDAC','VgainDAC','ReadSeconds','ComputeSeconds','ExportSeconds'});
end

function result = sweepPoint(raw,p,point,~)
started = tic;
[centered,q] = preparePoint(raw,p);
clear raw
[taper,~] = pulseTaper(size(centered,2),q.onset,p);
prefix = p;
prefix.useLowPass = false;
prefix.useIntegrator = false;
prefix.useBoxcar = false;
diagnosticInput = diagnosticFilterBatches(centered,prefix);
scoreInput = scoreFilterBatches(centered,taper,prefix);
clear centered

cutoffs = p.sweepLowPassHz;
lengths = p.sweepBoxcarLengths;
[lengthGrid,cutoffGrid] = meshgrid(lengths,cutoffs/1e6);
shape = size(lengthGrid);
snr = nan(shape); accepted = nan(shape); scoreSample = nan(shape);
reason = strings(shape);
for i = 1:numel(cutoffs)
    b = p.sweepBLow(i,:);
    a = p.sweepALow(i,:);
    try
        d = diagnosePoint(filter(b,a,diagnosticInput,[],2),q,p);
    catch exception
        if ~strcmp(exception.identifier,'pds:coldbox:InsufficientDiagnosticReference')
            rethrow(exception);
        end
        reason(i,:) = string(exception.message);
        continue
    end
    train = d.accepted & q.training;
    evaluation = d.accepted & ~q.training;
    accepted(i,:) = nnz(d.accepted);
    if nnz(train)<=100 || nnz(evaluation)<=100
        reason(i,:) = "Too few events after quality gates.";
        continue
    end
    unboxed = filter(b,a,scoreInput,[],2);
    if p.useIntegrator
        unboxed = filter(p.bHp,p.aHp,unboxed,[],2);
    end
    referenceMean = mean(unboxed(d.beforeLate & q.training,:),1);
    for j = 1:numel(lengths)
        boxcar = [lengths(j)-1 0];
        [sample,~,valid] = locateScore(movmean(referenceMean,boxcar,2),q,taper);
        if ~valid
            reason(i,j) = "The score window is outside the flat part of the taper.";
            continue
        end
        % Include the complete history of the three scored samples. No
        % other per-record boxcar outputs enter the fit.
        first = max(1,sample-lengths(j));
        local = movmean(unboxed(:,first:sample+1),boxcar,2);
        scores = 2*mean(local(:,end-2:end),2);
        fit = pds.calibration.fitPhotoelectronPeaks(scores,train,evaluation,evaluation,0,[], ...
            ComputeDiagnostics=false);
        scoreSample(i,j) = sample;
        reason(i,j) = fit.message;
        if fit.status=="resolved", snr(i,j) = fit.fit.snr; end
    end
    clear unboxed
end
numCells = numel(snr);
status = repmat("unresolved",numCells,1);
status(isfinite(snr(:))) = "resolved";
grid = table(repmat(point.channel,numCells,1),repmat(point.vbias,numCells,1), ...
    repmat(point.vgain,numCells,1),cutoffGrid(:),lengthGrid(:),snr(:),accepted(:),scoreSample(:),status,reason(:), ...
    'VariableNames',{'Channel','VbiasDAC','VgainDAC','LowPassMHz','BoxcarLength', ...
    'SNR','Accepted','ScoreSample','Status','StatusReason'});
result = struct('grid',grid,'computeSeconds',toc(started));
end

function result = analyzePoint(raw,p,point,bootstrap)
computeClock = tic;
[n,m] = size(raw);
channel = point.channel;
offset = point.offset;
vbias = point.vbias;
vgain = point.vgain;
[centered,q] = preparePoint(raw,p);
clear raw
ids = q.ids; training = q.training; rail = q.rail; duplicate = q.duplicate;
eligible = q.eligible; pp = q.pp; polarity = q.polarity; onset = q.onset;
pre = q.pre; baseline = q.baseline; quality = q.quality;

diagnostic = diagnosticFilterBatches(centered,p);
d = diagnosePoint(diagnostic,q,p);
clear diagnostic
beforeLate = d.beforeLate; accepted = d.accepted; late = d.late;
preOffset = d.preOffset; preExcursion = d.preExcursion; preThreshold = d.preThreshold;
outOfTime = d.outOfTime; pedestalOutlier = d.pedestalOutlier;
diagnosticPeak = d.diagnosticPeak; filteredPeak = d.filteredPeak;
lateOffset = late.representativeOffsetADU;

% The late gate uses the untapered diagnostic copy. The Tukey taper is only
% part of pulse scoring, and stays flat across the prompt score window.
[taper,alpha] = pulseTaper(m,onset,p);
shaped = scoreFilterBatches(centered,taper,p);
train = accepted & training;
eval = accepted & ~training;
assert(nnz(train)>100 && nnz(eval)>100,'Too few events after pre-pulse quality gates.');
referenceMean = mean(shaped(beforeLate & training,:),1);
[scoreSample,scorePeak,validScore] = locateScore(referenceMean,q,taper);
assert(validScore,'Score window is outside the flat part of the Tukey taper.');
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

function [centered,q] = preparePoint(raw,p)
[n,m] = size(raw);
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

q = struct('ids',ids,'training',training,'rail',rail,'duplicate',duplicate, ...
    'eligible',eligible,'reference',reference,'pulseWindow',pulseWindow, ...
    'pp',pp,'polarity',polarity,'onset',onset,'pre',pre,'baseline',baseline,'quality',quality);
end

function d = diagnosePoint(diagnostic,q,p)
diagnosticMean = mean(diagnostic(q.reference,:),1);
[~,diagnosticPeak] = max(diagnosticMean(q.pulseWindow));
diagnosticPeak = q.pulseWindow(diagnosticPeak);
preOffset = median(diagnostic(:,q.pre),2);
preExcursion = max(abs(diagnostic(:,q.pre)-preOffset),[],2);
preThreshold = robustFence(preExcursion(q.reference));
pedestalOutlier = abs(preOffset-median(preOffset(q.reference))) > ...
    robustFence(abs(preOffset(q.reference)-median(preOffset(q.reference))));
outOfTime = preExcursion>preThreshold;
beforeLate = q.eligible & ~outOfTime & ~pedestalOutlier;
assert(nnz(beforeLate & q.training)>=100, ...
    'pds:coldbox:InsufficientDiagnosticReference','Too few training events before the late veto.');
late = pds.preprocess.vetLatePedestal(diagnostic,q.pre,q.pp,1/p.sampleRateHz,beforeLate & q.training, ...
    DelayUs=p.lateDelayUs,OffsetSigma=p.lateOffsetSigma,ExcursionSigma=p.lateExcursionSigma);
accepted = beforeLate & ~late.offsetVeto & ~late.excursionVeto;
filteredPeak = diagnostic(:,diagnosticPeak);
d = struct('diagnosticPeak',diagnosticPeak,'preOffset',preOffset, ...
    'preExcursion',preExcursion,'preThreshold',preThreshold, ...
    'outOfTime',outOfTime,'pedestalOutlier',pedestalOutlier,'beforeLate',beforeLate, ...
    'accepted',accepted,'late',late,'filteredPeak',filteredPeak);
end

function [taper,alpha] = pulseTaper(m,onset,p)
alpha = 0;
taper = ones(1,m);
if p.useTukey
    edge = floor((onset-1)/2);
    alpha = 2*max(0,edge)/(m-1);
    taper = pds.signal.createWindow(m,"tukey",TukeyRatio=alpha);
end
end

function [sample,peak,valid] = locateScore(referenceMean,q,taper)
search = q.onset:min(q.pp+160,numel(taper));
[peak,relativeSample] = max(referenceMean(search));
sample = search(relativeSample);
valid = isfinite(peak) && peak>0 && sample<numel(taper) && ...
    all(taper(q.onset:sample+1)==1);
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
    x = centered(rows,:);
    if p.useTukey, x = x.*window; end
    x = diagnosticBandwidth(x,p);
    if p.useIntegrator, x = filter(p.bHp,p.aHp,x,[],2); end
    if p.useBoxcar, x = movmean(x,[p.boxcarLength-1 0],2); end
    shaped(rows,:) = x;
end
end

function filtered = diagnosticBandwidth(waveforms,p)
filtered = waveforms;
if p.useNotch, filtered = filter(p.bNotch,p.aNotch,filtered,[],2); end
if p.useLowPass, filtered = filter(p.bLow,p.aLow,filtered,[],2); end
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
state = ["off","on"];
fprintf(fid,'| Stage | State | Setting | Routes |\n|---|---|---|---|\n');
fprintf(fid,'| Tukey window | %s | | SNR |\n',state(1+p.useTukey));
fprintf(fid,'| Notch | %s | %.4f MHz, Q = %g | Diagnostic, SNR, SPE |\n', ...
    state(1+p.useNotch),p.notchFrequencyHz/1e6,p.notchQ);
fprintf(fid,'| Butterworth low-pass | %s | %g MHz, order 3 | Diagnostic, SNR |\n', ...
    state(1+p.useLowPass),p.lowPassHz/1e6);
fprintf(fid,'| Reference IIR integrator | %s | | SNR |\n',state(1+p.useIntegrator));
fprintf(fid,'| Causal boxcar | %s | %d samples, including the current sample | SNR |\n\n', ...
    state(1+p.useBoxcar),p.boxcarLength);
fprintf(fid,['Odd IDs determine pulse and score windows, amplitude calibration and quality thresholds. ' ...
    'Even IDs estimate SNR and supply the centered waveforms for the 1-PE average. ' ...
    'The late gate is applied to the original event IDs before histogram fitting. ' ...
    'The comparison column uses the same score calibration after only rail and duplicate removal. ' ...
    'Bootstrap intervals condition on training and use independent evaluation record resamples.\n\n']);
fprintf(fid,['Historical DR uses %d divided by the 1-PE peak-to-peak amplitude with the notch %s. ' ...
    'ADC headroom uses the 1-PE average before filtering, the measured pedestal and %d-bit rails. ' ...
    'A linearity measurement needs saturation data. The spectral plot shows the shaped waveform ' ...
    'in the legacy normalization.\n\n'],2^p.adcBits,state(1+p.useNotch),p.adcBits);
fprintf(fid,['Each point has the Live Script layouts for the average waveform, integral histogram, ' ...
    'spectrum and 1-PE waveform, plus a diagnostic boxplot panel. Figures accompany a point MAT ' ...
    'file with event masks, estimated windows and fit diagnostics, and a separate histogram model ' ...
    'file. Reference-layout PNGs use 700 by 525 pixels. A supplemental comparison shows the ' ...
    'all-waveform averages and the 1-PE averages before and after the late veto. Histograms stay ' ...
    'in raw score ADU with per-point limits and a bin width chosen on training. The red overlay ' ...
    'includes higher PE orders supported by local maxima near the common peak spacing. SNR is ' ...
    'evaluated from a joint, bin-integrated 0- and 1-PE fit.\n\n']);
fprintf(fid,['The late ROI starts %.2f us after the raw pulse peak. ' ...
    'The diagnostic branch vetoes a block offset above %.1f robust early contrast scales ' ...
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
