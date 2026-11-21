classdef TestReadDaqNpz < matlab.unittest.TestCase
    properties (TestParameter)
        fortranOrder = {true, false}
        endian = {'<', '>'}
    end
    methods (TestClassSetup)
        function addSource(testCase)
            directory = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'src');
            addpath(directory);
            testCase.addTeardown(@() rmpath(directory));
        end
    end
    methods (Test)
        function preservesOrderTypesAndExactTicks(testCase, fortranOrder, endian)
            [path, expected, ticks] = fixture(testCase, fortranOrder, endian, "valid");
            [data, average, Tm, info] = pds.io.readDaqNpz(path, 2);
            testCase.verifyEqual(data, double(expected([1,3,5], :)));
            testCase.verifyEqual(average, mean(data, 1));
            testCase.verifyEqual(Tm, 16e-9);
            testCase.verifyClass(info.timestamps, 'uint64');
            testCase.verifyEqual(info.timestamps, ticks([1,3,5]));
            testCase.verifyEqual(diff(info.timestamps), uint64([1024;1024]));
            testCase.verifyEqual(info.relativeTimeSeconds, [0;1024;2048]*Tm);
            testCase.verifyEqual(info.sourceRows, [1;3;5]);
            testCase.verifyEqual(info.module, "M1_CH1");
            testCase.verifyEqual(info.panelChannel, 2);
            testCase.verifyEqual(info.continuation, false(3,1));
            testCase.verifyClass(info.timingTags, 'uint8');
        end
        function rejectsAbsentChannel(testCase)
            path = fixture(testCase, true, '<', "valid");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 24), ...
                'pds:io:readDaqNpz:ChannelNotFound');
        end
        function rejectsWrongCounts(testCase)
            path = fixture(testCase, true, '<', "counts");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 2), ...
                'pds:io:readDaqNpz:CountMismatch');
        end
        function rejectsDecreasingTicks(testCase)
            path = fixture(testCase, true, '<', "timestamps");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 2), ...
                'pds:io:readDaqNpz:UnorderedTimestamps');
        end
        function rejectsWrongAdcRange(testCase)
            path = fixture(testCase, true, '<', "range");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 2), ...
                'pds:io:readDaqNpz:InvalidAdc');
        end
        function rejectsMissingVector(testCase)
            path = fixture(testCase, true, '<', "missing");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 2), ...
                'pds:io:readDaqNpz:MissingArray');
        end
        function rejectsTruncatedPayload(testCase)
            path = fixture(testCase, true, '<', "truncated");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 2), ...
                'pds:io:readDaqNpz:PayloadSize');
        end
        function rejectsUnsupportedSchema(testCase)
            path = fixture(testCase, true, '<', "schema");
            testCase.verifyError(@() pds.io.readDaqNpz(path, 2), ...
                'pds:io:readDaqNpz:UnsupportedSchema');
        end
    end
end

function [path, adc, ticks] = fixture(testCase, fortranOrder, endian, variant)
directory = tempname;
mkdir(directory);
testCase.addTeardown(@() rmdir(directory, 's'));
adc = reshape(uint16(1:1536), 6, 256);
ticks = bitshift(uint64(1),56) + uint64([17;17;1041;1041;2065;2065]);
if variant == "timestamps"
    ticks(5) = ticks(1)-uint64(1);
elseif variant == "range"
    adc(1) = 16384;
end
receipt = struct('schema', 'pds.calibration.step.v1', 'frame_version',4, ...
    'samples_per_frame',256, 'adc_bits',14, 'clock_hz',62500000, ...
    'channel_namespace','legacy_FPGA', 'channels',[2,3], ...
    'received_counts', struct('x2',3,'x3',3), ...
    'firmware_to_panel',struct('x2',2,'x3',3));
if variant == "counts"
    receipt.received_counts.x2 = 4;
elseif variant == "schema"
    receipt.frame_version = 3;
end
meta = struct('receipt',receipt, ...
    'module_by_firmware_channel',struct('x2','M1_CH1','x3','M1_CH2'));
raw = strrep(strrep(jsonencode(meta), '"x2":', '"2":'), '"x3":', '"3":');
writeNpy(fullfile(directory,'adc.npy'), adc, [endian,'u2'], fortranOrder);
writeNpy(fullfile(directory,'channels.npy'), uint8([2;3;2;3;2;3]), '|u1', false);
writeNpy(fullfile(directory,'timestamps.npy'), ticks, [endian,'u8'], false);
writeNpy(fullfile(directory,'stream_ids.npy'), uint8(zeros(6,1)), '|u1', false);
writeNpy(fullfile(directory,'timing_tags.npy'), uint8(2*ones(6,1)), '|u1', false);
writeNpy(fullfile(directory,'continuation.npy'), false(6,1), '|b1', false);
writeNpy(fullfile(directory,'metadata_json.npy'), raw, ['<U',num2str(numel(raw))], false);
if variant == "missing"
    delete(fullfile(directory,'stream_ids.npy'));
elseif variant == "truncated"
    file = fopen(fullfile(directory,'channels.npy'),'rb');
    bytes = fread(file,Inf,'*uint8');
    fclose(file);
    file = fopen(fullfile(directory,'channels.npy'),'wb');
    fwrite(file,bytes(1:end-1),'uint8');
    fclose(file);
end
files = dir(fullfile(directory,'*.npy'));
zip(fullfile(directory,'fixture.zip'), {files.name}, directory);
path = fullfile(directory, 'fixture.npz');
movefile(fullfile(directory,'fixture.zip'), path);
end

function writeNpy(path, value, descriptor, fortranOrder)
if ischar(value)
    shape = '';
    payload = uint32(value);
    precision = 'uint32';
elseif isvector(value)
    shape = sprintf('%d,',numel(value));
    payload = value;
    precision = class(value);
else
    shape = sprintf('%d, %d',size(value));
    payload = value;
    if ~fortranOrder
        payload = value.';
    end
    precision = class(value);
end
if islogical(value)
    precision = 'uint8';
end
order = 'False';
if fortranOrder
    order = 'True';
end
header = sprintf('{''descr'': ''%s'', ''fortran_order'': %s, ''shape'': (%s), }', ...
    descriptor,order,shape);
padding = mod(-(10+numel(header)+1),64);
header = [header, repmat(' ',1,padding), newline];
file = fopen(path,'wb','ieee-le');
cleanup = onCleanup(@() fclose(file));
fwrite(file,uint8([147,double('NUMPY'),1,0]),'uint8');
fwrite(file,uint16(numel(header)),'uint16');
fwrite(file,uint8(header),'uint8');
machine = 'ieee-le';
if descriptor(1) == '>'
    machine = 'ieee-be';
end
fwrite(file,payload,precision,0,machine);
end
