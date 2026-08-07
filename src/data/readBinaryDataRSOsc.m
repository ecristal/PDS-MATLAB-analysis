function [data] = readBinaryDataRSOsc(dataInfo_filename,dataWaveform_filename)
% readBinaryDataRSOsc This function parses binary data from RS Osciloscope
% function [data] = readBinaryDataRSOsc(dataInfo,dataWaveform)
% dataInfo: XML data header file that contains information about the waveforms
%           e.g. '/path/to/file/file_name.bin'
% dataWaveform: binary waveforms file (i.e. file_name.Wfm.bin).
%               e.g. '/path/to/file/file_name.Wfm.bin'

headerInfo_ = xmltools(dataInfo_filename);


SignalHardwareRecordLength = str2double(headerInfo_.child(2).child(1).child(18).attribs(4).value);
SignalRecordLength = str2double(headerInfo_.child(2).child(1).child(15).attribs(4).value);
Resolution = str2double(headerInfo_.child(2).child(1).child(2).attribs(4).value);
Format = headerInfo_.child(2).child(1).child(67).attribs(5).value;
Impedance = str2double(headerInfo_.child(2).child(1).child(12).attribs(4).value);
LeadingSettlingSamples = str2double(headerInfo_.child(2).child(1).child(30).attribs(4).value);
TrailingAdittionalSamples = SignalHardwareRecordLength - SignalRecordLength - LeadingSettlingSamples;

Format = split(Format,'_');
Format = Format(end);
Format = lower(Format{1});

file = fopen(dataWaveform_filename,"r");

imported_data = fread(file,Format)';
imported_data = imported_data(3:end); 

fclose(file);

data.Resolution = Resolution;
data.SignalHardwareRecordLength = SignalHardwareRecordLength;
data.SignalRecordLength = SignalRecordLength;
data.Format = Format;
data.Impedance = Impedance;
data.NumberOfWaveforms = length(imported_data)/SignalHardwareRecordLength;

data.waveforms = reshape(imported_data',SignalHardwareRecordLength,data.NumberOfWaveforms)';
data.waveforms = data.waveforms(:,(LeadingSettlingSamples + 1):(SignalHardwareRecordLength - TrailingAdittionalSamples));
data.mean_waveform = mean(data.waveforms);

end

