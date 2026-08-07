function [locs, pks, widths, proms, min_sep] = find_peaks_hist_adaptive(x_hist, y_hist, varargin)
%FIND_PEAKS_HIST_ADAPTIVE Adaptive peak positions for histogram data (Option A: findpeaks).
%
% Usage:
%   [locs,pks,widths,proms,min_sep] = find_peaks_hist_adaptive(x_hist,y_hist)
%   [...] = find_peaks_hist_adaptive(...,'Name',Value,...)
%
% Inputs:
%   x_hist, y_hist : vectors (bin centers and counts), same length
%
% Name-Value options:
%   'Smoother'            : "movmedian" (default) | "sgolay" | "movmean"
%   'SmoothWindow'        : odd integer window (default 5)
%   'MinProminenceFrac'   : fraction of max(smoothed y) (default 0.02)
%   'MinPeakWidthBins'    : minimum width in bins (default 3)
%   'MinSepFactor'        : factor * median(candidate spacing) (default 0.6)
%   'MinSepMinBins'       : minimum separation in bins (default 5)
%   'UseWidthBasedSep'    : true/false (default false)
%   'WidthSepFactor'      : factor * median(widths) if UseWidthBasedSep=true (default 1.5)
%
% Outputs:
%   locs    : peak positions (x units)
%   pks     : peak heights (y units, after smoothing)
%   widths  : peak widths (x units)
%   proms   : prominences
%   min_sep : chosen MinPeakDistance (x units)

    % ---- Parse inputs ----
    x_hist = x_hist(:);
    y_hist = y_hist(:);
    if numel(x_hist) ~= numel(y_hist)
        error('x_hist and y_hist must have the same length.');
    end

    p = inputParser;
    p.addParameter('Smoother', "movmedian", @(s) isstring(s) || ischar(s));
    p.addParameter('SmoothWindow', 5, @(n) isnumeric(n) && isscalar(n) && n>=1);
    p.addParameter('MinProminenceFrac', 0.02, @(v) isnumeric(v) && isscalar(v) && v>0);
    p.addParameter('MinPeakWidthBins', 3, @(n) isnumeric(n) && isscalar(n) && n>=1);
    p.addParameter('MinSepFactor', 0.6, @(v) isnumeric(v) && isscalar(v) && v>0);
    p.addParameter('MinSepMinBins', 5, @(n) isnumeric(n) && isscalar(n) && n>=1);
    p.addParameter('UseWidthBasedSep', false, @(b) islogical(b) && isscalar(b));
    p.addParameter('WidthSepFactor', 1.5, @(v) isnumeric(v) && isscalar(v) && v>0);
    p.parse(varargin{:});
    opt = p.Results;

    % ---- Ensure sane smoothing window ----
    w = round(opt.SmoothWindow);
    if w < 1, w = 1; end
    if mod(w,2) == 0, w = w + 1; end  % odd

    % ---- Smooth ----
    smoother = string(opt.Smoother);
    switch lower(smoother)
        case "movmedian"
            yS = smoothdata(y_hist, "movmedian", w);
        case "movmean"
            yS = smoothdata(y_hist, "movmean", w);
        case "sgolay"
            yS = smoothdata(y_hist, "sgolay", w);
        otherwise
            error('Unknown Smoother: %s', smoother);
    end

    dx = median(diff(x_hist));
    if ~isfinite(dx) || dx <= 0
        dx = 1; % fallback
    end

    minProm = opt.MinProminenceFrac * max(yS);
    minW    = opt.MinPeakWidthBins * dx;

    % ---- Pass 1: permissive ----
    [p0, x0, w0, prom0] = findpeaks(yS, x_hist, ...
        "MinPeakProminence", minProm, ...
        "MinPeakWidth", minW);

    % ---- Choose adaptive min_sep ----
    min_sep = opt.MinSepMinBins * dx; % baseline

    if opt.UseWidthBasedSep && ~isempty(w0)
        min_sep = max(opt.WidthSepFactor * median(w0), min_sep);
    else
        if numel(x0) >= 2
            d = diff(sort(x0));
            min_sep = max(opt.MinSepFactor * median(d), min_sep);
        end
    end

    % ---- Pass 2: enforce separation ----
    [pks, locs, widths, proms] = findpeaks(yS, x_hist, ...
        "MinPeakProminence", minProm, ...
        "MinPeakDistance", min_sep, ...
        "MinPeakWidth", minW);

    % Sort by x position (findpeaks already does for x input, but keep safe)
    [locs, order] = sort(locs);
    pks    = pks(order);
    widths = widths(order);
    proms  = proms(order);
end
