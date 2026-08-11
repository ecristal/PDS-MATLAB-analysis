function window = createWindow(sampleCount, windowSpecification, options)
%CREATEWINDOW Create a validated window for spectral estimation.
%   WINDOW = pds.signal.createWindow(N, TYPE) supports "rectangular",
%   "tukey", "hann", and "hamming". A numeric vector can be supplied as
%   TYPE to use custom coefficients without an external toolbox.
%
%   TukeyRatio is the tapered fraction in [0,1]. Zero is rectangular and
%   one is equivalent to a Hann window.

    arguments
        sampleCount
        windowSpecification = "rectangular"
        options.TukeyRatio = 0.1
    end

    if ~isnumeric(sampleCount) || ~isscalar(sampleCount) || ...
            ~isreal(sampleCount) || ~isfinite(sampleCount) || ...
            sampleCount < 2 || sampleCount ~= fix(sampleCount)
        error('pds:signal:createWindow:InvalidSampleCount', ...
            'Sample count must be an integer scalar of at least two.');
    end
    if ~isnumeric(options.TukeyRatio) || ~isscalar(options.TukeyRatio) || ...
            ~isreal(options.TukeyRatio) || ~isfinite(options.TukeyRatio) || ...
            options.TukeyRatio < 0 || options.TukeyRatio > 1
        error('pds:signal:createWindow:InvalidTukeyRatio', ...
            'TukeyRatio must be a finite scalar in [0,1].');
    end

    sampleCount = double(sampleCount);
    tukeyRatio = double(options.TukeyRatio);

    if isnumeric(windowSpecification)
        if ~isvector(windowSpecification) || numel(windowSpecification) ~= sampleCount
            error('pds:signal:createWindow:WindowLength', ...
                'A custom window must contain exactly N coefficients.');
        end
        window = double(windowSpecification(:).');
        if ~isreal(window) || any(~isfinite(window)) || sum(window.^2) == 0
            error('pds:signal:createWindow:InvalidWindow', ...
                'Custom window coefficients must be finite, real, and have nonzero energy.');
        end
        return;
    end

    if ~(isstring(windowSpecification) && isscalar(windowSpecification)) && ...
            ~(ischar(windowSpecification) && isrow(windowSpecification))
        error('pds:signal:createWindow:UnknownWindow', ...
            'Window must be a supported name or a numeric vector.');
    end

    windowName = lower(string(windowSpecification));
    n = 0:(sampleCount - 1);
    switch windowName
        case {"rectangular", "none"}
            window = ones(1, sampleCount);
        case "hann"
            window = 0.5 - 0.5 * cos(2 * pi * n / (sampleCount - 1));
        case "hamming"
            window = 0.54 - 0.46 * cos(2 * pi * n / (sampleCount - 1));
        case "tukey"
            alpha = tukeyRatio;
            if alpha == 0
                window = ones(1, sampleCount);
            elseif alpha == 1
                window = 0.5 - 0.5 * cos(2 * pi * n / (sampleCount - 1));
            else
                x = n / (sampleCount - 1);
                window = ones(1, sampleCount);
                left = x < alpha / 2;
                right = x > 1 - alpha / 2;
                window(left) = 0.5 * (1 + cos(pi * (2 * x(left) / alpha - 1)));
                window(right) = 0.5 * (1 + cos(pi * ...
                    (2 * x(right) / alpha - 2 / alpha + 1)));
            end
        otherwise
            error('pds:signal:createWindow:UnknownWindow', ...
                'Unknown window type "%s".', windowName);
    end
end
