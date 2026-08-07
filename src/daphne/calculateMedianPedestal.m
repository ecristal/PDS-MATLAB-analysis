function [pedestal, pedestal_25, pedestal_75, out_seed] = calculateMedianPedestal(signal,pedestal_limit, average_width, number_of_regions,in_seed)
% This script calculates the pedestal taking randomly distributed regions
% in the pretrigger cualting the mean values, then the returned average
% pedestal is the median value in a boxplot 

% ---- Input validation (avoid out-of-bounds / invalid ranges)
N = numel(signal);
if pedestal_limit < 1 || pedestal_limit > N
    error('calculateMedianPedestal:InvalidPedestalLimit', ...
          'pedestal_limit must be in [1, numel(signal)]. Got %d (N=%d).', pedestal_limit, N);
end
if average_width < 1
    error('calculateMedianPedestal:InvalidAverageWidth', ...
          'average_width must be >= 1. Got %d.', average_width);
end
start_max = pedestal_limit - average_width + 1; % last valid window start (inclusive)
if start_max < 1
    error('calculateMedianPedestal:WindowTooLong', ...
          'average_width=%d is too long for pedestal_limit=%d.', average_width, pedestal_limit);
end
if number_of_regions < 1
    error('calculateMedianPedestal:InvalidNumberOfRegions', ...
          'number_of_regions must be >= 1. Got %d.', number_of_regions);
end

% ---- Reproducible RNG
rng(in_seed,'multFibonacci');
out_seed = rng; % return RNG state after seeding (useful for debugging/reproducibility)

% ---- Random window starts (1-based, safe, uniform)
regions = randi([1, start_max], 1, number_of_regions);

len = length(regions);
mean_values = zeros(1,len);
for i=1:len
    % Note: MATLAB ranges are inclusive, so this selects exactly average_width samples
    idx0 = regions(i);
    idx1 = idx0 + average_width - 1;
    mean_values(i) = mean(signal(idx0:idx1));
end

% figure
% hold on 
% boxplot(mean_values)

pedestal_quantiles = quantile(mean_values,[0.25 0.5 0.75]);
pedestal = pedestal_quantiles(2);
pedestal_25 = pedestal_quantiles(1);
pedestal_75 = pedestal_quantiles(3);
end


