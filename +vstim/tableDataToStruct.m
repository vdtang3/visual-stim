function s = tableDataToStruct(data, template)
%TABLEDATATOSTRUCT Parse GUI rows using types from a template structure.
s = template;
for i = 1:size(data,1)
    name = char(string(data{i,1}));
    if ~isfield(template, name)
        continue
    end
    text = strtrim(string(data{i,2}));
    original = template.(name);
    if islogical(original)
        if any(strcmpi(text, ["true", "on", "yes", "1"]))
            value = true;
        elseif any(strcmpi(text, ["false", "off", "no", "0"]))
            value = false;
        else
            error('vstim:InvalidLogical', '%s must be true or false.', name)
        end
    elseif isnumeric(original)
        value = str2num(char(text)); %#ok<ST2NM>
        if isempty(value) && text ~= "[]"
            error('vstim:InvalidNumericValue', ...
                '%s must be a numeric scalar or array.', name)
        end
    elseif isstring(original)
        if startsWith(text, "[")
            tokens = regexp(char(text), '"([^"]*)"', 'tokens');
            value = string([tokens{:}]);
        else
            value = text;
        end
    elseif ischar(original)
        value = char(text);
    else
        error('vstim:UnsupportedConfigValue', ...
            'Cannot parse field %s of class %s.', name, class(original))
    end
    s.(name) = value;
end
end
