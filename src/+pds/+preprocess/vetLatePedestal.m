function late = vetLatePedestal(diagnostic,pre,rawPeak,samplePeriod,reference,options)
%VETLATEPEDESTAL Apply the pre-trigger noise scale to the late baseline.
% Rows are events. Pre and rawPeak are sample indices. Reference selects
% events used to learn the thresholds in the diagnostic input units.
arguments
    diagnostic (:,:) double
    pre (1,:) double
    rawPeak (1,1) double
    samplePeriod (1,1) double {mustBePositive}
    reference (:,1) logical
    options.BlockSamples (1,1) double {mustBeInteger,mustBePositive} = 64
    options.DelayUs (1,1) double {mustBePositive} = 5.12
    options.OffsetSigma (1,1) double {mustBePositive} = 4
    options.ExcursionSigma (1,1) double {mustBePositive} = 6
end
assert(numel(reference)==size(diagnostic,1),'The reference mask must match the event count.');
assert(nnz(reference)>=100 && numel(pre)>=80,'Late gate needs a clean pre-trigger training reference.');
n = size(diagnostic,2);
start = rawPeak+round(options.DelayUs*1e-6/samplePeriod);
blockCount = floor((n-start+1)/options.BlockSamples);
assert(blockCount>=3,'The record needs at least three late pedestal blocks after the guard interval.');

preFiltered = diagnostic(:,pre);
baseline = median(preFiltered,2);
preResidual = preFiltered-baseline;
% A disjoint early block contrast estimates the fluctuation of one nearly
% constant block against the pre-trigger reference. A pooled robust sample
% scale in the same filtered domain sets the transient threshold.
half = floor(numel(pre)/2);
contrast = mean(preFiltered(:,half+1:end),2)-mean(preFiltered(:,1:half),2);
offsetScale = robustSigma(contrast(reference));
excursionScale = robustSigma(preResidual(reference,:));
offsetLimit = max(0.6,options.OffsetSigma*offsetScale);
excursionLimit = max(2,options.ExcursionSigma*excursionScale);

bounds = round(linspace(start,n+1,blockCount+1));
levels = zeros(size(diagnostic,1),blockCount);
for k = 1:blockCount
    levels(:,k) = mean(diagnostic(:,bounds(k):bounds(k+1)-1),2)-baseline;
end
late = struct('start',start,'bounds',bounds,'blockOffsetADU',levels, ...
    'representativeOffsetADU',median(levels,2), ...
    'maxBlockOffsetADU',max(abs(levels),[],2), ...
    'maxExcursionADU',max(abs(diagnostic(:,start:end)-baseline),[],2), ...
    'offsetLimitADU',offsetLimit,'excursionLimitADU',excursionLimit, ...
    'offsetScaleADU',offsetScale,'excursionScaleADU',excursionScale);
late.offsetVeto = late.maxBlockOffsetADU>offsetLimit;
late.excursionVeto = late.maxExcursionADU>excursionLimit;
end

function scale = robustSigma(values)
values = values(:);
scale = 1.4826*median(abs(values-median(values)));
end
