function [h_filt]= optimal_filter_for_daphne_gpessina_function(signal_waveforms,noise_waveforms,apply_decimation,n_decimation,is_inverted, filt,use_noise,pedestal_value)
    % best filter determination according to g.pessina lectures
    
    %load('C:\Users\e_cri\OneDrive\Documents\PhD\Investigacion\MATLAB\sim_cold_amp\transfer_function_estimation\fbk_rb_0_cdaphne_100n_coldamp.mat');
    
    %test if displacement is done properly in the frequency domain 
    
    % calculation of signal

    signal = signal_waveforms;
    if(is_inverted)
        signal = -signal + mean(signal(1:pedestal_value));
    else
        signal = signal - mean(signal(1:pedestal_value));
    end
    
    l_signal = length(signal);

    % claculation of noise 

    noise = noise_waveforms(:,1:l_signal);
    noise = noise - mean(noise(:,1:l_signal));
    

    if(apply_decimation)
        [num_decimator,den_decimator] = butter(1,(62.5e6/(2*n_decimation))/(62.5e6/2),'low');
        signal = filter(num_decimator,den_decimator,signal);
    end
    window_f = tukeywin(l_signal,30/l_signal);
    %noise = noise.*window_f;

    [~,n_disp] = max(signal); 
    [~,signal_fft,~] = mi_dft(signal,window_f,62.5e6,-n_disp+1);
    [~,delta_max_signal_fft,~] = mi_dft([1 zeros(1,length(signal)-1)],ones(1,4096),62.5e6,-n_disp+1);
    conj_disp_fft = conj(signal_fft);
    disp_signal = mi_idtft(signal_fft);
    disp_delta_max = mi_idtft(delta_max_signal_fft);
    disp_conj_delta_max = mi_idtft(conj_disp_fft);
    % figure(1)
    % plot(signal)
    % hold on 
    % plot(real(disp_signal))
    % plot(real(disp_delta_max))
    % plot(real(disp_conj_delta_max))
    % multply conjugate and delta in frequency domain 
    figure(2)
    [~ , ~, ~, pds_noise, ~] = f_fourier(noise,16e-9,false);
    if(use_noise)
        signal_mult = conj_disp_fft./(pds_noise);
    else
        signal_mult = conj_disp_fft./(1);
    end
    h_filt = real(mi_idtft(signal_mult));
    if(filt)
        [num_decimator,den_decimator] = butter(1,5e6/(62.5e6/2),'low');
        h_filt = filtfilt(num_decimator,den_decimator,h_filt);
    end

    h_filt = h_filt(n_disp:end);
    plot(h_filt)
    % 
    % figure(3)
    % plot(real(time_domain_signal_mult(2048:end)/max(real(time_domain_signal_mult(2048:end)))))
    % hold on 
    % time_domain_signal_mult_ = mi_idtft(conj_disp_fft);
    % plot(real(time_domain_signal_mult_(2048:end))/max(real(time_domain_signal_mult_(2048:end))))
    % 
    % % test of the filter 
    % 
    % noisy_signal = signal + filter(num_decimator,den_decimator,daphne_noise_fbk_int_off(1,:));
    % final_filter = (1/50000)*real(time_domain_signal_mult(end-1023:end));
    % filtered_signal = filter(final_filter,1,noisy_signal);
    % figure(4)
    % plot(filtered_signal)
end

