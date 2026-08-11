function waveform = mi_idtft(coefficients)
%MI_IDTFT Deprecated compatibility wrapper for pds.signal.inverseDft.
%   The historical function name referred to an inverse DTFT, but its
%   implementation was the finite inverse DFT. The corrected API is
%   pds.signal.inverseDft.

    warning('PDS:mi_idtft:Deprecated', ...
        'mi_idtft is deprecated. Use pds.signal.inverseDft instead.');
    waveform = pds.signal.inverseDft(coefficients);
end
