function text = valueToText(value)
%VALUETOTEXT Make a readable, round-trippable GUI representation.
if isstring(value)
    if isscalar(value)
        text = char(value);
    else
        text = char("[" + join('"' + value(:)' + '"', ' ') + "]");
    end
elseif ischar(value)
    text = value;
elseif isnumeric(value) || islogical(value)
    text = mat2str(value);
elseif isempty(value)
    text = "[]";
else
    error('vstim:UnsupportedConfigValue', ...
        'Cannot display values of class %s.', class(value))
end
end
