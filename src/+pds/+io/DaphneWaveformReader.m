classdef DaphneWaveformReader < handle
    %DAPHNEWAVEFORMREADER Read one waveform from a DAPHNE binary channel file.
    % reader = pds.io.DaphneWaveformReader(file, SamplesPerWaveform=1e6)
    % Open a little-endian uint16 .dat or a .7z containing <name>.dat.
    % Omit SamplesPerWaveform to look in dma_format.json and config.txt.
    % read(index) uses one-based indices and leaves the next() cursor alone.
    % readBlock(index,count) returns consecutive uint16 rows, also without
    % moving the next() cursor.
    % Use hasNext() to test for the end of sequential reads.
    % A .7z uses 7-Zip and needs temporary space for the uncompressed .dat.
    % TempDirectory selects an existing directory on a different disk.
    % close() releases the file and removes any extracted temporary copy.

    properties (SetAccess = private)
        SamplesPerWaveform (1,1) double
        WaveformCount (1,1) double
        NextIndex (1,1) double = 1
    end

    properties (Access = private)
        FileID (1,1) double = -1
        ScratchDirectory (1,1) string = ""
    end

    methods
        function obj = DaphneWaveformReader(filename, options)
            arguments
                filename (1,1) string
                options.SamplesPerWaveform double {mustBePositive, mustBeInteger} = []
                options.TempDirectory (1,1) string = string(tempdir)
                options.SevenZipExecutable (1,1) string = ""
            end
            if ~isfile(filename)
                error('pds:io:DaphneWaveformReader:FileNotFound', ...
                    'File not found: %s.', filename);
            end
            [~, attributes] = fileattrib(filename);
            filename = string(attributes.Name);
            [folder, name, extension] = fileparts(filename);
            if ~any(strcmpi(extension, [".dat", ".7z"]))
                error('pds:io:DaphneWaveformReader:UnsupportedFile', ...
                    'Expected a binary .dat or .7z file.');
            end
            sampleCount = options.SamplesPerWaveform;
            if isempty(sampleCount)
                sampleCount = acquisitionLength(folder, name);
            end
            if ~isnumeric(sampleCount) || ~isscalar(sampleCount) || ...
                    ~isreal(sampleCount) || ~isfinite(sampleCount) || ...
                    sampleCount < 1 || sampleCount ~= fix(sampleCount) || sampleCount > flintmax/2
                error('pds:io:DaphneWaveformReader:InvalidLength', ...
                    'SamplesPerWaveform must be a positive integer representable as a byte offset.');
            end
            obj.SamplesPerWaveform = sampleCount;

            try
                dataFile = filename;
                if strcmpi(extension, '.7z')
                    if ~isfolder(options.TempDirectory)
                        error('pds:io:DaphneWaveformReader:InvalidTempDirectory', ...
                            'Temporary directory does not exist: %s.', options.TempDirectory);
                    end
                    [~, attributes] = fileattrib(options.TempDirectory);
                    scratch = string(tempname(attributes.Name));
                    [ok, message] = mkdir(scratch);
                    if ~ok
                        error('pds:io:DaphneWaveformReader:TempFailed', '%s', message);
                    end
                    obj.ScratchDirectory = scratch;
                    member = name + ".dat";
                    dataFile = fullfile(scratch, member);
                    extractChannel(filename, member, dataFile, options.SevenZipExecutable);
                end
                [obj.FileID, message] = fopen(dataFile, 'rb', 'ieee-le');
                if obj.FileID < 0
                    error('pds:io:DaphneWaveformReader:OpenFailed', '%s', message);
                end
                if fseek(obj.FileID, 0, 'eof') ~= 0
                    error('pds:io:DaphneWaveformReader:SeekFailed', ...
                        'Cannot determine binary file size.');
                end
                byteCount = ftell(obj.FileID);
                recordBytes = 2 * sampleCount;
                if byteCount <= 0 || byteCount > flintmax || rem(byteCount, recordBytes) ~= 0
                    error('pds:io:DaphneWaveformReader:InvalidFileSize', ...
                        'File size (%g bytes) is not a positive multiple of %g bytes per waveform.', ...
                        byteCount, recordBytes);
                end
                obj.WaveformCount = byteCount / recordBytes;
            catch exception
                obj.close();
                rethrow(exception);
            end
        end

        function waveform = read(obj, index)
            %READ Return the indexed waveform as a 1-by-N uint16 row.
            arguments
                obj (1,1) pds.io.DaphneWaveformReader
                index (1,1) double {mustBeInteger, mustBePositive}
            end
            if obj.FileID < 0
                error('pds:io:DaphneWaveformReader:Closed', 'The reader is closed.');
            end
            if index > obj.WaveformCount
                error('pds:io:DaphneWaveformReader:IndexOutOfRange', ...
                    'Waveform index %g exceeds the %g available waveforms.', index, obj.WaveformCount);
            end
            waveform = obj.readBlock(index, 1);
        end

        function waveforms = readBlock(obj, index, recordCount)
            %READBLOCK Return adjacent waveforms as records-by-samples.
            arguments
                obj (1,1) pds.io.DaphneWaveformReader
                index (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
                recordCount (1,1) double {mustBeInteger, mustBePositive, mustBeFinite}
            end
            if obj.FileID < 0
                error('pds:io:DaphneWaveformReader:Closed', 'The reader is closed.');
            end
            if index > obj.WaveformCount || recordCount > obj.WaveformCount-index+1
                error('pds:io:DaphneWaveformReader:IndexOutOfRange', ...
                    'Cannot read %g waveforms from index %g with %g available.', ...
                    recordCount, index, obj.WaveformCount);
            end
            offset = (index - 1) * (2 * obj.SamplesPerWaveform);
            if fseek(obj.FileID, offset, 'bof') ~= 0
                error('pds:io:DaphneWaveformReader:SeekFailed', 'Cannot seek to waveform %g.', index);
            end
            [samples, count] = fread(obj.FileID, [obj.SamplesPerWaveform, recordCount], '*uint16');
            if count ~= obj.SamplesPerWaveform*recordCount
                error('pds:io:DaphneWaveformReader:ShortRead', ...
                    'Waveform data starting at index %g are incomplete.', index);
            end
            waveforms = samples.';
        end

        function [waveform, index] = next(obj)
            %NEXT Read the next waveform and advance the cursor on success.
            index = obj.NextIndex;
            waveform = obj.read(index);
            obj.NextIndex = index + 1;
        end

        function available = hasNext(obj)
            available = obj.FileID >= 0 && obj.NextIndex <= obj.WaveformCount;
        end

        function close(obj)
            if obj.FileID >= 0
                fclose(obj.FileID);
                obj.FileID = -1;
            end
            if strlength(obj.ScratchDirectory) > 0
                if isfolder(obj.ScratchDirectory)
                    [ok, message] = rmdir(obj.ScratchDirectory, 's');
                    if ~ok
                        warning('pds:io:DaphneWaveformReader:CleanupFailed', ...
                            'Cannot remove %s: %s', obj.ScratchDirectory, message);
                        return
                    end
                end
                obj.ScratchDirectory = "";
            end
        end

        function delete(obj)
            obj.close();
        end
    end
end

function count = acquisitionLength(folder, name)
formatFile = fullfile(folder, 'dma_format.json');
channel = regexp(name, '^channel_(\d+)$', 'tokens', 'once');
if ~isempty(channel) && isfile(formatFile)
    format = jsondecode(fileread(formatFile));
    key = matlab.lang.makeValidName(channel{1});
    if isfield(format, 'capture_contracts') && isfield(format.capture_contracts, key)
        contract = format.capture_contracts.(key);
        if isfield(contract, 'samples')
            count = contract.samples;
            return
        end
    end
end
configFile = fullfile(folder, 'config.txt');
if isfile(configFile)
    matches = regexp(fileread(configFile), ...
        '(?m)^[ \t]*waveform_length[ \t]*=[ \t]*(\d+)[ \t]*\r?$', 'tokens');
    lengths = unique(cellfun(@(match) str2double(match{1}), matches));
    if isscalar(lengths)
        count = lengths;
        return
    end
end
error('pds:io:DaphneWaveformReader:MissingLength', ...
    'Supply SamplesPerWaveform when the waveform length is unavailable in metadata.');
end

function extractChannel(archive, member, dataFile, executable)
if strlength(executable) == 0
    executable = "7z";
    if ispc
        installed = fullfile(getenv('ProgramFiles'), '7-Zip', '7z.exe');
        if isfile(installed)
            executable = string(installed);
        end
    end
end
logFile = fullfile(fileparts(dataFile), '7z-errors.txt');
command = [executable, "e", "-so", "-bsp0", "-spd", "--", archive, member];
builder = javaObject('java.lang.ProcessBuilder', javaArray('java.lang.String', 0));
for argument = command
    builder.command().add(java.lang.String(char(argument)));
end
builder.redirectOutput(java.io.File(char(dataFile)));
builder.redirectError(java.io.File(char(logFile)));
try
    process = builder.start();
catch exception
    error('pds:io:DaphneWaveformReader:SevenZipUnavailable', ...
        'Cannot start 7-Zip (%s). Set SevenZipExecutable to its path. %s', ...
        executable, exception.message);
end
cleanup = onCleanup(@() process.destroyForcibly());
process.getOutputStream().close();
status = process.waitFor();
file = dir(dataFile);
if status ~= 0 || isempty(file) || file.bytes == 0
    error('pds:io:DaphneWaveformReader:ExtractionFailed', ...
        'Cannot extract %s from %s (7-Zip exit code %d). %s', ...
        member, archive, status, strtrim(fileread(logFile)));
end
end
