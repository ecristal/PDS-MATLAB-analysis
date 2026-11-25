function module = scanModuleName(folder)
%SCANMODULENAME Identify the module in scan and timestamped result paths.
[~,module] = fileparts(regexprep(folder,'[\\/]+$',''));
prefix = regexp(char(module),'^M[0-9]+(?=_|$)','match','once');
if ~isempty(prefix)
    module = string(prefix);
end
end
