function [comparison,outputFolder] = benchmarkThreads(scanRoot,shaperFile,outputRoot,scanOptions,options)
%BENCHMARKTHREADS Run the same scan in serial and through the thread pool.
% scanOptions contains the fields accepted by analyzeScan, such as Channels.
arguments
    scanRoot (1,1) string
    shaperFile (1,1) string
    outputRoot (1,1) string
    scanOptions (1,1) struct
    options.SerialFirst (1,1) logical = false
end
assert(~isfield(scanOptions,'UseParallel'),'The benchmark selects the execution mode.');
args = namedargs2cell(scanOptions);
if options.SerialFirst
    [serial,serialFolder,serialTime] = pds.coldbox.analyzeScan(scanRoot,shaperFile,outputRoot,args{:},'UseParallel',false);
    [threaded,outputFolder,threadTime] = pds.coldbox.analyzeScan( ...
        scanRoot,shaperFile,outputRoot,args{:},'UseParallel',true);
    firstMode = "serial";
else
    [threaded,outputFolder,threadTime] = pds.coldbox.analyzeScan( ...
        scanRoot,shaperFile,outputRoot,args{:},'UseParallel',true);
    [serial,serialFolder,serialTime] = pds.coldbox.analyzeScan(scanRoot,shaperFile,outputRoot,args{:},'UseParallel',false);
    firstMode = "threads";
end

assert(isequal(serial.Properties.VariableNames,threaded.Properties.VariableNames));
for name = string(serial.Properties.VariableNames)
    checkEquivalent(serial.(name),threaded.(name),name);
end
for k = 1:height(serial)
    r = serial(k,:);
    file = fullfile(sprintf('vbias_%d',r.VbiasDAC),sprintf('vgain_%d',r.VgainDAC), ...
        sprintf('channel_%d',r.Channel),'point_results.mat');
    a = load(fullfile(serialFolder,file),'events','speMean');
    b = load(fullfile(outputFolder,file),'events','speMean');
    for column = ["EventID","Accepted","SinglePECandidate","ScoreADU"]
        checkEquivalent(a.events.(column),b.events.(column),column);
    end
    checkEquivalent(a.speMean,b.speMean,"speMean");
end

comparison = [serialTime; threadTime];
comparison.SpeedupVsSerial = serialTime.WallSeconds./comparison.WallSeconds;
comparison.ProcessingSpeedupVsSerial = serialTime.ProcessingSeconds./comparison.ProcessingSeconds;
comparison.SavedPercentVsSerial = 100*(1-comparison.WallSeconds/serialTime.WallSeconds);
comparison.OutputFolder = [string(serialFolder);string(outputFolder)];
writetable(comparison,fullfile(outputFolder,'benchmark.csv'));
fid = fopen(fullfile(outputFolder,'benchmark.md'),'w');
assert(fid>=0,'Cannot write benchmark report.');
closeReport = onCleanup(@() fclose(fid));
fprintf(fid,'# ColdBox serial vs. thread benchmark\n\n');
fprintf(fid,['Both runs processed %d identical channel-points, ' ...
    'including archive reading, numerical processing, fitting, and all six figure exports per point. ' ...
    'Table values, event IDs, accepted and 1-PE masks, scores, and the notched averages agree. ' ...
    'The first mode was %s. This is one measured run per mode.\n\n'], ...
    height(serial),firstMode);
fprintf(fid,'| Mode | Workers | Pool startup [s] | Processing [s] | Total [s] | Speedup |\n');
fprintf(fid,'|:---|---:|---:|---:|---:|---:|\n');
for k=1:height(comparison)
    r = comparison(k,:);
    fprintf(fid,'| %s | %d | %.2f | %.2f | %.2f | %.3fx |\n',r.Mode,r.Workers, ...
        r.PoolStartupSeconds,r.ProcessingSeconds,r.WallSeconds,r.SpeedupVsSerial);
end
fprintf(fid,'\nMATLAB CPU-worker limit: %d. RAM-worker limit: %.0f (%.2f GiB available before opening pool).\n', ...
    threadTime.MATLABCoreLimit,threadTime.RAMWorkerLimit,threadTime.AvailableRAMGiB);
fprintf(fid,'\nSerial output: `%s`\n\nThreaded output: `%s`\n',serialFolder,outputFolder);
fprintf('Benchmark output: %s\n',outputFolder);
end

function checkEquivalent(a,b,label)
if isnumeric(a)
    assert(isequal(size(a),size(b)) && isequal(isfinite(a),isfinite(b)) && ...
        isequaln(a(~isfinite(a)),b(~isfinite(b))), 'Result mismatch: %s.',label);
    finite = isfinite(a);
    assert(all(abs(a(finite)-b(finite))<=1e-8*(1+abs(a(finite)))), ...
        'Numerical mismatch: %s.',label);
else
    assert(isequaln(a,b),'Result mismatch: %s.',label);
end
end
