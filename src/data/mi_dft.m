function [f,p,pds] = mi_dft(waveform,window_f,fs,n_desplazamiento)
num_samples = length(waveform);
omega = 0:(2*pi/(num_samples)):2*pi-(2*pi/(num_samples));
f = zeros(1,num_samples);
p = zeros(1,num_samples);
pds = zeros(1,num_samples);
%delta_f = fs/(num_samples);
s_2 = 0;
for i = 1:num_samples
    s_2 = s_2 + window_f(i)^2;
end
for i=1:num_samples
    f(i) = fs*omega(i)/(2*pi);
    omega_num = 0;
    for j=1:num_samples
        omega_num = omega_num + waveform(j)*exp(-1i*omega(i)*(j-1))*exp(-1i*omega(i)*(n_desplazamiento));
    end
    p(i) = omega_num;
    pds(i) = (abs(p(i))^2)/((fs)*s_2);
end
end