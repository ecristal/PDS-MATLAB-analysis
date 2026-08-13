function [model, diagnostics] = estimateDiscreteTransferFunction( ...
        inputSignal, outputSignal, options)
%ESTIMATEDISCRETETRANSFERFUNCTION Identify a stable SISO IIR in z^-1.
%   The model is identified directly in discrete time. It is not obtained
%   by discretizing a continuous-time model.

    arguments
        inputSignal
        outputSignal
        options.SampleTime = []
        options.MaxOrder = 6
        options.DelayRange = 0
        options.FitTolerance = 0.5
        options.SelectionCriterion = "parsimonious-fit"
    end

    [model, diagnostics] = estimateTransferFunctionCore( ...
        inputSignal, outputSignal, "discrete", ...
        "estimateDiscreteTransferFunction", options);
end
