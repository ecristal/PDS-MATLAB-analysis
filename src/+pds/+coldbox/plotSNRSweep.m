function best = plotSNRSweep(runFolder)
%PLOTSNRSWEEP Save the observed maxima and regenerate meshes from snr_grid.csv.
arguments
    runFolder (1,1) string {mustBeFolder}
end
file = fullfile(runFolder,'snr_grid.csv');
opts = detectImportOptions(file);
opts = setvartype(opts,{'Status','StatusReason'},'string');
opts = setvartype(opts,{'LowPassMHz','BoxcarLength','SNR','Accepted','ScoreSample'},'double');
grid = readtable(file,opts);
saved = load(fullfile(runFolder,'pipeline.mat'),'pipeline');
p = saved.pipeline;
keys = {'Channel','VbiasDAC','VgainDAC'};
grid = sortrows(grid,[keys,{'LowPassMHz','BoxcarLength'}]);
[group,coordinates] = findgroups(grid(:,keys));
numGroups = height(coordinates);
assert(numGroups>0,'The SNR sweep grid is empty.');

best = table();
rows = cell(numGroups,1);
for k = 1:numGroups
    rows{k} = grid(group==k,:);
    cells = rows{k};
    found = isfinite(cells.SNR) & cells.Status=="resolved";
    cellIndex = find(found);
    if isempty(cellIndex)
        peak = cells(1,:);
        peak{1,{'LowPassMHz','BoxcarLength','SNR','Accepted','ScoreSample'}} = nan(1,5);
        peak.Status = "unresolved";
        peak.StatusReason = "No grid cell resolved 0 and 1 PE.";
    else
        [~,i] = max(cells.SNR(cellIndex));
        peak = cells(cellIndex(i),:);
    end
    peak.ResolvedCells = nnz(found);
    peak.TotalCells = height(cells);
    peak.AtGridEdge = ismember(peak.LowPassMHz,[min(cells.LowPassMHz),max(cells.LowPassMHz)]) || ...
        ismember(peak.BoxcarLength,[min(cells.BoxcarLength),max(cells.BoxcarLength)]);
    best = [best; peak]; %#ok<AGROW>
end
writetable(best,fullfile(runFolder,'best_snr.csv'));

destination = fullfile(runFolder,'meshes');
if ~isfolder(destination), mkdir(destination); end
[x,y] = meshgrid(p.sweepLowPassHz/1e6,p.sweepBoxcarLengths);
for k = 1:numGroups
    cells = rows{k};
    assert(isequal(cells.BoxcarLength,y(:)) && ...
        all(abs(cells.LowPassMHz-x(:))<=1e-12*max(1,abs(x(:)))), ...
        'Incomplete or duplicate cutoff/boxcar cells in the SNR grid.');
    drawMesh(destination,p.figureTitle,x,y,reshape(cells.SNR,size(x)),best(k,:));
end
end

function drawMesh(folder,figureTitle,x,y,z,peak)
f = figure('Visible','off','Color','white','Position',[100 100 820 640]);
closeFigure = onCleanup(@() close(f));
ax = axes(f);
if all(size(x)>=2)
    mesh(ax,x,y,z);
else
    plot3(ax,x(:),y(:),z(:),'o-');
end
hold(ax,'on');
if isfinite(peak.SNR)
    plot3(ax,peak.LowPassMHz,peak.BoxcarLength,peak.SNR,'ro', ...
        'MarkerSize',9,'MarkerFaceColor','r','HandleVisibility','off');
    detail = sprintf('Peak SNR %.3f at %.3g MHz and %d samples', ...
        peak.SNR,peak.LowPassMHz,peak.BoxcarLength);
else
    detail = 'No resolved 0/1 PE fit';
end
view(ax,[-37.5 30]);
grid(ax,'on');
xlabel(ax,'Low-pass cutoff (MHz)');
ylabel(ax,'Boxcar length (samples)');
zlabel(ax,'SNR');
title(ax,{char(figureTitle),sprintf('Vbias %d DAC | Vgain %d DAC | DAPHNE CH %d', ...
    peak.VbiasDAC,peak.VgainDAC,peak.Channel)},detail);
stem = fullfile(folder,sprintf('snr_mesh_vbias_%d_vgain_%d_ch_%d', ...
    peak.VbiasDAC,peak.VgainDAC,peak.Channel));
savefig(f,stem+".fig");
exportgraphics(ax,stem+".png",'Resolution',160);
end
