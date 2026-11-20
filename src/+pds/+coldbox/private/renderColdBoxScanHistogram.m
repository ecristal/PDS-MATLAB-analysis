function model = renderColdBoxScanHistogram(folder,row,pe,scores,figureTitle)
%RENDERCOLDBOXSCANHISTOGRAM Render the reference layout in actual score ADU.
f = figure('Visible','off','Units','pixels','Position',[100 100 560 420], ...
    'Color','w','PaperUnits','inches','PaperPosition',[0 0 560/96 420/96]);
closeFigure = onCleanup(@() close(f));
hold on;
model = struct('orders',[],'coefficient',[],'binWidth',pe.binWidthADU, ...
    'limitsADU',pe.limitsADU,'edgesADU',pe.edgesADU,'counts',[], ...
    'curveX',[],'curveY',[]);
edges = pe.edgesADU;
if isempty(edges)
    histogram(scores,'DisplayStyle','stairs','LineWidth',2);
else
    histogram(scores,'BinEdges',edges,'DisplayStyle','stairs','LineWidth',2);
    model.counts = histcounts(scores,edges);
    xlim(pe.limitsADU);
end
if pe.status == "resolved"
    fitResult = pe.fit;
    mu0 = fitResult.mu0;
    mu1 = fitResult.mu1;
    sigma0 = fitResult.sigma0;
    [model.coefficient,model.curveX,model.curveY,peakCenters,peakHeights] = ...
        fitVisibleOrderWeights(edges,model.counts,pe.binWidthADU,pe.orders,fitResult);
    model.orders = pe.orders;
    plot(peakCenters,peakHeights,'o');
    plot(model.curveX,model.curveY,'r','LineWidth',1.25);
    xline(mu0,'r--');
    xline(mu0+sigma0,'b--');
    xline(mu0-sigma0,'b--');
    xline(mu1,'r--');
    summary = sprintf('$\\Delta$ = %.4g ADU\n$\\sigma_{0}$ = %.4g ADU\nSNR = %.4g', ...
        fitResult.delta,sigma0,fitResult.snr);
else
    summary = '0 and 1 PE unresolved';
end
if ~isempty(edges)
    summary = sprintf('%s\nBin = %.3g ADU\nRange: %.2f to %.2f ADU',summary, ...
        pe.binWidthADU,pe.limitsADU);
end
annotation(f,'textbox',[0.64 0.67 0.1 0.1],'Interpreter','latex','String',summary);
subtitle = sprintf('Vbias %d DAC - Vgain %d DAC - Channel %d', ...
    row.VbiasDAC,row.VgainDAC,row.Channel);
title('Histogram of integrals - ' + figureTitle,subtitle);
ylabel('Entries');
xlabel('ADU');
grid on;
stem = fullfile(folder,sprintf('histogram_ch_%d',row.Channel));
savefig(f,stem + ".fig");
print(f,stem + ".png",'-dpng','-r120');
save(fullfile(folder,'histogram_model.mat'),'model');
end

function [weights,curveX,curveY,peakCenters,peakHeights] = ...
    fitVisibleOrderWeights(edges,counts,h,orders,result)
% Preserve the 0/1 PE calibration for the multi-PE display overlay.
mu = result.mu0+orders*result.delta;
sigma = sqrt(result.sigma0^2+orders*max(result.sigma1^2-result.sigma0^2,0));
sigma(2) = result.sigma1;
cdf = @(u) 0.5*(1+erf((u(:)-mu)./(sqrt(2)*sigma)));
basis = [diff(edges(:))/h diff(cdf(edges),1,1)];
scale = 1./sqrt(max(counts(:),8));
weights = lsqnonneg(scale.*basis,scale.*counts(:));
curveX = linspace(edges(1),edges(end),1000);
evaluate = @(u) [ones(numel(u),1) (cdf(u+h/2)-cdf(u-h/2))]*weights;
curveY = evaluate(curveX);
% Mark actual bin maxima close to the predicted locations.
observed = edges(1:end-1)+diff(edges)/2;
peakCenters = nan(size(mu));
peakHeights = peakCenters;
for k = 1:numel(mu)
    nearby = find(abs(observed-mu(k))<=0.25*result.delta);
    if isempty(nearby), continue; end
    [peakHeights(k),j] = max(counts(nearby));
    peakCenters(k) = observed(nearby(j));
end
end
