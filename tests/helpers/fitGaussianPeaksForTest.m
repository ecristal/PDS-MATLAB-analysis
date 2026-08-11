function result = fitGaussianPeaksForTest(scores)
%FITGAUSSIANPEAKSFORTEST Fit pedestal and 1-PE peaks for integration tests.
%   Peak discovery delegates to the existing legacy helper
%   find_peaks_hist_adaptive. Individual bounded gauss1 fits are kept here
%   because gaussian_fit_SNR has hard-coded three-Gaussian assumptions.

    scores = scores(:);
    if numel(scores) < 100 || any(~isfinite(scores))
        error('PDS:test:InvalidHistogramScores', ...
            'At least 100 finite scores are required.');
    end

    lowerLimit = prctile(scores, 0.2);
    upperLimit = prctile(scores, 99.5);
    binCount = 500;
    edges = linspace(lowerLimit, upperLimit, binCount + 1);
    counts = histcounts(scores, edges);
    centers = (edges(1:end-1) + edges(2:end)) / 2;

    [locations, heights] = find_peaks_hist_adaptive(centers, counts, ...
        'Smoother', "sgolay", 'SmoothWindow', 9, ...
        'MinProminenceFrac', 0.015, 'MinPeakWidthBins', 2, ...
        'MinSepFactor', 0.55, 'MinSepMinBins', 8);
    [locations, order] = sort(locations);
    locations = locations(:).';
    heights = heights(order);
    heights = heights(:).';
    prominent = heights > 0.03 * max(heights);
    locations = locations(prominent);
    heights = heights(prominent);
    if numel(locations) < 2
        error('PDS:test:InsufficientHistogramPeaks', ...
            'Fewer than two prominent histogram peaks were found.');
    end

    [~, pedestalIndex] = min(abs(locations));
    onePeIndex = find((1:numel(locations)) > pedestalIndex & ...
        locations > locations(pedestalIndex), 1, 'first');
    if isempty(onePeIndex)
        error('PDS:test:MissingOnePePeak', ...
            'No photoelectron peak was found to the right of the pedestal.');
    end

    approximateMu0 = locations(pedestalIndex);
    approximateMu1 = locations(onePeIndex);
    spacing = approximateMu1 - approximateMu0;
    if spacing <= 0
        error('PDS:test:InvalidPeakSpacing', 'Peak spacing must be positive.');
    end

    pedestalFit = fitOnePeak(centers, counts, approximateMu0, spacing);
    onePeFit = fitOnePeak(centers, counts, approximateMu1, spacing);
    mu0 = pedestalFit.b1;
    sigma0 = abs(pedestalFit.c1) / sqrt(2);
    mu1 = onePeFit.b1;
    sigma1 = abs(onePeFit.c1) / sqrt(2);

    evaluationAxis = linspace(approximateMu0 - spacing, ...
        approximateMu1 + spacing, 1000);
    result = struct( ...
        'mu0', mu0, ...
        'sigma0', sigma0, ...
        'mu1', mu1, ...
        'sigma1', sigma1, ...
        'delta', mu1 - mu0, ...
        'snr', (mu1 - mu0) / sigma0, ...
        'binCenters', centers, ...
        'binCounts', counts, ...
        'binWidth', edges(2) - edges(1), ...
        'peakLocations', locations, ...
        'peakHeights', heights, ...
        'evaluationAxis', evaluationAxis, ...
        'pedestalCurve', pedestalFit(evaluationAxis), ...
        'onePeCurve', onePeFit(evaluationAxis), ...
        'method', "legacy peak finder + bounded gauss1 fits");
end

function fittedPeak = fitOnePeak(centers, counts, approximateCenter, spacing)
    fitMask = centers > approximateCenter - 0.42 * spacing & ...
        centers < approximateCenter + 0.42 * spacing;
    if sum(fitMask) < 5
        error('PDS:test:InsufficientPeakBins', ...
            'Too few histogram bins are available for Gaussian fitting.');
    end

    options = fitoptions('gauss1');
    options.StartPoint = [max(counts(fitMask)), approximateCenter, spacing / 3];
    options.Lower = [0, approximateCenter - 0.25 * spacing, eps];
    options.Upper = [Inf, approximateCenter + 0.25 * spacing, spacing];
    fittedPeak = fit(centers(fitMask).', counts(fitMask).', 'gauss1', options);
end
