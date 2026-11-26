function [best,outputFolder,performance] = sweepSNR( ...
    scanRoot,shaperFile,outputRoot,lowPassHz,boxcarLengths,varargin)
%SWEEPSNR Sweep Butterworth cutoffs in Hz and causal boxcar lengths in samples.
% Pass Vbias, Vgain, Channels and any fixed settings as analyzeScan options.
% Returns one best observed fit per bias, gain and channel. The grid fits
% omit bootstrap intervals. The output folder includes snr_grid.csv and meshes.
assert(~isempty(lowPassHz) && ~isempty(boxcarLengths),'Supply two nonempty sweep axes.');
[best,outputFolder,performance] = pds.coldbox.analyzeScan( ...
    scanRoot,shaperFile,outputRoot,varargin{:}, ...
    'SweepLowPassHz',lowPassHz,'SweepBoxcarLengths',boxcarLengths);
end
