function outputFolder = plotScanSummary(runFolder,options)
%PLOTSCANSUMMARY Export scan curves from the saved summary table.
arguments
    runFolder (1,1) string
    options.Campaign (1,1) string = ""
    options.Module (1,1) string = ""
    options.OnlySNRvsSPE (1,1) logical = false
end
data = readtable(fullfile(runFolder,'summary.csv'),TextType='string');
keys = {'Channel','VbiasDAC','VgainDAC'};
assert(height(unique(data(:,keys)))==height(data),'Duplicate scan coordinates in summary.csv.');
bias = unique(data.VbiasDAC).';
gain = unique(data.VgainDAC).';
channels = unique(data.Channel).';
assert(~isempty(channels),'The scan summary is empty.');
metadata = struct('campaign',"ColdBox November 2026", ...
    'module',scanModuleName(runFolder),'adcBits',14);
pipelineFile = fullfile(runFolder,'pipeline.mat');
speLabel = "Notch-filtered 1-PE average";
if isfile(pipelineFile)
    saved = load(pipelineFile,'pipeline');
    for name = ["campaign","module","adcBits"]
        if isfield(saved.pipeline,name)
            metadata.(name) = saved.pipeline.(name);
        end
    end
    if ~scanUsesNotch(saved.pipeline)
        speLabel = "1-PE average (notch off)";
    end
end
if strlength(options.Campaign)>0, metadata.campaign = options.Campaign; end
if strlength(options.Module)>0, metadata.module = options.Module; end
figureTitle = metadata.campaign + " - Module " + metadata.module;
fullScaleADU = 2^metadata.adcBits;

data = sortrows(data,keys);
valid = data.Status=="resolved" & isfinite(data.SNR);
assert(any(valid),'There are no resolved points to plot.');
assert(all(isfinite(data.HistoricalDR(valid)) & data.HistoricalDR(valid)>0 & ...
    isfinite(data.SinglePEPeakToPeakADU(valid)) & data.SinglePEPeakToPeakADU(valid)>0), ...
    'Resolved scan points must have positive DR and SPE amplitude.');
data.SNR(~valid) = NaN;
data.HistoricalDR(~valid) = NaN;
data.SinglePEPeakToPeakADU(~valid) = NaN;

outputFolder = fullfile(runFolder,'scan_figures');
if ~isfolder(outputFolder), mkdir(outputFolder); end
snrGuide = 4;
drGuide = 1500;
snrRange = [floor(min(snrGuide,min(data.SNR(valid)))),ceil(max(snrGuide,max(data.SNR(valid))))];
drRange = [min(drGuide,min(data.HistoricalDR(valid)))/1.15, ...
           max(drGuide,max(data.HistoricalDR(valid)))*1.15];
gainRange = [min(gain)-50,max(gain)+50];
yAmp = max(data.SinglePEPeakToPeakADU(valid));
ampRange = [0,max(20,20*ceil(yAmp/20))];
colors = [0.000 0.447 0.741; 0.850 0.325 0.098; 0.900 0.630 0.000; ...
          0.494 0.184 0.556; 0.340 0.600 0.160; 0.200 0.690 0.880; ...
          0.750 0.090 0.215; 0.075 0.160 0.420];
if numel(bias)>size(colors,1), colors = turbo(numel(bias)); end
names = string(bias);

amplitudeGuide = fullScaleADU/drGuide;
plotSNRvsSPEAmplitude(data,gain,bias,channels,colors,names,snrRange,snrGuide,amplitudeGuide, ...
    outputFolder,figureTitle + " - " + speLabel,metadata.module);
if options.OnlySNRvsSPE
    writeFigureNotes(runFolder,outputFolder,data,valid,channels,snrGuide,drGuide,amplitudeGuide, ...
        figureTitle,fullScaleADU,speLabel);
    fprintf('Scan figures: %s\n',outputFolder);
    return
end

for index = 1:numel(channels)
    channel = channels(index);
    subset = data(data.Channel==channel,:);
    channelTitle = sprintf('%s CH%d (DAPHNE CH%d)',figureTitle,index,channel);

    f = newFigure(935,745);
    closeFigure = onCleanup(@() close(f));
    ax = axes(f,'Position',[0.105 0.122 0.866 0.747]);
    styleAxes(ax);
    lines = plotCurves(ax,subset,gain,bias,colors,"VgainDAC","SNR");
    xlim(ax,gainRange);
    xticks(ax,gain(1:2:end));
    ylim(ax,snrRange);
    xlabel(ax,'VGAIN (DAC)','FontName','Times New Roman','FontSize',24);
    ylabel(ax,'SNR','FontName','Times New Roman','FontSize',24);
    title(ax,{'SNR vs VGAIN (DAC)',channelTitle},'FontName','Times New Roman', ...
        'FontWeight','normal','FontSize',24);
    addSNRGuide(ax,snrGuide);
    biasLegend(ax,lines,names);
    exportFigure(f,outputFolder,sprintf('snr_vs_vgain_ch_%d',channel));
    clear closeFigure

    f = newFigure(935,745);
    closeFigure = onCleanup(@() close(f));
    ax = axes(f,'Position',[0.105 0.122 0.866 0.747]);
    styleAxes(ax);
    lines = plotCurves(ax,subset,gain,bias,colors,"HistoricalDR","SNR");
    ax.XScale = 'log';
    ax.XMinorGrid = 'on';
    ax.MinorGridAlpha = 0.14;
    xlim(ax,drRange);
    marks = [100 150 200 300 500 750 1000 1500 2500 4000 6000 10000];
    marks = marks(marks>=drRange(1) & marks<=drRange(2));
    xticks(ax,marks);
    xticklabels(ax,string(marks));
    ylim(ax,snrRange);
    xlabel(ax,'P.E. equivalent','FontName','Times New Roman','FontSize',24);
    ylabel(ax,'SNR','FontName','Times New Roman','FontSize',24);
    title(ax,{'SNR vs Dynamic Range (ADC)',channelTitle},'FontName','Times New Roman', ...
        'FontWeight','normal','FontSize',24);
    addSNRGuide(ax,snrGuide);
    red = [0.86 0.07 0.1];
    xline(ax,drGuide,'--','Color',red,'LineWidth',1,'HandleVisibility','off');
    text(ax,drGuide/1.024,snrRange(1)+0.035*diff(snrRange),'1500 P.E.', ...
        'Color',red,'FontSize',16,'Rotation',90,'VerticalAlignment','bottom','HandleVisibility','off');
    biasLegend(ax,lines,names);
    exportFigure(f,outputFolder,sprintf('snr_vs_dynamic_range_ch_%d',channel));
    clear closeFigure
end

f = newFigure(1240,650);
closeFigure = onCleanup(@() close(f));
layout = tiledlayout(f,1,numel(channels),'TileSpacing','compact','Padding','compact');
title(layout,{'SPE Peak-to-Peak Amplitude vs VGAIN (DAC)', ...
    char(figureTitle + " - " + speLabel)}, ...
    'FontName','Times New Roman','FontWeight','normal','FontSize',24);
for index = 1:numel(channels)
    channel = channels(index);
    ax = nexttile(layout);
    styleAxes(ax);
    lines = plotCurves(ax,data(data.Channel==channel,:),gain,bias,colors, ...
        "VgainDAC","SinglePEPeakToPeakADU");
    xlim(ax,gainRange);
    ylim(ax,ampRange);
    xticks(ax,gain(1:4:end));
    title(ax,sprintf('%s CH%d (DAPHNE CH%d)',metadata.module,index,channel), ...
        'FontName','Times New Roman','FontWeight','normal','FontSize',22);
    xlabel(ax,'VGAIN (DAC)','FontName','Times New Roman','FontSize',22);
    if index==1
        ylabel(ax,'SPE peak-to-peak amplitude (ADU)','FontName','Times New Roman','FontSize',20);
        sharedBiasLegend(ax,lines,names);
    end
end
exportFigure(f,outputFolder,'spe_peak_to_peak_vs_vgain_' + metadata.module);
clear closeFigure

writeFigureNotes(runFolder,outputFolder,data,valid,channels,snrGuide,drGuide,amplitudeGuide, ...
    figureTitle,fullScaleADU,speLabel);
fprintf('Scan figures: %s\n',outputFolder);
end

function writeFigureNotes(runFolder,outputFolder,data,valid,channels,snrGuide,drGuide,amplitudeGuide, ...
    figureTitle,fullScaleADU,speLabel)
fid = fopen(fullfile(outputFolder,'figure_notes.md'),'w');
assert(fid>=0,'Cannot write figure notes.');
note = onCleanup(@() fclose(fid));
fprintf(fid,'# %s - Scan figures\n\n',figureTitle);
fprintf(fid,'Source: `%s` (`summary.csv`).\n\n',runFolder);
fprintf(fid,['Each curve corresponds to a recorded Vbias DAC setting. ' ...
    'The source records DAC codes, so the legend displays Vbias in DAC. ' ...
    'Resolved measurements are connected in Vgain order; unresolved points leave gaps.\n\n']);
fprintf(fid,['Dynamic range is the historical ADC extrapolation (%d divided by the ' ...
    'peak-to-peak amplitude of the %s), in PE equivalents, and is plotted ' ...
    'on a log axis. The vertical guide at 1500 PE denotes that metric. The separate ' ...
    'ADCHeadroomPE column is based on the raw ADC waveform.\n\n'],fullScaleADU,speLabel);
fprintf(fid,['The SNR vs SPE-amplitude figure uses a logarithmic amplitude axis. ' ...
    'Its red guide at %.2f ADU is the amplitude corresponding to %d PE of historical DR.\n\n'], ...
    amplitudeGuide,drGuide);
fprintf(fid,'| DAPHNE channel | Resolved / acquired | SNR >= 4 and historical DR >= 1500 PE |\n');
fprintf(fid,'|---:|---:|---:|\n');
for channel = channels
    onChannel = data.Channel==channel;
    meetsBoth = onChannel & data.SNR>=snrGuide & data.HistoricalDR>=drGuide;
    fprintf(fid,'| %d | %d / %d | %d |\n',channel,nnz(valid & onChannel),nnz(onChannel),nnz(meetsBoth));
end
end

function plotSNRvsSPEAmplitude(data,gain,bias,channels,colors,names,snrRange,snrGuide,ampGuide,folder,subtitle,module)
f = newFigure(1240,650);
closeFigure = onCleanup(@() close(f));
layout = tiledlayout(f,1,numel(channels),'TileSpacing','compact','Padding','compact');
title(layout,{'SNR vs SPE Peak-to-Peak Amplitude',char(subtitle)}, ...
    'FontName','Times New Roman','FontWeight','normal','FontSize',24);
amp = data.SinglePEPeakToPeakADU(isfinite(data.SinglePEPeakToPeakADU));
xx = [min([amp; ampGuide])/1.15,max([amp; ampGuide])*1.15];
ticks = [1 2 3 5 7 10 15 20 30 50 75 100 150 200];
ticks = ticks(ticks>=xx(1) & ticks<=xx(2));
red = [0.86 0.07 0.1];
for index = 1:numel(channels)
    channel = channels(index);
    ax = nexttile(layout);
    styleAxes(ax);
    lines = plotCurves(ax,data(data.Channel==channel,:),gain,bias,colors, ...
        "SinglePEPeakToPeakADU","SNR");
    ax.XScale = 'log';
    ax.XMinorGrid = 'on';
    ax.MinorGridAlpha = 0.14;
    xlim(ax,xx);
    xticks(ax,ticks);
    xticklabels(ax,string(ticks));
    ylim(ax,snrRange);
    addSNRGuide(ax,snrGuide,"right");
    xline(ax,ampGuide,'--','Color',red,'LineWidth',1,'HandleVisibility','off');
    text(ax,ampGuide/1.025,snrRange(2)-0.035*diff(snrRange), ...
        sprintf('%.2f ADU',ampGuide),'Color',red,'FontSize',15,'Rotation',90, ...
        'VerticalAlignment','bottom','HorizontalAlignment','right','HandleVisibility','off');
    title(ax,sprintf('%s CH%d (DAPHNE CH%d)',module,index,channel), ...
        'FontName','Times New Roman','FontWeight','normal','FontSize',22);
    xlabel(ax,'SPE peak-to-peak amplitude (ADU)','FontName','Times New Roman','FontSize',21);
    if index==1
        ylabel(ax,'SNR','FontName','Times New Roman','FontSize',22);
        sharedBiasLegend(ax,lines,names);
    end
end
exportFigure(f,folder,'snr_vs_spe_peak_to_peak_' + module);
end

function sharedBiasLegend(ax,lines,names)
leg = legend(ax,lines,names,'Orientation','horizontal','NumColumns',numel(names), ...
    'FontSize',14,'Box','on');
leg.Title.String = 'Vbias (DAC)';
leg.Title.FontWeight = 'bold';
leg.Layout.Tile = 'south';
end

function lines = plotCurves(ax,data,gain,bias,colors,xField,yField)
lines = gobjects(1,numel(bias));
for k = 1:numel(bias)
    group = data(data.VbiasDAC==bias(k),:);
    [present,idx] = ismember(gain,group.VgainDAC);
    x = nan(size(gain));
    y = nan(size(gain));
    x(present) = group.(xField)(idx(present));
    y(present) = group.(yField)(idx(present));
    lines(k) = plot(ax,x,y,'Color',colors(k,:),'LineWidth',1.25, ...
        'Marker','.','MarkerSize',9);
end
end

function styleAxes(ax)
hold(ax,'on');
grid(ax,'on');
set(ax,'FontName','Arial','FontSize',17,'LineWidth',1, ...
    'TickDir','in','Box','on','GridAlpha',0.19,'Layer','top');
end

function addSNRGuide(ax,level,side)
if nargin<3, side = "left"; end
blue = [0.10 0.18 0.99];
yline(ax,level,'--','Color',blue,'LineWidth',1,'HandleVisibility','off');
xx = xlim(ax);
yy = ylim(ax);
fraction = 0.028;
if side=="right", fraction = 1-fraction; end
if ax.XScale=="log"
    labelX = xx(1)*(xx(2)/xx(1))^fraction;
else
    labelX = xx(1)+fraction*diff(xx);
end
text(ax,labelX,level-0.03*diff(yy),'SNR 4','Color',blue,'FontSize',18, ...
    'HorizontalAlignment',side,'VerticalAlignment','middle','HandleVisibility','off');
end

function biasLegend(ax,lines,names)
lg = legend(ax,lines,names,'Location','northeast','Box','on','FontSize',16);
lg.Title.String = 'Vbias (DAC)';
lg.Title.FontWeight = 'bold';
end

function f = newFigure(width,height)
f = figure('Visible','off','Units','pixels','Position',[100 100 width height], ...
    'Color','w','PaperUnits','inches','PaperPosition',[0 0 width/96 height/96]);
end

function exportFigure(f,folder,name)
stem = fullfile(folder,name);
savefig(f,stem+".fig");
print(f,stem+".png",'-dpng','-r144');
end
