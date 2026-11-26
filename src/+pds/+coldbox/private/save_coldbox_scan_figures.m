function save_coldbox_scan_figures(folder,r,t,p,pe,scores,rawMean,shapedMean, ...
    speMean,extrema,spectrum,boxplotInputs)
%SAVE_COLDBOX_SCAN_FIGURES Reproduce the scan Live Script figure layouts.
id = char(p.figureTitle);
subtitle = sprintf('Vbias %d DAC - Vgain %d DAC - Channel %d', ...
    r.VbiasDAC,r.VgainDAC,r.Channel);
time = (0:numel(rawMean)-1)/p.sampleRateHz*1e6;
suffix = sprintf('_ch_%d',r.Channel);

f = newFigure();
closeFigure = onCleanup(@() close(f));
plot(time,rawMean);
hold on;
plot(time,shapedMean);
xline(time(t.scoreSample),'b--');
grid on;
title({['Average waveform - ' id],subtitle},'Interpreter','latex','FontSize',14);
xlabel('$\mu$s','Interpreter','latex','FontSize',12);
ylabel('ADU','Interpreter','latex','FontSize',12);
legend('Average signal','Waveform used for scoring','Interpreter','latex','FontSize',10);
saveFigure(f,folder,['average_PE' suffix]);
clear closeFigure

renderColdBoxScanHistogram(folder,r,pe,scores,p.figureTitle);

f = newFigure();
closeFigure = onCleanup(@() close(f));
frequencyHz = (1:numel(spectrum)-1)*p.sampleRateHz/numel(rawMean);
amplitude = struct('frequencyHz',frequencyHz,'amplitudeMean',spectrum(2:end),'inputUnit',"ADU");
ax = axes(f);
pds.plotting.plotSpectrum(amplitude,Axes=ax,Scale="decibel", ...
    ReferenceValue=2^p.adcBits,ReferenceLabel="dBFS",FrequencyUnit="MHz");
ax.XScale = 'log';
title(['Average signal spectrum - ' id],subtitle);
xlabel('Frequency (MHz)');
ylabel('dBFS');
saveFigure(f,folder,['average_spectrum' suffix]);
clear closeFigure

saveColdBoxAverageSPE(folder,r,p,speMean,extrema);

f = newFigure();
closeFigure = onCleanup(@() close(f));
layout = tiledlayout(f,1,3);
labels = ["Diagnostic pulse peak","Early pedestal","Late pedestal"];
for k = 1:3
    nexttile(layout);
    values = boxplotInputs(:,k);
    if any(isfinite(values))
        boxchart(values);
        ylabel('ADU');
        grid on;
        xticks([]);
    else
        axis off;
        text(0.5,0.5,'No stable late window','HorizontalAlignment','center');
    end
    title(labels(k));
end
title(layout,'Pulse and pedestal quality',subtitle);
saveFigure(f,folder,['quality_boxplots' suffix]);
end

function f = newFigure()
f = figure('Visible','off','Units','pixels','Position',[100 100 560 420], ...
    'Color','w','PaperUnits','inches','PaperPosition',[0 0 560/96 420/96]);
end

function saveFigure(f,folder,stem)
savefig(f,fullfile(folder,[stem '.fig']));
print(f,fullfile(folder,[stem '.png']),'-dpng','-r120');
end
