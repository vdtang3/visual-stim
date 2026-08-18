function filename = saveGuiConfig(cfg, protocolConfigs)
%SAVEGUICONFIG Save the complete GUI configuration for every protocol.
% MAT format preserves Inf, empty arrays, strings, and numeric types without
% the lossy conversions that JSON applies to these values.

if nargin < 2 || isempty(protocolConfigs)
    protocolConfigs = struct;
end
cfg = vstim.normalizeDisplayGeometry(cfg);
vstim.validateConfig(cfg);
protocolConfigs.(vstim.protocolConfigKey(cfg.protocol)) = cfg;

names = fieldnames(protocolConfigs);
for i = 1:numel(names)
    % Rig and session settings are intentionally common to every protocol.
    protocolConfigs.(names{i}).display = cfg.display;
    protocolConfigs.(names{i}).sync = cfg.sync;
    protocolConfigs.(names{i}).session = cfg.session;
    protocolConfigs.(names{i}).analysis = cfg.analysis;
    protocolConfigs.(names{i}) = vstim.normalizeDisplayGeometry( ...
        protocolConfigs.(names{i}));
    vstim.validateConfig(protocolConfigs.(names{i}));
end

guiConfig.schemaVersion = "2.0.0";
guiConfig.savedAt = datetime('now');
guiConfig.platform = string(computer);
guiConfig.matlabRelease = string(version('-release'));
guiConfig.cfg = cfg;
guiConfig.activeProtocol = cfg.protocol;
guiConfig.protocolConfigs = protocolConfigs;

protocolSlug = lower(regexprep(char(cfg.protocol), '[^a-zA-Z0-9]+', '_'));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
filename = fullfile(vstim.configDirectory, sprintf( ...
    '%s_%s.mat', stamp, protocolSlug));
save(filename, 'guiConfig');
end
