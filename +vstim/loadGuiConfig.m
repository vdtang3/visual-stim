function [cfg, protocolConfigs] = loadGuiConfig(filename)
%LOADGUICONFIG Load GUI configurations, including all saved protocols.

protocolConfigs = struct;

if ~isfile(filename)
    error('vstim:ConfigNotFound', 'Configuration file not found: %s', filename)
end
[~,~,extension] = fileparts(filename);
if strcmpi(extension, '.json')
    descriptor = jsondecode(fileread(filename));
    if isfield(descriptor, 'useBuiltInDefaults') && ...
            descriptor.useBuiltInDefaults
        cfg = vstim.defaultConfig(string(descriptor.activeProtocol));
        protocolConfigs.(vstim.protocolConfigKey(cfg.protocol)) = cfg;
        return
    end
    error('vstim:InvalidGuiConfig', ...
        'JSON file is not a supported visual-stimulus configuration.')
end

s = load(filename, 'guiConfig');
if ~isfield(s, 'guiConfig') || ~isfield(s.guiConfig, 'cfg')
    error('vstim:InvalidGuiConfig', ...
        'File does not contain a saved visual-stimulus GUI configuration.')
end
if isfield(s.guiConfig,'platform') && ...
        ~strcmpi(string(s.guiConfig.platform),string(computer))
    error('vstim:ConfigPlatformMismatch', ...
        ['This configuration was saved on %s and contains machine-specific ' ...
         'display, serial-port, and folder settings. Use a configuration ' ...
         'saved on this %s machine.'], ...
        string(s.guiConfig.platform),string(computer))
end
cfg = s.guiConfig.cfg;
if ispc && ~isfield(s.guiConfig,'platform') && ...
        (startsWith(string(cfg.sync.port),"/") || ...
        startsWith(string(cfg.session.outputDirectory),"/"))
    error('vstim:ConfigPlatformMismatch', ...
        ['This older configuration contains Unix paths or serial ports. ' ...
         'Save a new configuration after running installVisualStim on Windows.'])
end

% Add session fields introduced after this configuration was saved. This
% keeps newly added controls visible when the GUI autoloads an older file.
currentDefaults = vstim.defaultConfig(string(cfg.protocol));
displayFields = fieldnames(currentDefaults.display);
for i = 1:numel(displayFields)
    name = displayFields{i};
    if ~isfield(cfg.display,name)
        cfg.display.(name) = currentDefaults.display.(name);
    end
end
sessionFields = fieldnames(currentDefaults.session);
% Older configurations stored the exact folder to search. Convert a dated
% yyyyMMdd folder back to its parent; otherwise treat the old value as the
% parent itself.
if ~isfield(cfg.session,'wavesurferParentDirectory') && ...
        isfield(cfg.session,'wavesurferSearchDirectory')
    oldDirectory = string(cfg.session.wavesurferSearchDirectory);
    [oldParent,oldLeaf] = fileparts(oldDirectory);
    if ~isempty(regexp(char(oldLeaf),'^\d{8}$','once'))
        cfg.session.wavesurferParentDirectory = string(oldParent);
    else
        cfg.session.wavesurferParentDirectory = oldDirectory;
    end
end
if isfield(cfg.session,'wavesurferSearchDirectory')
    cfg.session = rmfield(cfg.session,'wavesurferSearchDirectory');
end
for i = 1:numel(sessionFields)
    name = sessionFields{i};
    if ~isfield(cfg.session, name)
        cfg.session.(name) = currentDefaults.session.(name);
    end
end

if cfg.protocol == "Fast Gabor tiling"
    % Migrate configurations saved before drifting Gabors became the
    % default. Preserve their numeric temporal frequency while replacing
    % the obsolete counterphase-only field.
    if isfield(cfg.stimulus, 'counterphaseFrequencyHz') && ...
            ~isfield(cfg.stimulus, 'temporalFrequencyHz')
        cfg.stimulus.temporalFrequencyHz = ...
            cfg.stimulus.counterphaseFrequencyHz;
    end
    if isfield(cfg.stimulus, 'counterphaseFrequencyHz')
        cfg.stimulus = rmfield(cfg.stimulus, 'counterphaseFrequencyHz');
    end
    cfg.stimulus.temporalModulation = "drifting";
    if ~isfield(cfg.stimulus, 'temporalFrequencyHz')
        cfg.stimulus.temporalFrequencyHz = 2;
    end
    % Gaussian-windowed Gabors were replaced by paper-style circular
    % grating patches with a locally blurred edge.
    if isfield(cfg.stimulus, 'sigmaDeg')
        cfg.stimulus = rmfield(cfg.stimulus, 'sigmaDeg');
    end
    if isfield(cfg.stimulus, 'aspectRatio')
        cfg.stimulus = rmfield(cfg.stimulus, 'aspectRatio');
    end
    if ~isfield(cfg.stimulus, 'edgeBlurDeg')
        cfg.stimulus.edgeBlurDeg = 10;
    end
end
if cfg.protocol == "Sparse noise" && ...
        ~isfield(cfg.stimulus, 'gridCoordinateMode')
    cfg.stimulus.gridCoordinateMode = "constant_degrees";
    % The degree-uniform grid has a different aspect ratio from the legacy
    % pixel grid; a distance of four cannot place six simultaneous tiles
    % on common monitor geometries.
    cfg.stimulus.minimumGridDistance = min( ...
        cfg.stimulus.minimumGridDistance, 3);
end
if cfg.protocol == "Gabor + inverse stimuli" && ...
        ~isfield(cfg.stimulus,'inverseDiameterDeg')
    % Older configurations used diameterDeg for both apertures.
    cfg.stimulus.inverseDiameterDeg = cfg.stimulus.diameterDeg;
end
if cfg.protocol == "Targeted Gabor grid" && ...
        isfield(cfg.stimulus, 'centerPixelX')
    cfg.stimulus.centerAzimuthDeg = cfg.display.azimuthLimitsDeg(1) + ...
        cfg.stimulus.centerPixelX/cfg.display.resolutionPx(1) * ...
        diff(cfg.display.azimuthLimitsDeg);
    cfg.stimulus.centerElevationDeg = cfg.display.elevationLimitsDeg(2) - ...
        cfg.stimulus.centerPixelY/cfg.display.resolutionPx(2) * ...
        diff(cfg.display.elevationLimitsDeg);
    cfg.stimulus.gridSpacingDeg = cfg.stimulus.gridSpacingPx ./ ...
        cfg.display.resolutionPx .* ...
        [diff(cfg.display.azimuthLimitsDeg), ...
        diff(cfg.display.elevationLimitsDeg)];
    cfg.stimulus = rmfield(cfg.stimulus, ...
        {'centerPixelX', 'centerPixelY', 'gridSpacingPx'});
end
cfg = vstim.normalizeDisplayGeometry(cfg);
cfg = vstim.clampMappingRegion(cfg);
vstim.validateConfig(cfg);

% Version 1 files contain only cfg. Version 2 files retain one configuration
% per protocol while cfg remains present for compatibility with older code.
if isfield(s.guiConfig,'protocolConfigs')
    savedConfigs = s.guiConfig.protocolConfigs;
    names = fieldnames(savedConfigs);
    for i = 1:numel(names)
        savedCfg = savedConfigs.(names{i});
        if string(savedCfg.protocol) == cfg.protocol
            protocolConfigs.(names{i}) = cfg;
        else
            protocolConfigs.(names{i}) = migrateSavedConfig(savedCfg, filename);
        end
    end
end
protocolConfigs.(vstim.protocolConfigKey(cfg.protocol)) = cfg;
end

function cfg = migrateSavedConfig(savedCfg, sourceFilename)
% Reuse the public version-1 migration path for each stored protocol.

guiConfig.schemaVersion = "1.0.0";
guiConfig.platform = string(computer);
guiConfig.cfg = savedCfg;
temporaryFile = [tempname '.mat'];
cleanup = onCleanup(@() deleteIfPresent(temporaryFile));
save(temporaryFile,'guiConfig');
cfg = vstim.loadGuiConfig(temporaryFile);
if isempty(cfg)
    error('vstim:InvalidGuiConfig', ...
        'Could not load a protocol configuration from %s.', sourceFilename)
end
end

function deleteIfPresent(filename)
if isfile(filename)
    delete(filename)
end
end
