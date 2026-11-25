function results = compareElectronicNoise(folders,outputFolder,options)
%COMPAREELECTRONICNOISE Export comparable amplitude spectra from DAPHNE captures.
% Each folder contains config.txt and channel archives. Longer records are
% divided into equal, nonoverlapping segments. FFT magnitudes are averaged
% in linear units before conversion to dBFS. Mean removal is per segment.
arguments
    folders (1,:) string {mustBeNonempty}
    outputFolder (1,1) string
    options.Labels (1,:) string = folders
    options.Channels (1,:) double {mustBeInteger,mustBeNonnegative} = 8:11
    options.ChannelTitles (1,:) string = strings(1,0)
    options.Subtitle (1,1) string = ""
    options.RoiMHz (1,1) double = NaN
    options.SegmentLength (1,1) double {mustBeInteger,mustBeNonnegative} = 0
    options.SamplePeriod (1,1) double {mustBePositive,mustBeFinite} = 16e-9
    options.AdcBits (1,1) double {mustBeInteger,mustBePositive} = 14
end
assert(numel(folders)>=2 && numel(options.Labels)==numel(folders), ...
    'Provide at least two captures and one label per capture.');
channels = options.Channels;
channelTitles = options.ChannelTitles;
if isempty(channelTitles)
    channelTitles = "DAPHNE CH "+string(channels);
end
assert(~isempty(channels) && numel(unique(channels))==numel(channels) && ...
    numel(channelTitles)==numel(channels),'Provide unique channels and one title per channel.');
for d = 1:numel(folders)
    datasets(d).Folder = folders(d); %#ok<AGROW>
    datasets(d).Label = options.Labels(d);
    config = fileread(fullfile(datasets(d).Folder,'config.txt'));
    datasets(d).RecordCount = str2double(readAcquisitionParameter(config,'number_of_waveforms'));
    datasets(d).RecordLength = str2double(readAcquisitionParameter(config,'waveform_length'));
    datasets(d).TimestampUTC = readAcquisitionParameter(config,'timestamp_utc');
    datasets(d).TriggerSource = readAcquisitionParameter(config,'trigger_source');
    datasets(d).BiasControlDAC = str2double(readAcquisitionParameter(config,'bias_control_requested'));
    datasets(d).VbiasDAC = str2double(readAcquisitionParameter(config,'bias_requested'));
    datasets(d).VgainDAC = str2double(readAcquisitionParameter(config,'vgain_requested'));
end
segmentLength = options.SegmentLength;
if segmentLength==0
    segmentLength = min([datasets.RecordLength]);
end
assert(segmentLength>=2 && all(mod([datasets.RecordLength],segmentLength)==0), ...
    'Every record must split into equal segments without padding.');
samplePeriod = options.SamplePeriod;
fullScaleADU = 2^options.AdcBits;
frequencyHz = (0:floor(segmentLength/2)) / (segmentLength*samplePeriod);
if ~isnan(options.RoiMHz)
    assert(options.RoiMHz>=frequencyHz(2)/1e6 && options.RoiMHz<=frequencyHz(end)/1e6, ...
        'ROI limit must be inside the plotted frequency range.');
end
amplitudeADU = zeros(numel(channels),numel(datasets),numel(frequencyHz));
rmsADU = zeros(numel(channels),numel(datasets));
segmentCounts = zeros(size(rmsADU));
for c = 1:numel(channels)
    for d = 1:numel(datasets)
        [amplitudeADU(c,d,:), rmsADU(c,d), segmentCounts(c,d)] = ...
            averageChannel(datasets(d),channels(c),samplePeriod,segmentLength);
    end
end
amplitudeDBFS = 20*log10(amplitudeADU/fullScaleADU);
results = struct('datasets',datasets,'channels',channels,'frequencyHz',frequencyHz, ...
    'segmentLength',segmentLength,'segmentCounts',segmentCounts,'samplePeriod',samplePeriod, ...
    'fullScaleADU',fullScaleADU,'amplitudeADU',amplitudeADU,'amplitudeDBFS',amplitudeDBFS, ...
    'rmsADU',rmsADU);

if ~isfolder(outputFolder)
    [ok,message] = mkdir(outputFolder);
    assert(ok,'Cannot create output directory: %s',message);
end
plotComparison(results,outputFolder,channelTitles,options.Subtitle,options.RoiMHz);
save(fullfile(outputFolder,'electronic_noise_spectra.mat'),'-struct','results');
end

function [amplitude,rmsNoise,segmentsTotal] = averageChannel(dataset,channel,samplePeriod,segmentLength)
filename = scanChannelFile(dataset.Folder,channel);
reader = pds.io.DaphneWaveformReader(filename);
closeReader = onCleanup(@() reader.close()); %#ok<NASGU>
assert(reader.WaveformCount == dataset.RecordCount && ...
    reader.SamplesPerWaveform == dataset.RecordLength, ...
    'Unexpected waveform dimensions in %s',filename);

batchRecords = 1000;
amplitudeSum = zeros(1,floor(segmentLength/2)+1);
squaredRmsSum = 0;
segmentsTotal = 0;
for first = 1:batchRecords:reader.WaveformCount
    count = min(batchRecords,reader.WaveformCount-first+1);
    raw = reader.readBlock(first,count);
    segments = reshape(raw.',segmentLength,[]).';
    spectrum = pds.signal.computeSpectrum(segments,samplePeriod,RemoveMean=true);
    amplitudeSum = amplitudeSum + spectrum.recordCount*spectrum.amplitudeMean;
    squaredRmsSum = squaredRmsSum + sum(spectrum.rmsPerRecord.^2);
    segmentsTotal = segmentsTotal + spectrum.recordCount;
end
amplitude = amplitudeSum/segmentsTotal;
rmsNoise = sqrt(squaredRmsSum/segmentsTotal);
fprintf('CH %d | %s | %d records, %d segments | RMS %.4f ADU\n', ...
    channel,dataset.Label,reader.WaveformCount,segmentsTotal,rmsNoise);
end

function plotComparison(results,outputFolder,channelTitles,subtitleText,roiMHz)
frequencyHz = results.frequencyHz(2:end);
curves = results.amplitudeDBFS(:,:,2:end);  % Exclude the removed DC bin.
valid = curves(isfinite(curves));
yLimits = [-120 0];
if ~isempty(valid)
    lower = floor(min(valid)/10)*10;
    yLimits = [lower,max(lower+10,ceil(max(valid)/10)*10)];
end
colors = get(groot,'DefaultAxesColorOrder');
for c = 1:numel(results.channels)
    channel = results.channels(c);
    fig = figure('Visible','off','Color','w','Position',[50 50 1100 660]);
    closeFigure = onCleanup(@() close(fig));
    ax = axes(fig);
    hold(ax,'on');
    plotted = gobjects(1,numel(results.datasets));
    for d = 1:numel(results.datasets)
        spectrum = struct('frequencyHz',frequencyHz, ...
            'amplitudeMean',reshape(results.amplitudeADU(c,d,2:end),1,[]),'inputUnit',"ADU");
        plotted(d) = pds.plotting.plotSpectrum(spectrum,Axes=ax,Scale="decibel", ...
            ReferenceValue=results.fullScaleADU,ReferenceLabel="dBFS",FrequencyUnit="MHz");
        plotted(d).LineWidth = 1.2;
        plotted(d).Color = colors(mod(d-1,size(colors,1))+1,:);
    end
    ax.XScale = 'log';
    if numel(frequencyHz)>1
        xlim(ax,frequencyHz([1 end])/1e6);
    end
    ylim(ax,yLimits);
    if isfinite(roiMHz)
        xline(ax,roiMHz,'--',sprintf('%g MHz',roiMHz),'Color',[0.25 0.25 0.25], ...
            'LineWidth',1.3,'LabelOrientation','horizontal','HandleVisibility','off');
    end
    box(ax,'on');
    ax.FontSize = 12;
    title(ax,"Average electronic-noise spectrum | "+channelTitles(c));
    subtitle(ax,subtitleText);
    ylabel(ax,'Mean FFT amplitude (dBFS)');
    legend(ax,plotted,[results.datasets.Label],'Location','southwest','Interpreter','none');
    stem = fullfile(outputFolder,sprintf('average_noise_fft_ch_%d',channel));
    savefig(fig,stem+".fig");
    exportgraphics(ax,stem+".png",'Resolution',180);
    clear closeFigure
end
end
