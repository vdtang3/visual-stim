function cfg = defaultConfig(protocol)
%DEFAULTCONFIG Return all adjustable defaults for a mapping protocol.

if nargin < 1
    protocol = "Moving bars";
end

cfg.schemaVersion = "1.0.0";
cfg.protocol = string(protocol);

% Visual display and mapped field. Azimuth increases to the right and
% elevation increases upward. Screen center is the origin by default.
cfg.display.screenNumber = [];
cfg.display.backgroundGray = 0.5;
cfg.display.whiteLevel = 1;
cfg.display.blackLevel = 0;
cfg.display.viewingDistanceCm = 9;
cfg.display.monitorWidthCm = 52.7;
cfg.display.monitorHeightCm = 29.6;
cfg.display.resolutionPx = [1920 1080];
cfg.display.monitorCenterXcm = 0;
cfg.display.monitorCenterYcm = 0;
cfg.display.monitorCenterAzimuthDeg = 0;
cfg.display.monitorCenterElevationDeg = 0;
cfg.display.monitorHorizontalDistanceCm = 9;
cfg.display.monitorForwardDistanceCm = 9;
cfg.display.azimuthLimitsDeg = atand([-52.7/2, 52.7/2] / 9);
cfg.display.elevationLimitsDeg = atand([-29.6/2, 29.6/2] / 9);
cfg.display.skipSyncTests = false;
cfg.display.geometryCorrectionEnabled = false;
cfg.display.geometryCalibrationFile = "";

% Arduino serial-to-TTL adapter.
cfg.sync.enabled = true;
cfg.sync.port = "COM9";
cfg.sync.baudRate = 128000;
cfg.sync.highCommand = 'a';
cfg.sync.lowCommand = 'b';
cfg.sync.initialLowPauseSec = 0.05;

% Run identity and output.
cfg.session.outputDirectory = fullfile(pwd, "stimulus_runs");
cfg.session.filePrefix = "visual_stim";
cfg.session.wavesurferSweep = "";
cfg.session.autoDetectWaveSurferFile = false;
cfg.session.wavesurferSearchDirectory = "";
cfg.session.wavesurferMaximumAgeMinutes = 5;
cfg.session.notes = "";
cfg.session.randomSeed = 1;

% Shared analysis settings. These are saved for offline analysis and do not
% affect stimulus presentation.
cfg.analysis.durationsSec = [30 60 90 120 180 Inf];
cfg.analysis.bootstrapRepetitions = 1000;
cfg.analysis.gaussianCenterBoundsDeg = [-100 100; -60 60];
cfg.analysis.gaussianWidthBoundsDeg = [2 80];

switch cfg.protocol
    case "Moving bars"
        p.mappingAzimuthLimitsDeg = [];
        p.mappingElevationLimitsDeg = [];
        p.barWidthDeg = 9.6;
        p.barSpeedDegPerSec = 50;
        p.polarities = [-1 1];
        p.directions = ["left_to_right", "right_to_left", ...
            "bottom_to_top", "top_to_bottom"];
        p.repetitionsPerCondition = 3;
        p.interSweepSec = 0.250;

        a.spikeLatencyRangeMs = [20 200];
        a.spikeBinMs = 10;
        a.positionBinDeg = 4.8;
        a.spatialSmoothingDeg = 4.8;
        a.minimumSweeps = 8;
        a.bootstrapRepetitions = 1000;

    case "Flashed bars"
        p.mappingAzimuthLimitsDeg = [];
        p.mappingElevationLimitsDeg = [];
        p.barWidthDeg = 9.6;
        p.positionSpacingDeg = 9.6;
        p.durationSec = 0.100;
        p.interStimulusSec = 0.300;
        p.polarities = [-1 1];
        p.verticalPositionsDeg = [];
        p.horizontalPositionsDeg = [];
        p.repetitionsPerCondition = 3;

        a.responseWindowMs = [20 200];
        a.baselineWindowMs = [-100 0];
        a.spatialSmoothingDeg = 4.8;
        a.sharePolarityCenter = true;
        a.sharePolarityWidth = true;
        a.bootstrapRepetitions = 1000;

    case "Sparse noise"
        p.mappingAzimuthLimitsDeg = [];
        p.mappingElevationLimitsDeg = [];
        p.gridSize = [17 6]; % [azimuth elevation]
        p.autoGridFromDisplay = true;
        p.gridCoordinateMode = "constant_degrees";
        p.tileSizeDeg = [9.6 9.6];
        p.gridSpacingDeg = [9.6 9.6];
        p.lockGridSpacingToTileSize = true;
        p.forceSquareTiles = true;
        p.patternDurationSec = 0.100;
        p.interPatternSec = 0;
        p.activeTilesPerPattern = 6;
        p.whiteTilesPerPattern = 3;
        p.blackTilesPerPattern = 3;
        p.minimumGridDistance = 3;
        p.minimumReusePatterns = 2;
        p.avoidAdjacentNextPattern = true;
        p.totalDurationSec = 180;
        p.maximumGenerationAttempts = 5000;

        a.spikeBinMs = 10;
        a.testedLagsMs = 0:10:200;
        a.spatialSmoothingDeg = 4.8;
        a.regularizationStrength = 1;
        a.crossValidationFolds = 5;
        a.method = "both";
        a.bootstrapRepetitions = 1000;

    case "Fast Gabor tiling"
        p.mappingAzimuthLimitsDeg = [];
        p.mappingElevationLimitsDeg = [];
        p.gridSize = [17 6];
        p.autoGridFromDisplay = true;
        p.positionSpacingDeg = [15 15];
        p.orientationsDeg = [0 45 90 135];
        p.orientationDefinition = "bar_orientation";
        p.spatialFrequencyCyclesPerDeg = 0.04;
        p.diameterDeg = 20;
        p.edgeBlurDeg = 10;
        p.contrast = 1;
        p.spatialPhaseDeg = 0;
        p.temporalModulation = "drifting";
        p.temporalFrequencyHz = 2;
        p.durationSec = 0.500;
        p.interStimulusSec = 1;
        p.repetitionsPerCondition = 20;

        a.responseWindowMs = [20 300];
        a.baselineWindowMs = [-100 0];
        a.spatialSmoothingDeg = 4.8;
        a.orientationRadiusDeg = 15;
        a.bootstrapRepetitions = 1000;

    case "Targeted Gabor grid"
        p.centerAzimuthDeg = [];
        p.centerElevationDeg = [];
        p.gridRadius = 0;
        p.gridSpacingDeg = [15 15];
        p.orientationsDeg = [0 45 90 135];
        p.orientationDefinition = "bar_orientation";
        p.spatialFrequencyCyclesPerDeg = 0.04;
        p.diameterDeg = 20;
        p.edgeBlurDeg = 10;
        p.contrast = 1;
        p.spatialPhaseDeg = 0;
        p.temporalModulation = "drifting";
        p.temporalFrequencyHz = 2;
        p.durationSec = 0.500;
        p.interStimulusSec = 1;
        p.repetitionsPerCondition = 20;

        a.responseWindowMs = [20 300];
        a.baselineWindowMs = [-100 0];
        a.spatialSmoothingDeg = 4.8;
        a.orientationRadiusDeg = 15;
        a.bootstrapRepetitions = 1000;

    case "Gabor + inverse stimuli"
        p.centerAzimuthDeg = [];
        p.centerElevationDeg = [];
        p.stimulusTypes = ["classical", "inverse", "full_field"];
        p.orientationsDeg = [0 45 90 135];
        p.orientationDefinition = "bar_orientation";
        p.spatialFrequencyCyclesPerDeg = 0.04;
        p.diameterDeg = 20;
        p.inverseDiameterDeg = 20;
        p.edgeBlurDeg = 10;
        p.contrast = 1;
        p.spatialPhaseDeg = 0;
        p.temporalModulation = "drifting";
        p.temporalFrequencyHz = 2;
        p.durationSec = 0.500;
        p.interStimulusSec = 1;
        p.repetitionsPerCondition = 20;

        a.responseWindowMs = [20 300];
        a.baselineWindowMs = [-100 0];
        a.orientationRadiusDeg = 15;
        a.bootstrapRepetitions = 1000;

    otherwise
        error('vstim:UnknownProtocol', 'Unknown protocol "%s".', cfg.protocol)
end

cfg.stimulus = p;
cfg.protocolAnalysis = a;

% Apply machine-specific choices made by installVisualStim. Protocol
% defaults remain in this file; installation settings only override
% display geometry, synchronization hardware, and output location.
installation = vstim.loadInstallationConfig();
if isfield(installation, 'display')
    names = fieldnames(installation.display);
    for i = 1:numel(names)
        value = installation.display.(names{i});
        if strcmp(names{i}, 'screenNumber') && isnumeric(value) && ...
                (isempty(value) || (isscalar(value) && isnan(value)))
            value = [];
        end
        cfg.display.(names{i}) = value;
    end
end
if isfield(installation, 'sync')
    names = fieldnames(installation.sync);
    for i = 1:numel(names)
        cfg.sync.(names{i}) = installation.sync.(names{i});
    end
end
if isfield(installation, 'session')
    names = fieldnames(installation.session);
    for i = 1:numel(names)
        cfg.session.(names{i}) = string(installation.session.(names{i}));
    end
end
cfg = vstim.normalizeDisplayGeometry(cfg);
if any(cfg.protocol == ["Targeted Gabor grid", "Gabor + inverse stimuli"])
    if isempty(cfg.stimulus.centerAzimuthDeg)
        cfg.stimulus.centerAzimuthDeg = ...
            cfg.display.monitorCenterAzimuthDeg;
    end
    if isempty(cfg.stimulus.centerElevationDeg)
        cfg.stimulus.centerElevationDeg = ...
            cfg.display.monitorCenterElevationDeg;
    end
end
end
