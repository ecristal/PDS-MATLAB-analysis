function [x] = mi_idtft(ft_function)
num_samples = length(ft_function);
omega = 0:(2*pi/(num_samples)):2*pi-(2*pi/(num_samples));
x = zeros(1,num_samples);
for i=1:num_samples
    x_i = 0;
    for j=1:num_samples
        x_i = x_i + ft_function(j)*exp(1i*omega(j)*(i-1));
    end
    x(i) = x_i;
end
x = x/num_samples;
end