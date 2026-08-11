function waveform = inverseDft(coefficients, options)
%INVERSEDFT Compute the inverse discrete Fourier transform.
%   WAVEFORM = pds.signal.inverseDft(COEFFICIENTS) returns the complex IFFT
%   in canonical row-vector form.
%
%   WAVEFORM = pds.signal.inverseDft(..., RealOutput=true) verifies that the
%   coefficients are Hermitian within a floating-point tolerance before
%   returning an explicitly real waveform.

    arguments
        coefficients
        options.RealOutput = false
    end

    if ~isnumeric(coefficients) || ~isvector(coefficients) || isempty(coefficients)
        error('pds:signal:inverseDft:CoefficientDimensions', ...
            'Coefficients must be a nonempty numeric vector.');
    end
    if numel(coefficients) < 2
        error('pds:signal:inverseDft:TooFewBins', ...
            'At least two DFT bins are required.');
    end
    if any(~isfinite(coefficients(:)))
        error('pds:signal:inverseDft:NonfiniteCoefficients', ...
            'DFT coefficients must be finite.');
    end
    if ~(islogical(options.RealOutput) && isscalar(options.RealOutput))
        error('pds:signal:inverseDft:InvalidRealOutput', ...
            'RealOutput must be a logical scalar.');
    end

    coefficients = coefficients(:).';
    if options.RealOutput
        mirrored = conj(coefficients([1, end:-1:2]));
        scale = max(1, max(abs(coefficients)));
        tolerance = 100 * eps(scale) * numel(coefficients);
        if max(abs(coefficients - mirrored)) > tolerance
            error('pds:signal:inverseDft:NonHermitianSpectrum', ...
                'RealOutput requires a Hermitian spectrum in FFT order.');
        end
        waveform = real(ifft(coefficients));
    else
        waveform = ifft(coefficients);
    end
end
