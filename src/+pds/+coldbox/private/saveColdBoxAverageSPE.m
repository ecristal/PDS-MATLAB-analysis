function saveColdBoxAverageSPE(folder,row,pipeline,speMean,extrema)
%SAVECOLDBOXAVERAGESPE Render the live-script SPE layout with the notch enabled.
f = figure('Visible','off','Units','pixels','Position',[100 100 560 420], ...
    'Color','w','PaperUnits','inches','PaperPosition',[0 0 560/96 420/96]);
cleanup = onCleanup(@() close(f));
time = (0:numel(speMean)-1)*1e6/pipeline.sampleRateHz;
plot(time,speMean);
hold on;
grid on;
subtitle = sprintf('Vbias %d DAC - Vgain %d DAC - Channel %d - %.4f MHz notch', ...
    row.VbiasDAC,row.VgainDAC,row.Channel,pipeline.notchFrequencyHz/1e6);
title('Average single PE - ' + pipeline.figureTitle,subtitle);
if all(isfinite(extrema))
    yline(extrema(2),'r--');
    yline(extrema(1),'r--');
    annotation(f,'textbox',[0.5 0.7 0.1 0.1], ...
        'String',sprintf('Amplitude = %.4f',row.SinglePEPeakToPeakADU));
    annotation(f,'textbox',[0.5 0.6 0.1 0.1], ...
        'String',sprintf('Dynamic range = %.4f',row.HistoricalDR));
else
    xlim([time(1) time(end)]);
    annotation(f,'textbox',[0.5 0.6 0.1 0.1],'String','Single PE unresolved');
end
xlabel('Time [\mus]');
ylabel('ADU');
stem = fullfile(folder,sprintf('average_single_PE_ch_%d',row.Channel));
savefig(f,stem + ".fig");
print(f,stem + ".png",'-dpng','-r120');
end
