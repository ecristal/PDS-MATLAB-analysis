function [data,mean_data,Tm] = import_data_daphne_func(ch,waveforms_length,data_type,data_type_2,endianess,save_file,extract,filename_)
    %clearvars -except ch waveforms_length;
    if(extract)
        filename = strcat('channel_',num2str(ch));
    else
        filename = filename_;
        filename = split(filename,'.');
        filename = filename(1);
    end
    %filename = strcat('fbk_31_6_vgain_089_fpgafilter_off_behavioral_filtered_fast');
    Tm = 1/62.5e6;
    length_waveform = waveforms_length;
    
    if(~data_type)
        imported_data = importdata(strcat(filename,'.dat'))'; %% txt file
    else
        file = fopen(strcat(filename,'.dat'),"r");
        imported_data = fread(file,data_type_2,endianess)';
        fclose(file);
    end
    waveform_number = floor(length(imported_data)/length_waveform);
    %waveform_number = 5000;

    data = reshape(imported_data,length_waveform,waveform_number)';
    mean_data = mean(data);
    
%     k = 1;
%     for j=1:waveform_number
%        for i=1:length_waveform
%            data(j,i) = imported_data(k);
%            k = k + 1;
%        end
%        mean_data = mean_data + data(j,:);
%     end
    
%     data = concatenate_daphne_wavefomrs(data,10);
    
%     mean_data = mean_data/waveform_number;
    if(save_file)
        save(filename,'data','mean_data','Tm')
    end
end