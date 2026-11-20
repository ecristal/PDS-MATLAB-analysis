function saveColdBoxLatePedestalComparison(folder,row,timing,pipeline,audit)
%SAVECOLDBOXLATEPEDESTALCOMPARISON Show matched populations before and after the late veto.
f = figure('Visible','off','Units','pixels','Position',[100 100 720 550], ...
    'Color','w','PaperPositionMode','auto');
cleanup = onCleanup(@() close(f));
layout = tiledlayout(f,2,1,'TileSpacing','compact');
t = (0:numel(audit.beforeMean)-1)*1e6/pipeline.sampleRateHz;
start = t(timing.lateOnset);
titles = ["Average waveform","Average single PE with common PE window and notch"];
before = [audit.beforeMean; filter(pipeline.bNotch,pipeline.aNotch,audit.beforeMatchedSPE)];
after = [audit.afterMean; filter(pipeline.bNotch,pipeline.aNotch,audit.afterMatchedSPE)];
for i = 1:2
    ax = nexttile(layout);
    plot(ax,t,before(i,:));
    hold(ax,'on');
    plot(ax,t,after(i,:));
    xline(ax,start,'k--','Late veto starts','LabelVerticalAlignment','bottom', ...
        'HandleVisibility','off');
    yline(ax,0,':','HandleVisibility','off');
    title(ax,titles(i));
    ylabel(ax,'ADU');
    grid(ax,'on');
    xlim(ax,[t(1) t(end)]);
    legend(ax,'Before late veto','After late veto','Location','best');
end
xlabel(layout,'Time [\mus]');
title(layout,'Late pedestal stability', ...
    sprintf('%s - Vbias %d DAC - Vgain %d DAC - Channel %d', ...
    pipeline.figureTitle,row.VbiasDAC,row.VgainDAC,row.Channel));
stem = fullfile(folder,sprintf('late_pedestal_comparison_ch_%d',row.Channel));
savefig(f,stem + ".fig");
saveas(f,stem + ".png");
end
