function [f, P1, Y, Pc1, rms_] = f_fourier(senhal, Tm, do_plot, y_label, normalize)
% f_fourier
% FFT + single-sided amplitude spectrum + single-sided PSD + RMS from PSD
%
% Inputs:
%   senhal  : [A x L] (A records, L samples) or [1 x L]
%   Tm      : sampling period [s]
%   do_plot : boolean
%   y_label : "abs" or "dBFS"
%
% Outputs:
%   f    : frequency vector for single-sided spectra [1 x (floor(L/2)+1)]
%   P1   : single-sided amplitude spectrum (avg across records if A>1)
%   Y    : complex FFT (avg across records if A>1) [1 x L]
%   Pc1  : single-sided PSD (avg across records if A>1) [1 x (floor(L/2)+1)]
%   rms_ : RMS per record from Pc1 integration [1 x A]

[A, L] = size(senhal);

Fs = 1 / Tm;
Nhalf = floor(L/2);
f = Fs * (0:Nhalf) / L;
df = Fs / L;

rms_ = zeros(1, A);

% Accumulators for averaging when A > 1
avg_P1  = zeros(1, Nhalf + 1);
avg_Y   = zeros(1, L);
avg_Pc1 = zeros(1, Nhalf + 1);

for i = 1:A
    x = senhal(i, :);

    % If you want to remove DC before spectra, uncomment:
    % x = x - mean(x);

    Yi = fft(x);

    % ---------- Single-sided amplitude spectrum ----------
    P2 = abs(Yi) / L;                 % two-sided amplitude
    P1i = P2(1:Nhalf+1);              % keep [0..Fs/2]
    if Nhalf >= 1
        P1i(2:end-1) = 2 * P1i(2:end-1);
    end

    % ---------- Single-sided PSD ----------
    % Two-sided periodogram PSD:
    Pc2 = (abs(Yi).^2) / (L * Fs);    % length L, real-valued
    Pc1i = Pc2(1:Nhalf+1);
    if Nhalf >= 1
        Pc1i(2:end-1) = 2 * Pc1i(2:end-1);
    end

    % Optional: remove DC contribution from RMS integration
    Pc1i(1) = 0;

    % RMS from PSD integral
    rms_(i) = sqrt(trapz(Pc1i) * df);

    % Accumulate for averages
    avg_P1  = avg_P1  + P1i;
    avg_Y   = avg_Y   + Yi;
    avg_Pc1 = avg_Pc1 + Pc1i;
end

% Average outputs (if only one record, this is the same)
P1  = avg_P1  / A;
Y   = avg_Y   / A;
Pc1 = avg_Pc1 / A;

% ---------- Output scaling for plot label ----------
if strcmp(y_label, "abs")
    y_label_text = "|A(f)|";
elseif strcmp(y_label, "dBFS")
    % NOTE: This assumes a 14-bit full-scale reference (2^14).
    % Adjust to your ADC full-scale definition if needed.
    P1 = 20 * log10(P1 ./ 2^14);
    y_label_text = "dBFS";
else
    error("Bad argument y_label: must be abs or dBFS.");
end

% ---------- Plot ----------
if do_plot
    figure(3);
    if(normalize)
        P1 = P1/max(P1);
        semilogx(f, 20*log10(P1));
    else
        semilogx(f, P1);
    end
    title('Single-Sided Amplitude Spectrum of X(t)', 'Interpreter','latex','FontSize',14);
    xlabel('f [Hz]', 'Interpreter','latex','FontSize',12);
    ylabel(y_label_text, 'Interpreter','latex','FontSize',12);
    grid on;
end

end