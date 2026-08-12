function correctedWaveforms = subtractPedestal(waveforms, pedestalLevel)
%SUBTRACTPEDESTAL Subtract known pedestal levels without re-estimation.
%
% Rows are events and columns are samples. Integer inputs are converted to
% double before subtraction to avoid underflow or wrap.

arguments
    waveforms {mustBeNumeric, mustBeReal, mustBeFinite}
    pedestalLevel {mustBeNumeric, mustBeReal, mustBeFinite}
end

if isempty(waveforms) || ~ismatrix(waveforms)
    error('pds:preprocess:subtractPedestal:InvalidWaveforms', ...
        'Waveforms must be a nonempty two-dimensional numeric array.');
end
if iscolumn(waveforms) && numel(waveforms) > 1
    error('pds:preprocess:subtractPedestal:AmbiguousColumnVector', ...
        ['A column vector is ambiguous under the events-by-samples ' ...
        'contract; provide one waveform as a row vector.']);
end
if hasInexactIntegerValues(waveforms)
    error('pds:preprocess:subtractPedestal:InexactIntegerConversion', ...
        'Integer waveform values must be within the exact double range.');
end
if hasInexactIntegerValues(pedestalLevel)
    error('pds:preprocess:subtractPedestal:InexactIntegerConversion', ...
        'Integer pedestal levels must be within the exact double range.');
end
if isvector(waveforms)
    waveforms = reshape(waveforms, 1, []);
end
waveforms = double(waveforms);
if ~isscalar(pedestalLevel) && ~isvector(pedestalLevel)
    error('pds:preprocess:subtractPedestal:InvalidPedestalLevel', ...
        'Pedestal levels must be scalar or a one-dimensional vector.');
end
pedestalLevel = double(pedestalLevel(:));

if isscalar(pedestalLevel)
    pedestalLevel = repmat(pedestalLevel, size(waveforms, 1), 1);
elseif numel(pedestalLevel) ~= size(waveforms, 1)
    error('pds:preprocess:subtractPedestal:LevelCountMismatch', ...
        'Pedestal levels must be scalar or provide one value per waveform.');
end

correctedWaveforms = waveforms - pedestalLevel;
end

function tf = hasInexactIntegerValues(value)
if isa(value, 'uint64')
    tf = any(value(:) > uint64(flintmax));
elseif isa(value, 'int64')
    limit = int64(flintmax);
    tf = any(value(:) > limit | value(:) < -limit);
else
    tf = false;
end
end
