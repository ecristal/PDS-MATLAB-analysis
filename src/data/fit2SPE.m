function [fitted_single_pe] = fit2SPE(model,spe_signal)

[max_spe_value, max_spe_pos] = max(spe_signal);

horizontal_gof = zeros(1,length(max_spe_pos-30:1:max_spe_value));
input_signal = zeros(1,length(spe_signal));
input_signal(max_spe_pos) = 1;
k = 30;
p = 1;
for i = max_spe_pos-30:max_spe_pos
    fitted_signal = max_spe_value*filter(model.Numerator{1},model.Denominator{1},circshift(input_signal,-k));
    horizontal_gof(p) = 1 - goodnessOfFit(spe_signal', fitted_signal','NRMSE');
    k = k - 1;
    p = p + 1;
end

[~, max_horizontal_gof_pos] = max(horizontal_gof);

amplitude_sweep = max_spe_value-3:0.1:max_spe_value+3;
vertical_gof = zeros(1,length(amplitude_sweep));

for i = 1:length(amplitude_sweep)
    fitted_signal = amplitude_sweep(i)*filter(model.Numerator{1},model.Denominator{1},circshift(input_signal,-(30-max_horizontal_gof_pos+1)));
    vertical_gof(i) = 1 - goodnessOfFit(spe_signal', fitted_signal','NRMSE');
end

[~, max_vertical_gof_pos] = max(vertical_gof);
fitted_single_pe = amplitude_sweep(max_vertical_gof_pos)*filter(model.Numerator{1},model.Denominator{1},circshift(input_signal,-(30-max_horizontal_gof_pos+1)));

plot(spe_signal)
hold on 
plot(fitted_single_pe)
end
