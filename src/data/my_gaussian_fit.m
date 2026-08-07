function [mu1,sigma1,snr_gauss_fit] = my_gaussian_fit(x_hist,y_hist,max_value,max_value_x_pos,init_sigma_2_sqrt)

%x_hist_plot = x_axis_low_limit:0.01:x_axis_high_limit;
fit_options = fitoptions('gauss1');
fit_options.StartPoint = [NaN, NaN, NaN];
%snr_gauss_fit = fit(x_hist',y_hist','gauss4');
fit_options.StartPoint(1) = max_value;
fit_options.StartPoint(2) = max_value_x_pos;
fit_options.StartPoint(3) = init_sigma_2_sqrt;
weights_ = zeros(1,length(x_hist));
weights_(max_value_x_pos-init_sigma_2_sqrt:max_value_x_pos+init_sigma_2_sqrt) = ones(1,2*init_sigma_2_sqrt+1);
fit_options.Weights = weights_;

snr_gauss_fit = fit(x_hist',y_hist','gauss1',fit_options);
%gauss_fitted_curve = snr_gauss_fit(x_hist_plot);

mu_vec = [snr_gauss_fit.b1];
sigma_vec = [snr_gauss_fit.c1]./sqrt(2);


mu1 = mu_vec(1);
sigma1 = sigma_vec(1);