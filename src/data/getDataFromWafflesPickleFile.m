function [signal1, signal2, timestamp, channels, endpoint] = getDataFromWafflesPickleFile(channel_1,channel_2,pickle_file)
    pyenv;
    py.importlib.import_module('waffles.data_classes.Waveform');
    pickle = py.importlib.import_module('pickle');
    archivo = py.open(pickle_file, 'rb');
    waveforms_list = pickle.load(archivo);
    waveforms_list = cell(waveforms_list);
    number_of_waveforms = length(waveforms_list);
    signal1 = zeros(number_of_waveforms,1024);
    signal2 = zeros(number_of_waveforms,1024);
    timestamp = int64(zeros(number_of_waveforms,2));
    channels = int8(zeros(number_of_waveforms,2));
    endpoint = int8(zeros(number_of_waveforms,2));

    for i=1:number_of_waveforms
        channel_1_timestamp = int64(0);
        channel_2_timestamp = int64(0);
        adcs_channel_1 = int64([]);
        adcs_channel_2 = int64([]);
        wv_channel_1 = int8(-1);
        wv_channel_2 = int8(-1);
        wv_endpoint_1 = int8(-1);
        wv_endpoint_2 = int8(-1);
        complete_waveforms = waveforms_list{i};
        cw_len = length(complete_waveforms);
        assert(cw_len == 40,'Error: incomplete waveformset found')
        for j=1:cw_len
            waveform = complete_waveforms{j};
            if(int8(waveform.channel) == int8(channel_1))
                channel_1_timestamp = int64(waveform.timestamp);
                adcs_channel_1 = int16(waveform.adcs);
                wv_channel_1 = int8(waveform.channel);
                wv_endpoint_1 = int8(waveform.endpoint);
            end
            if(int8(waveform.channel) == int8(channel_2))
                channel_2_timestamp = int64(waveform.timestamp);
                adcs_channel_2 = int16(waveform.adcs);
                wv_channel_2 = int8(waveform.channel);
                wv_endpoint_2 = int8(waveform.endpoint);
            end
        end
        assert(int8(channel_1) == wv_channel_1,strcat('Error: Channel ', num2str(int8(channel_1)),'not found'))
        assert(int8(channel_2) == wv_channel_2,strcat('Error: Channel ', num2str(int8(channel_2)),'not found'))
        assert(channel_1_timestamp == channel_2_timestamp, 'Error: waveforms have different timestamps')
        assert(wv_endpoint_1 == wv_endpoint_2, 'Error: waveforms have different endpoints')
        signal1(i,:) = double(adcs_channel_1);
        signal2(i,:) = double(adcs_channel_2);
        timestamp(i,1) = channel_1_timestamp;
        timestamp(i,2) = channel_2_timestamp;
        channels(i,1) = wv_channel_1;
        channels(i,2) = wv_channel_2;
        endpoint(i,1) = wv_endpoint_1;
        endpoint(i,2) = wv_endpoint_2;
    end
end 