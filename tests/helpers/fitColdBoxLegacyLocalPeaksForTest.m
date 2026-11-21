function result = fitColdBoxLegacyLocalPeaksForTest(scores, binWidth)
%FITCOLDBOXLEGACYLOCALPEAKSFORTEST Fit normalized 0-PE and 1-PE peaks.
%   Uses fixed normalized windows so the fallback is identical for every
%   acquisition and cannot select a different shoulder case by case.

    arguments
        scores (:, 1) double {mustBeReal, mustBeFinite}
        binWidth (1, 1) double {mustBeReal, mustBeFinite, mustBePositive}
    end

    edges = -0.5:binWidth:1.5;
    if edges(end) < 1.5
        edges(end + 1) = 1.5;
    end
    counts = histcounts(scores, edges);
    centers = edges(1:end-1) + diff(edges) / 2;
    pedestalMask = centers >= -0.45 & centers <= 0.45;
    firstPeMask = centers >= 0.60 & centers <= 1.40;
    pedestalX = centers(pedestalMask).';
    pedestalY = counts(pedestalMask).';
    firstPeX = centers(firstPeMask).';
    firstPeY = counts(firstPeMask).';

    try
        [pedestalFit, pedestalGoodness] = fit(pedestalX, pedestalY, ...
            'gauss1', 'StartPoint', [max(pedestalY), 0, 0.2], ...
            'Lower', [0, -0.3, 0.01], 'Upper', [Inf, 0.3, 1]);
        [firstPeFit, firstPeGoodness] = fit(firstPeX, firstPeY, ...
            'gauss1', 'StartPoint', [max(firstPeY), 1, 0.25], ...
            'Lower', [0, 0.65, 0.01], 'Upper', [Inf, 1.35, 1]);
        mu0 = pedestalFit.b1;
        sigma0 = abs(pedestalFit.c1) / sqrt(2);
        mu1 = firstPeFit.b1;
        sigma1 = abs(firstPeFit.c1) / sqrt(2);
        delta = mu1 - mu0;
        snr = delta / sigma0;
        pedestalCurve = feval(pedestalFit, pedestalX);
        firstPeCurve = feval(firstPeFit, firstPeX);
        observed = [pedestalY; firstPeY];
        fitted = [pedestalCurve; firstPeCurve];
        denominator = sum((observed - mean(observed)).^2);
        if denominator > 0
            rSquare = 1 - sum((observed - fitted).^2) / denominator;
        else
            rSquare = NaN;
        end
        rSquare0 = pedestalGoodness.rsquare;
        rSquare1 = firstPeGoodness.rsquare;
        completed = all(isfinite([mu0, sigma0, mu1, sigma1, delta, ...
            snr, rSquare, rSquare0, rSquare1]));
        valid = completed && delta > 0.5 && delta < 1.5 && ...
            sigma0 > 0 && sigma0 < 0.75 && rSquare0 > 0.90 && ...
            rSquare1 > 0.90 && rSquare > 0.90;
    catch
        mu0 = NaN;
        sigma0 = NaN;
        mu1 = NaN;
        sigma1 = NaN;
        delta = NaN;
        snr = NaN;
        rSquare = NaN;
        rSquare0 = NaN;
        rSquare1 = NaN;
        pedestalCurve = NaN(size(pedestalX));
        firstPeCurve = NaN(size(firstPeX));
        completed = false;
        valid = false;
    end

    result = struct( ...
        'completed', completed, 'valid', valid, ...
        'mu0', mu0, 'sigma0', sigma0, 'mu1', mu1, ...
        'sigma1', sigma1, 'delta', delta, 'snr', snr, ...
        'rSquare', rSquare, 'rSquare0', rSquare0, ...
        'rSquare1', rSquare1, 'pedestalX', pedestalX, ...
        'pedestalY', pedestalY, 'pedestalCurve', pedestalCurve, ...
        'firstPeX', firstPeX, 'firstPeY', firstPeY, ...
        'firstPeCurve', firstPeCurve);
end
