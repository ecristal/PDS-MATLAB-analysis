function [mu1,sigma1,mu2,sigma2,delta,SNR,x_hist_plot,gauss_fitted_curve,gof,center] = gaussian_fit_SNR(integral,histogram_bin,min_sep,min_localmax_peak_pos,x_axis_low_limit,x_axis_high_limit,center_min,center_max,init_sigma_2_sqrt, gaussN, eff)

h = histogram(integral,'BinWidth',histogram_bin,'DisplayStyle','stairs','LineWidth',2);
grid on 

%y_hist = histcounts(integral,h.BinEdges);

y_hist = h.Values;
binEdges = h.BinEdges;
x_hist = binEdges(1:end-1) + histogram_bin/2;
if(eff == 40)
    cutoff = 0.10:0.05:0.15;
elseif(eff == 45)
    cutoff = 0.15:0.05:0.50;
else
    cutoff = 0.20:0.05:0.30;
end
gof_cutoff = zeros(1,length(cutoff));
max_gof_shift_pos = zeros(1,length(cutoff));
for j=1:length(cutoff)
    [a, b] = butter(3,cutoff(j),'low');
    gof_shift = zeros(1,10);
    for i=1:10
        y_hist_f1 = filter(a,b,y_hist);
        y_hist_f = circshift(y_hist_f1,-i);
        gof_shift(i) = 1 - goodnessOfFit(y_hist_f',y_hist','NRMSE');
    end
    [gof_cutoff(j), max_gof_shift_pos(j)] = max(gof_shift);
end

[~, max_gof_cutoff_pos] = max(gof_cutoff);
max_gof_shift = max_gof_shift_pos(max_gof_cutoff_pos);
max_gof_cutoff = cutoff(max_gof_cutoff_pos);

[a, b] = butter(3,max_gof_cutoff,'low');
y_hist = filter(a,b,y_hist);
y_hist = circshift(y_hist,-max_gof_shift);

%L = islocalmax(movmedian(y_hist,2),'MinSeparation',min_sep,'SamplePoints',x_hist);
[center, hist_max_values] = find_peaks_hist_adaptive(x_hist,y_hist, ...
    'Smoother',"movmedian",'SmoothWindow',7,'MinProminenceFrac',0.02);
%L = L & (x_hist>min_localmax_peak_pos);

% Find the centers of the bins that islocalmax identified as peaks
%left = binEdges(L);
%right = binEdges([false L]);
%center = (left + right)/2;
%hist_max_values = y_hist(L);

plot(center, hist_max_values, 'o')

[~,center_start] = max(center>center_min & center<center_max);

x_condition_1 = x_hist>x_axis_low_limit;
x_condition_2 = x_hist<x_axis_high_limit;

y_hist = y_hist(x_condition_1 & x_condition_2);

x_hist = x_hist(x_condition_1 & x_condition_2);

xlim([x_axis_low_limit x_axis_high_limit])
x_hist_plot = x_axis_low_limit:0.01:x_axis_high_limit;

gaussN_str = sprintf('gauss%d',gaussN);
fit_options = fitoptions(gaussN_str);
%fit_options.StartPoint = [NaN, center(center_start), NaN, NaN, center(center_start+1), NaN, NaN, center(center_start+2), NaN, NaN, center(center_start+3), NaN, NaN, center(center_start+4), NaN, NaN, center(center_start+5), NaN];
%snr_gauss_fit = fit(x_hist',y_hist','gauss4');

for i=1:gaussN
    if(i <= length(hist_max_values))
        fit_options.StartPoint(3*i - 2) = hist_max_values(center_start + (i-1));
        fit_options.StartPoint(3*i - 1) = center(center_start + (i-1));
        fit_options.StartPoint(3*i) = init_sigma_2_sqrt;
    else
        fit_options.StartPoint(3*i - 2) = hist_max_values(end);
        fit_options.StartPoint(3*i - 1) = center(end);
        fit_options.StartPoint(3*i) = init_sigma_2_sqrt;
    end
end

[snr_gauss_fit, gof_struct] = fit(x_hist',y_hist',gaussN_str,fit_options);
gof = gof_struct.rsquare;
gauss_fitted_curve = snr_gauss_fit(x_hist_plot);

mu_vec = [snr_gauss_fit.b1 snr_gauss_fit.b2 snr_gauss_fit.b3];
sigma_vec = [snr_gauss_fit.c1 snr_gauss_fit.c2 snr_gauss_fit.c3]./sqrt(2);
[mu_vec_sorted, sort_indexes] = sort(mu_vec); 
sigma_vec_sorted = sigma_vec(sort_indexes);

mu1 = mu_vec_sorted(1);
sigma1 = sigma_vec_sorted(1);

mu2 = mu_vec_sorted(2);
sigma2 = sigma_vec_sorted(2);

delta = mu2 - mu1;
SNR = delta/sigma1;
SNR1 = delta/sqrt(sigma1*sigma1 + sigma2*sigma2);