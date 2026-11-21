function value = readCalibrationNpy(filename)
%READCALIBRATIONNPY Restricted numeric/Unicode NPY reader; never evaluates headers.
file = fopen(filename, 'rb', 'ieee-le');
if file < 0
    error('pds:io:readDaqNpz:OpenFailed', 'Cannot open %s.', filename);
end
cleanup = onCleanup(@() fclose(file));
magic = fread(file, 6, '*uint8').';
version = fread(file, 2, '*uint8').';
if ~isequal(magic, uint8([147, double('NUMPY')])) || numel(version) ~= 2 || ...
        ~ismember(version(1), [1,2,3]) || version(2) ~= 0
    error('pds:io:readDaqNpz:InvalidNpy', 'Unsupported NPY header.');
end
if version(1) == 1
    headerLength = fread(file, 1, '*uint16');
else
    headerLength = fread(file, 1, '*uint32');
end
if isempty(headerLength) || headerLength > 1024*1024
    error('pds:io:readDaqNpz:InvalidNpy', 'Invalid NPY header length.');
end
header = char(fread(file, double(headerLength), '*uint8').');
descriptor = regexp(header, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
order = regexp(header, '''fortran_order''\s*:\s*(True|False)', 'tokens', 'once');
shape = regexp(header, '''shape''\s*:\s*\(([^)]*)\)', 'tokens', 'once');
if isempty(descriptor) || isempty(order) || isempty(shape) || ...
        (~isempty(strtrim(shape{1})) && ...
        isempty(regexp(shape{1}, '^\s*(\d+\s*,?\s*)*$', 'once')))
    error('pds:io:readDaqNpz:InvalidNpy', 'Malformed NPY descriptor, order or shape.');
end
dimensions = str2double(regexp(shape{1}, '\d+', 'match'));
if numel(dimensions) > 2 || any(~isfinite(dimensions) | dimensions < 1)
    error('pds:io:readDaqNpz:UnsupportedNpy', 'Only nonempty scalar/vector/matrix arrays are supported.');
end
count = prod(dimensions);
descriptor = descriptor{1};
machine = 'ieee-le';
if startsWith(descriptor, '>')
    machine = 'ieee-be';
end
switch descriptor
    case {'<u2','>u2'}
        precision = 'uint16';
    case {'<u8','>u8'}
        precision = 'uint64';
    case '|u1'
        precision = 'uint8';
    case '|b1'
        precision = 'uint8';
    otherwise
        unicode = regexp(descriptor, '^[<>]U(\d+)$', 'tokens', 'once');
        if isempty(unicode) || ~isempty(dimensions)
            error('pds:io:readDaqNpz:UnsupportedNpy', 'Unsupported NPY type: %s.', descriptor);
        end
        count = str2double(unicode{1});
        precision = 'uint32';
end
[value, actualCount] = fread(file, count, ['*', precision], 0, machine);
if actualCount ~= count || ~isempty(fread(file, 1, '*uint8'))
    error('pds:io:readDaqNpz:PayloadSize', 'NPY payload size disagrees with header.');
end
if contains(descriptor, 'U')
    if any(value > 65535 | (value >= 55296 & value <= 57343))
        error('pds:io:readDaqNpz:UnsupportedNpy', 'Metadata contains unsupported Unicode code points.');
    end
    value = char(value(value ~= 0).');
elseif strcmp(descriptor, '|b1')
    if any(value > 1)
        error('pds:io:readDaqNpz:InvalidNpy', 'Invalid boolean payload.');
    end
    value = logical(value);
end
if numel(dimensions) == 2
    if strcmp(order{1}, 'True')
        value = reshape(value, dimensions);
    else
        value = reshape(value, fliplr(dimensions)).';
    end
end
end
