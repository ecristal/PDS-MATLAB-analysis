function [data, metadata] = readDaphneReferenceForTest(repositoryRoot)
%READDAPHNEREFERENCEFORTEST Read the ignored channel-24 reference archive.
%   This helper is intentionally test-only. It does not replace the legacy
%   DAPHNE IO functions and extracts the .dat file only under tempdir.

    archivePath = fullfile(repositoryRoot, 'data', 'DAPHNE', 'FBK_SiPM', ...
        'vgain_1700', 'channel_24.7z');
    if ~isfile(archivePath)
        error('PDS:test:ReferenceArchiveMissing', ...
            'Reference archive not found: %s', archivePath);
    end

    sevenZipPath = 'C:\Program Files\7-Zip\7z.exe';
    if ~isfile(sevenZipPath)
        error('PDS:test:SevenZipMissing', ...
            '7-Zip executable not found: %s', sevenZipPath);
    end

    extractionDirectory = tempname;
    mkdir(extractionDirectory);
    cleanupDirectory = onCleanup(@() removeDirectory(extractionDirectory));

    listCommand = sprintf('"%s" l -slt "%s"', sevenZipPath, archivePath);
    [listStatus, listing] = system(listCommand);
    if listStatus ~= 0
        error('PDS:test:ReferenceArchiveListFailed', ...
            '7-Zip could not list the archive (status %d): %s', ...
            listStatus, listing);
    end
    pathTokens = regexp(listing, '(?m)^Path = ([^\r\n]+)', 'tokens');
    listedPaths = string(cellfun(@(token) strtrim(token{1}), ...
        pathTokens, 'UniformOutput', false));
    if numel(listedPaths) ~= 2 || listedPaths(2) ~= "channel_24.dat"
        error('PDS:test:UnexpectedReferenceArchiveContents', ...
            'The archive must contain exactly channel_24.dat and no other members.');
    end

    command = sprintf('"%s" x -y -o"%s" "%s"', ...
        sevenZipPath, extractionDirectory, archivePath);
    [status, message] = system(command);
    if status ~= 0
        error('PDS:test:ReferenceExtractionFailed', ...
            '7-Zip failed with status %d: %s', status, message);
    end

    dataPath = fullfile(extractionDirectory, 'channel_24.dat');
    expectedByteCount = 122880000;
    dataFile = dir(dataPath);
    if isempty(dataFile) || dataFile.bytes ~= expectedByteCount
        error('PDS:test:UnexpectedReferenceDataSize', ...
            'Expected %d bytes in channel_24.dat.', expectedByteCount);
    end
    fileIdentifier = fopen(dataPath, 'r', 'ieee-le');
    if fileIdentifier < 0
        error('PDS:test:ReferenceDataOpenFailed', ...
            'Unable to open extracted data: %s', dataPath);
    end
    cleanupFile = onCleanup(@() fclose(fileIdentifier));
    rawSamples = fread(fileIdentifier, Inf, 'uint16=>double');
    clear cleanupFile;

    sampleCount = 2048;
    if mod(numel(rawSamples), sampleCount) ~= 0
        error('PDS:test:ReferenceDataLength', ...
            'Raw sample count is not divisible by %d.', sampleCount);
    end
    data = reshape(rawSamples, sampleCount, []).';
    expectedRecordCount = 30000;
    if size(data, 1) ~= expectedRecordCount
        error('PDS:test:UnexpectedReferenceRecordCount', ...
            'Expected %d waveforms, found %d.', ...
            expectedRecordCount, size(data, 1));
    end

    metadata = struct( ...
        'archivePath', string(archivePath), ...
        'channel', 24, ...
        'sampleCount', sampleCount, ...
        'recordCount', size(data, 1), ...
        'samplePeriod', 16e-9, ...
        'sampleRateHz', 62.5e6, ...
        'dataType', "uint16", ...
        'machineFormat', "ieee-le", ...
        'minimumRawSample', min(rawSamples), ...
        'maximumRawSample', max(rawSamples));
end

function removeDirectory(directory)
    if isfolder(directory)
        rmdir(directory, 's');
    end
end
