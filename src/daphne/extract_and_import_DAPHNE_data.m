function [data,mean_data,Tm] = extract_and_import_DAPHNE_data( ...
    ch, waveforms_length, filename, data_format, data_type, endianess, save_mat)

    filename = string(filename);

    % ---- Determine extension(s) robustly ----
    [~, baseName, ext] = fileparts(filename);   % ext is last extension (e.g. ".gz", ".dat", ".7z")

    extract7z = false;
    extractGz = false;

    if strcmpi(ext, ".7z")
        extract7z = true;
        extract = true;
        tempDat = ""; % will be "channel_#.dat" after extraction (your current convention)

    elseif strcmpi(ext, ".dat")
        extract = false;
        tempDat = ""; % not needed

    elseif strcmpi(ext, ".gz")
        % Could be "...dat.gz" or "...something.gz" — we assume it becomes a .dat after gunzip
        extractGz = true;
        extract = true;

        % gunzip output name:
        % If input is "...channel_12.dat.gz", gunzip produces "...channel_12.dat" in same folder by default.
        tempDat = fullfile(fileparts(filename), baseName);  % baseName is "channel_12.dat"
        % (If filename ends with ".gz", baseName includes ".dat" already when it's ".dat.gz")

    else
        error("error::extract_and_import_DAPHNE_data::Invalid file extension. Valid extensions are .dat, .gz(.dat.gz), and .7z.");
    end

    % ---- Extract if needed ----
    if extract7z
        filename_ = char(filename);
        extract_command = ['"C:\Program Files\7-Zip\7z.exe" -y e ', filename_];
        system(extract_command);  % join() not needed

        % Your downstream importer expects channel_#.dat in current folder
        tempDat = "channel_" + string(ch) + ".dat";

    elseif extractGz
        % Decompress .gz to same folder (or specify output folder if you want)
        gunzip(filename,pwd); % creates tempDat
        % If needed, you can verify:
        if ~isfile(tempDat)
            % Sometimes gunzip writes to current folder if path is relative; fall back:
            alt = fullfile(pwd, baseName);
            if isfile(alt)
                tempDat = alt;
            else
                error("error::extract_and_import_DAPHNE_data::gunzip did not produce expected output file.");
            end
        end
    end

    % ---- Import data ----
    % IMPORTANT: pass the file you want imported:
    % - if not extracting -> original filename
    % - if extracting -> extracted .dat
    if extract
        fileToImport = tempDat;
    else
        fileToImport = filename;
    end

    [data, mean_data, Tm] = import_data_daphne_func( ...
        ch, waveforms_length, data_format, data_type, endianess, save_mat, extract, fileToImport);

    % ---- Cleanup extracted temp .dat ----
    if extract
        % For .7z case you previously deleted channel_#.dat; keep same behavior
        if isfile(fileToImport)
            delete(fileToImport);
        end
    end
end

