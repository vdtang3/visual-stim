function key = protocolConfigKey(protocol)
%PROTOCOLCONFIGKEY Return the stable structure field for a protocol name.

key = matlab.lang.makeValidName(char(string(protocol)), ...
    'ReplacementStyle','underscore');
end
