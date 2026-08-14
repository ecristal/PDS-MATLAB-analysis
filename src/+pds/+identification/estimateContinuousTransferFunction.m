function [model, diagnostics] = estimateContinuousTransferFunction( ...
        inputSignal, outputSignal, options)
%ESTIMATECONTINUOUSTRANSFERFUNCTION Identify a stable SISO model in s.
%   The search evaluates one numerator structure per pole order:
%   zeroOrder = max(0,poleOrder-1). DelayRange is expressed in samples and
%   applied with zero padding, never circular wrapping.

    arguments
        inputSignal
        outputSignal
        options.SampleTime = []
        options.MaxOrder = 6
        options.DelayRange = 0
        options.FitTolerance = 0.5
        options.SelectionCriterion = "parsimonious-fit"
        options.TrainingSampleCount = []
    end

    [model, diagnostics] = estimateTransferFunctionCore( ...
        inputSignal, outputSignal, "continuous", ...
        "estimateContinuousTransferFunction", options);
end
