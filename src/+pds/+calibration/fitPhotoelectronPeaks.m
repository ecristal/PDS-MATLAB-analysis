function result = fitPhotoelectronPeaks(scores,train,evaluation,minimalVeto,bootstrapCount,stream,options)
%FITPHOTOELECTRONPEAKS Fit the pedestal and first PE in independent records.
% Scores are one scalar per event. Train, evaluation and minimalVeto are
% logical masks on those same events. Only train determines discovery, bin
% limits and bin width. Fits and bootstrap on evaluation use that grid.
% ComputeDiagnostics controls the extra evaluation bins and veto comparison.
arguments
    scores (:,1) double {mustBeReal,mustBeFinite}
    train (:,1) logical
    evaluation (:,1) logical
    minimalVeto (:,1) logical = evaluation
    bootstrapCount (1,1) double {mustBeInteger,mustBeNonnegative} = 0
    stream = []
    options.ComputeDiagnostics (1,1) logical = true
end
assert(all([numel(train),numel(evaluation),numel(minimalVeto)]==numel(scores)), ...
    'Fit masks must match the number of scores.');
assert(~any(train & (evaluation | minimalVeto)), ...
    'Training events must be disjoint from evaluation and minimal veto events.');
x = scores(train);
q = prctile(x,[0.25 25 75 99.5]);
fd = 2*(q(3)-q(2))/nthroot(numel(x),3);
result = struct('status',"unresolved",'message',"",'trainingFit',[], ...
    'fit',[],'minimalVetoSNR',NaN,'discoverySupport',0,'orders',[], ...
    'limitsADU',q([1 4]),'edgesADU',[],'binWidthADU',NaN,'binning',table());
if ~isfinite(fd) || fd<=0
    result.message = "Training scores have no usable spread.";
    return
end
result.binWidthADU = 0.75*fd;
result.edgesADU = binEdges(result.limitsADU,result.binWidthADU,0);

[cal,orders,support] = discoverPEComb(x,q([1 4]),fd);
result.discoverySupport = support;
if isempty(cal)
    result.message = "No stable pedestal and first PE across discovery histograms.";
    return
end
result.orders = orders;
result.limitsADU = chooseLimits(x,cal,orders,fd);
result.edgesADU = binEdges(result.limitsADU,result.binWidthADU,cal.offset);

% Probe three widths at two phases. Stability, then proximity to the middle
% width, decides the binning solely from training, with no reward for high SNR.
multipliers = [0.055 0.075 0.100];
widths = cal.scale*repelem(multipliers,2);
phases = repmat([0 0.5],1,numel(multipliers));
snrTrain = nan(size(widths));
fits = cell(size(widths));
grids = fits;
for k = 1:numel(widths)
    grids{k} = binEdges(result.limitsADU,widths(k),cal.offset+phases(k)*widths(k));
    fits{k} = fitPair(x,cal,grids{k},widths(k));
    if fits{k}.valid, snrTrain(k) = fits{k}.snr; end
end
result.binning = table(widths(:),phases(:),snrTrain(:), ...
    'VariableNames',{'WidthADU','Phase','TrainingSNR'});
pairs = reshape(snrTrain,2,[]);
phaseChange = abs(diff(pairs,1,1))./mean(pairs,1);
stableWidths = all(isfinite(pairs),1) & phaseChange<=0.12;
if nnz(stableWidths)<2
    result.message = "Peak fits were not stable for two bin widths at both origins.";
    return
end
consensus = median(pairs(:,stableWidths),'all');
withinConsensus = abs(mean(pairs,1)-consensus)<=0.12*consensus;
candidates = find(stableWidths & withinConsensus);
if numel(candidates)<2
    result.message = "Bin widths disagreed on pedestal width or PE spacing.";
    return
end
% Prefer the intermediate width when several widths agree. Among its two
% phases, take the one closest to the training consensus.
[~,rank] = min(abs(multipliers(candidates)-0.075));
first = 2*candidates(rank)-1;
[~,choice] = min(abs(snrTrain(first:first+1)-consensus));
k = first+choice-1;
result.binWidthADU = widths(k);
result.edgesADU = grids{k};
result.trainingFit = fits{k};
result.binning.Selected = (1:height(result.binning)).'==k;

y = scores(evaluation);
result.fit = fitPair(y,cal,result.edgesADU,result.binWidthADU);
if options.ComputeDiagnostics
    evalSNR = nan(size(widths));
    for j = find(isfinite(snrTrain))
        fitResult = fitPair(y,cal,grids{j},widths(j));
        if fitResult.valid, evalSNR(j) = fitResult.snr; end
    end
    result.binning.EvaluationSNR = evalSNR(:);
end
if ~result.fit.valid
    result.message = "Independent evaluation did not pass the 0/1 PE fit checks.";
    return
end
result.status = "resolved";
if bootstrapCount>0
    if isempty(stream)
        stream = RandStream.getGlobalStream();
    end
    result.fit.snrCI95 = bootstrapSNR(y,cal,result.edgesADU,result.binWidthADU,bootstrapCount,stream);
end
if options.ComputeDiagnostics
    benchmark = fitPair(scores(minimalVeto),cal,result.edgesADU,result.binWidthADU);
    if benchmark.valid, result.minimalVetoSNR = benchmark.snr; end
end
end

function [cal,orders,support] = discoverPEComb(x,limits,fd)
cal = []; orders = []; support = 0;
lines = nan(6,2);
lastOrder = zeros(6,1);
i = 0;
for h = fd*[0.50 0.65 0.80]
    for phase = [0 0.5]
        i = i+1;
        e = binEdges(limits,h,phase*h);
        centers = edgesToCenters(e);
        counts = conv(histcounts(x,e),[0.05 0.244 0.412 0.244 0.05],'same');
        [~,idx] = findpeaks(counts,'MinPeakDistance',3, ...
            'MinPeakProminence',max(5,0.05*max(counts)));
        if numel(idx)<2, continue; end
        [~,zero] = min(abs(centers(idx)));
        a = idx(zero);
        if abs(centers(a))>3*h, continue; end
        for j = zero+1:numel(idx)
            b = idx(j);
            gap = centers(b)-centers(a);
            lowestPeak = min(counts([a b]));
            if gap < 3*h || min(counts(a:b)) > 0.88*lowestPeak, continue; end
            peaks = centers([a b]);
            for n = 2:numel(idx)
                next = peaks(1)+n*gap;
                idxRight = idx(idx>b);
                [difference,k] = min(abs(centers(idxRight)-next));
                if isempty(k) || difference>0.29*gap, break; end
                b = idxRight(k);
                peaks(end+1) = centers(b); %#ok<AGROW>
                line = polyfit(0:numel(peaks)-1,peaks,1);
                gap = line(1);
            end
            lines(i,:) = polyfit(0:numel(peaks)-1,peaks,1);
            lastOrder(i) = numel(peaks)-1;
            break
        end
    end
end
[best,seed] = max(lastOrder);
if best<1, return; end
matching = abs(lines(:,1)-lines(seed,1))<=0.22*lines(seed,1) & ...
    abs(lines(:,2)-lines(seed,2))<=0.30*lines(seed,1);
support = nnz(matching);
if support<3, return; end
cal = struct('offset',median(lines(matching,2)),'scale',median(lines(matching,1)));
% Higher orders must appear at least twice, at comparable spacing.
n = sort(lastOrder(matching),'descend');
orders = 0:n(2);
end

function limits = chooseLimits(x,cal,orders,fd)
left = cal.offset-0.8*cal.scale;
% Look for the valley between the last supported order and its successor.
target = cal.offset+(orders(end)+0.5)*cal.scale;
h = min(0.075*cal.scale,0.55*fd);
edges = binEdges([target-0.32*cal.scale,target+0.32*cal.scale],h,cal.offset);
counts = conv(histcounts(x,edges),[0.25 0.5 0.25],'same');
centers = edgesToCenters(edges);
inValley = find(abs(centers-target)<=0.13*cal.scale);
if isempty(inValley)
    right = target;
else
    [~,idx] = min(counts(inValley));
    right = centers(inValley(idx));
end
limits = [left right];
end

function fitResult = fitPair(scores,cal,edges,widthADU)
fitResult = struct('valid',false,'calibration',cal,'mu0',NaN,'mu1',NaN, ...
    'sigma0',NaN,'sigma1',NaN,'delta',NaN,'snr',NaN,'snrCI95',[NaN NaN], ...
    'rSquare',NaN,'population0',NaN,'population1',NaN);
counts = histcounts(scores,edges);
x = (edgesToCenters(edges)-cal.offset)/cal.scale;
h = widthADU/cal.scale;
use = x>=-0.65 & x<=1.43 & abs(diff(edges)-widthADU)<1e-6*widthADU;
if nnz(use)<14 || sum(counts(use))<150, return; end

persistent model
if isempty(model)
    model = fittype(@(a0,m0,s0,a1,m1,s1,b,h,x) ...
        a0*gaussianBin(x,m0,s0,h)+a1*gaussianBin(x,m1,s1,h)+b, ...
        'independent','x','problem','h', ...
        'coefficients',{'a0','m0','s0','a1','m1','s1','b'});
end
n0 = sum(counts(use & abs(x)<0.38));
n1 = sum(counts(use & abs(x-1)<0.38));
[fitModel,g] = fit(x(use).',counts(use).',model,'problem',h, ...
    'StartPoint',[n0,0,0.19,n1,1,0.21,0], ...
    'Lower',[0,-0.24,0.035,0,0.76,0.035,0], ...
    'Upper',[Inf,0.24,0.46,Inf,1.24,0.48,Inf], ...
    'Display','Off');
fitResult.mu0 = cal.offset+cal.scale*fitModel.m0;
fitResult.mu1 = cal.offset+cal.scale*fitModel.m1;
fitResult.sigma0 = cal.scale*fitModel.s0;
fitResult.sigma1 = cal.scale*fitModel.s1;
fitResult.delta = fitResult.mu1-fitResult.mu0;
fitResult.snr = fitResult.delta/fitResult.sigma0;
fitResult.rSquare = g.rsquare;
fitResult.population0 = fitModel.a0;
fitResult.population1 = fitModel.a1;
gap = fitModel.m1-fitModel.m0;
fitResult.valid = g.rsquare>=0.90 && gap>=0.78 && gap<=1.22 && ...
    fitModel.s0<0.39 && fitModel.s1<0.42 && min(fitModel.a0,fitModel.a1)>=50;
end

function mass = gaussianBin(x,center,sigma,h)
mass = 0.5*(erf((x+h/2-center)/(sqrt(2)*sigma))- ...
    erf((x-h/2-center)/(sqrt(2)*sigma)));
end

function ci = bootstrapSNR(scores,cal,edges,width,n,stream)
snr = nan(n,1);
for k = 1:n
    fitResult = fitPair(scores(randi(stream,numel(scores),numel(scores),1)),cal,edges,width);
    snr(k) = fitResult.snr;
end
ci = [NaN NaN];
if nnz(isfinite(snr))>=0.9*n
    ci = prctile(snr(isfinite(snr)),[2.5 97.5]);
end
end

function centers = edgesToCenters(edges)
centers = edges(1:end-1)+diff(edges)/2;
end

function edges = binEdges(limits,h,origin)
inside = origin+h*(ceil((limits(1)-origin)/h):floor((limits(2)-origin)/h));
inside = inside(inside>limits(1)+h*1e-6 & inside<limits(2)-h*1e-6);
edges = [limits(1) inside limits(2)];
end
