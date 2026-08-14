classdef TestPlotTransferFunctionEstimate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceDirectory = fullfile(repositoryRoot, 'src');
            addpath(sourceDirectory);
            testCase.addTeardown(@() rmpath(sourceDirectory));
        end
    end

    methods (Test)
        function createsInvisibleReviewFigureForMultipleModels(testCase)
            target = [zeros(1, 5), 1, 0.5, -0.2, -0.1, zeros(1, 11)];
            predictions = [target; 0.9 * target];
            [figureHandle, axesHandles] = ...
                pds.plotting.plotTransferFunctionEstimate( ...
                target, predictions, SampleTime=16e-9, ...
                ModelLabels=["direct discrete", "continuous c2d"], ...
                TrainingSampleCount=12, TailStartIndex=8, ...
                Visible="off", Title="synthetic review");
            cleanup = onCleanup(@() close(figureHandle));

            testCase.verifyEqual(string(figureHandle.Visible), "off");
            testCase.verifyNumElements(axesHandles, 3);
            testCase.verifyEqual(figureHandle.Name, 'synthetic review');
            for axisHandle = axesHandles(:).'
                testCase.verifyGreaterThanOrEqual(numel(axisHandle.Children), 3);
            end
        end

        function rejectsInexactIntegerSignalsAndOptions(testCase)
            unsafe = uint64(flintmax) + uint64(2);
            testCase.verifyError(@() ...
                pds.plotting.plotTransferFunctionEstimate( ...
                [uint64(0), unsafe], [0, 1], SampleTime=1, Visible="off"), ...
                'pds:plotting:plotTransferFunctionEstimate:InvalidSignals');
            testCase.verifyError(@() ...
                pds.plotting.plotTransferFunctionEstimate( ...
                [0, 1], [0, 1], SampleTime=unsafe, Visible="off"), ...
                'pds:plotting:plotTransferFunctionEstimate:InvalidSampleTime');
        end
    end
end
