function validateConfig(cfg)
%VALIDATECONFIG Fail early for unsafe or internally inconsistent settings.

mustBeMember(string(cfg.protocol), ...
    ["Moving bars", "Flashed bars", "Sparse noise", "Fast Gabor tiling", ...
    "Targeted Gabor grid", "Gabor + inverse stimuli"]);
mustBeGreaterThan(cfg.display.viewingDistanceCm, 0);
mustBeGreaterThan(cfg.display.monitorWidthCm, 0);
mustBeGreaterThan(cfg.display.monitorHeightCm, 0);
mustBeInRange(cfg.display.backgroundGray, 0, 1);
mustBeGreaterThanOrEqual(cfg.display.preRunBlankSec, 0);
mustBeGreaterThanOrEqual(cfg.display.postRunBlankSec, 0);
mustBeGreaterThanOrEqual(cfg.session.randomSeed, 0);
if isfield(cfg.session, 'autoDetectWaveSurferFile') && ...
        cfg.session.autoDetectWaveSurferFile
    mustBePositive(cfg.session.wavesurferMaximumAgeMinutes);
end
if cfg.display.geometryCorrectionEnabled && ...
        strlength(string(cfg.display.geometryCalibrationFile)) == 0
    error('vstim:MissingGeometryCalibration', ...
        'Select a Psychtoolbox geometry-calibration file or disable correction.')
end

if diff(cfg.display.azimuthLimitsDeg) <= 0 || ...
        diff(cfg.display.elevationLimitsDeg) <= 0
    error('vstim:InvalidVisualField', ...
        'Visual-field limits must be increasing two-element vectors.')
end

p = cfg.stimulus;
[azLimits, elLimits] = vstim.mappingLimits(cfg);
if numel(azLimits) ~= 2 || numel(elLimits) ~= 2 || ...
        diff(azLimits) <= 0 || diff(elLimits) <= 0
    error('vstim:InvalidMappingRegion', ...
        'Mapping limits must be increasing two-element vectors.')
end
if azLimits(1) < cfg.display.azimuthLimitsDeg(1) || ...
        azLimits(2) > cfg.display.azimuthLimitsDeg(2) || ...
        elLimits(1) < cfg.display.elevationLimitsDeg(1) || ...
        elLimits(2) > cfg.display.elevationLimitsDeg(2)
    error('vstim:InvalidMappingRegion', ...
        'The selected mapping region must remain inside the display.')
end
switch string(cfg.protocol)
    case "Moving bars"
        mustBePositive(p.barWidthDeg);
        mustBePositive(p.barSpeedDegPerSec);
        mustBePositive(p.repetitionsPerCondition);
    case "Flashed bars"
        mustBePositive(p.barWidthDeg);
        mustBePositive(p.durationSec);
        mustBePositive(p.repetitionsPerCondition);
    case "Sparse noise"
        mustBeMember(string(p.gridCoordinateMode), ...
            ["constant_degrees", "constant_pixels"]);
        if any(p.gridSize < 1) || numel(p.gridSize) ~= 2
            error('vstim:InvalidGrid', 'Grid size must contain two positive integers.')
        end
        if p.activeTilesPerPattern > prod(p.gridSize)
            error('vstim:InvalidSparseCounts', ...
                'Active tiles cannot exceed the number of grid locations.')
        end
        if any(p.tileSizeDeg <= 0) || any(p.gridSpacingDeg <= 0)
            error('vstim:InvalidGrid', ...
                'Tile size and grid spacing must contain positive values.')
        end
        if p.whiteTilesPerPattern + p.blackTilesPerPattern ~= ...
                p.activeTilesPerPattern
            error('vstim:InvalidSparseCounts', ...
                'White plus black tiles must equal active tiles.')
        end
    case "Fast Gabor tiling"
        mustBePositive(p.spatialFrequencyCyclesPerDeg);
        mustBePositive(p.diameterDeg);
        mustBePositive(p.edgeBlurDeg);
        mustBeInRange(p.contrast, 0, 1);
        mustBeMember(string(p.temporalModulation), ...
            ["drifting", "counterphasing"]);
        mustBePositive(p.temporalFrequencyHz);
    case "Targeted Gabor grid"
        mustBeInRange(p.centerAzimuthDeg, ...
            cfg.display.azimuthLimitsDeg(1), cfg.display.azimuthLimitsDeg(2));
        mustBeInRange(p.centerElevationDeg, ...
            cfg.display.elevationLimitsDeg(1), ...
            cfg.display.elevationLimitsDeg(2));
        mustBeInteger(p.gridRadius);
        mustBeGreaterThanOrEqual(p.gridRadius, 0);
        if numel(p.gridSpacingDeg) ~= 2 || any(p.gridSpacingDeg <= 0)
            error('vstim:InvalidTargetedGrid', ...
                'gridSpacingDeg must contain two positive values.')
        end
        azimuthLimits = p.centerAzimuthDeg + [-1 1]* ...
            p.gridRadius*p.gridSpacingDeg(1);
        elevationLimits = p.centerElevationDeg + [-1 1]* ...
            p.gridRadius*p.gridSpacingDeg(2);
        if azimuthLimits(1) < cfg.display.azimuthLimitsDeg(1) || ...
                azimuthLimits(2) > cfg.display.azimuthLimitsDeg(2) || ...
                elevationLimits(1) < cfg.display.elevationLimitsDeg(1) || ...
                elevationLimits(2) > cfg.display.elevationLimitsDeg(2)
            error('vstim:TargetedGridOutsideDisplay', ...
                'The targeted Gabor grid contains centers outside the display.')
        end
        mustBePositive(p.spatialFrequencyCyclesPerDeg);
        mustBePositive(p.diameterDeg);
        mustBePositive(p.edgeBlurDeg);
        mustBeInRange(p.contrast, 0, 1);
        mustBeMember(string(p.temporalModulation), ...
            ["drifting", "counterphasing"]);
        mustBePositive(p.temporalFrequencyHz);
    case "Gabor + inverse stimuli"
        mustBeInRange(p.centerAzimuthDeg, ...
            cfg.display.azimuthLimitsDeg(1), cfg.display.azimuthLimitsDeg(2));
        mustBeInRange(p.centerElevationDeg, ...
            cfg.display.elevationLimitsDeg(1), ...
            cfg.display.elevationLimitsDeg(2));
        types = string(p.stimulusTypes);
        requiredTypes = ["classical", "inverse", "full_field"];
        if numel(types) ~= 3 || ~all(ismember(requiredTypes, types))
            error('vstim:InvalidStimulusTypes', ...
                ['stimulusTypes must contain classical, inverse, and ' ...
                'full_field.'])
        end
        mustBePositive(p.spatialFrequencyCyclesPerDeg);
        mustBePositive(p.diameterDeg);
        mustBePositive(p.inverseDiameterDeg);
        mustBePositive(p.edgeBlurDeg);
        mustBeInRange(p.contrast, 0, 1);
        mustBeMember(string(p.temporalModulation), ...
            ["drifting", "counterphasing"]);
        mustBePositive(p.temporalFrequencyHz);
end
end
