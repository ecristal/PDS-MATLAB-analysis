function enabled = scanUsesNotch(pipeline)
%SCANUSESNOTCH Read the SPE notch setting, including archived runs.
enabled = ~isfield(pipeline,'useNotch') || pipeline.useNotch;
end
