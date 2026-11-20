function value = readAcquisitionParameter(config,key)
%READACQUISITIONPARAMETER Read a required key=value field.
token = regexp(config,"(?m)^"+key+"=([^\r\n]+)\r?$",'tokens','once');
assert(~isempty(token),'Missing acquisition configuration field %s.',key);
value = string(strtrim(token{1}));
end
