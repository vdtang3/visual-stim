function filename = saveGuiConfig(cfg)
%SAVEGUICONFIG Save the complete current GUI configuration.
% MAT format preserves Inf, empty arrays, strings, and numeric types without
% the lossy conversions that JSON applies to these values.

vstim.validateConfig(vstim.normalizeDisplayGeometry(cfg));
guiConfig.schemaVersion = "1.0.0";
guiConfig.savedAt = datetime('now');
guiConfig.platform = string(computer);
guiConfig.matlabRelease = string(version('-release'));
guiConfig.cfg = cfg;

protocolSlug = lower(regexprep(char(cfg.protocol), '[^a-zA-Z0-9]+', '_'));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
filename = fullfile(vstim.configDirectory, sprintf( ...
    '%s_%s.mat', stamp, protocolSlug));
save(filename, 'guiConfig');
end
