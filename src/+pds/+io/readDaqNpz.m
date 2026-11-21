function [data, mean_data, Tm, info] = readDaqNpz(filename, channel)
%READDAQNPZ Import one legacy-FPGA channel from a calibration NPZ step.
% [data, mean_data, Tm, info] = pds.io.readDaqNpz(filename, channel)
% data is double [waveform,sample], without pedestal or polarity correction.
% Timestamps remain uint64; relative seconds use integer subtraction first.
% Supports pds.calibration.step.v1, frame version 4, 256 samples, 14-bit ADC.
% Uses MATLAB only. See docs/workflows/daq-npz-import.md.

arguments
    filename (1,1) string
    channel (1,1) double {mustBeInteger, mustBeNonnegative, mustBeLessThanOrEqual(channel,255)}
end
if ~isfile(filename)
    error('pds:io:readDaqNpz:FileNotFound', 'File not found: %s', filename);
end

directory = tempname;
mkdir(directory);
cleanup = onCleanup(@() rmdir(directory, 's'));
unzip(filename, directory);
names = {'adc', 'channels', 'timestamps', 'stream_ids', ...
    'timing_tags', 'continuation', 'metadata_json'};
arrays = struct;
for index = 1:numel(names)
    path = fullfile(directory, [names{index}, '.npy']);
    if ~isfile(path)
        error('pds:io:readDaqNpz:MissingArray', 'Missing array: %s.', names{index});
    end
    arrays.(names{index}) = readCalibrationNpy(path);
end
if ~ischar(arrays.metadata_json)
    error('pds:io:readDaqNpz:InvalidMetadata', 'metadata_json must be Unicode text.');
end
metadata = jsondecode(arrays.metadata_json);
if ~isfield(metadata, 'receipt')
    error('pds:io:readDaqNpz:InvalidMetadata', 'Missing acquisition receipt.');
end
receipt = metadata.receipt;
required = {'schema','frame_version','samples_per_frame','adc_bits', ...
    'clock_hz','channel_namespace','channels','received_counts'};
if ~all(isfield(receipt, required)) || ...
        ~strcmp(receipt.schema, 'pds.calibration.step.v1') || ...
        receipt.frame_version ~= 4 || receipt.samples_per_frame ~= 256 || ...
        receipt.adc_bits ~= 14 || receipt.clock_hz ~= 62500000 || ...
        ~strcmp(receipt.channel_namespace, 'legacy_FPGA')
    error('pds:io:readDaqNpz:UnsupportedSchema', ...
        'Expected calibration step v1, frame v4, 256 samples, 14 bits, 62.5 MHz, legacy_FPGA.');
end
eventCount = size(arrays.adc, 1);
if ~isa(arrays.adc, 'uint16') || ~ismatrix(arrays.adc) || ...
        size(arrays.adc, 2) ~= receipt.samples_per_frame || ...
        eventCount == 0 || any(arrays.adc(:) > 2^receipt.adc_bits-1)
    error('pds:io:readDaqNpz:InvalidAdc', 'Expected nonempty uint16 [event,256] within ADC range.');
end
types = {'uint8', 'uint64', 'uint8', 'uint8', 'logical'};
for index = 2:6
    value = arrays.(names{index});
    if ~isa(value, types{index-1}) || ~iscolumn(value) || numel(value) ~= eventCount
        error('pds:io:readDaqNpz:InvalidVector', ...
            '%s must have one %s value per waveform.', names{index}, types{index-1});
    end
end
available = unique(arrays.channels);
if ~isequal(double(available(:)), sort(double(receipt.channels(:))))
    error('pds:io:readDaqNpz:ChannelMismatch', 'Channel IDs disagree with receipt.');
end
for index = 1:numel(available)
    key = matlab.lang.makeValidName(num2str(available(index)));
    if ~isfield(receipt.received_counts, key) || ...
            sum(arrays.channels == available(index)) ~= receipt.received_counts.(key)
        error('pds:io:readDaqNpz:CountMismatch', 'Channel counts disagree with receipt.');
    end
end
selected = arrays.channels == channel;
if ~any(selected)
    error('pds:io:readDaqNpz:ChannelNotFound', ...
        'FPGA channel %d is absent. Available channels: %s.', channel, mat2str(available.'));
end
timestamps = arrays.timestamps(selected);
if any(timestamps(2:end) < timestamps(1:end-1))
    error('pds:io:readDaqNpz:UnorderedTimestamps', 'Channel timestamps decrease.');
end
data = double(arrays.adc(selected, :));
mean_data = mean(data, 1);
Tm = 1 / receipt.clock_hz;
info = struct('filename', filename, 'channel', channel, ...
    'availableChannels', available, 'sourceRows', find(selected), ...
    'timestamps', timestamps, ...
    'relativeTimeSeconds', double(timestamps - timestamps(1)) * Tm, ...
    'streamIds', arrays.stream_ids(selected), ...
    'timingTags', arrays.timing_tags(selected), ...
    'continuation', arrays.continuation(selected), ...
    'metadata', metadata, 'metadataJson', string(arrays.metadata_json), ...
    'module', "", 'panelChannel', NaN);
key = matlab.lang.makeValidName(num2str(channel));
if isfield(metadata, 'module_by_firmware_channel') && ...
        isfield(metadata.module_by_firmware_channel, key)
    info.module = string(metadata.module_by_firmware_channel.(key));
end
if isfield(receipt, 'firmware_to_panel') && isfield(receipt.firmware_to_panel, key)
    info.panelChannel = receipt.firmware_to_panel.(key);
end
end
