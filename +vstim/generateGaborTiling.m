function sequence = generateGaborTiling(cfg, frameRate)
%GENERATEGABORTILING Make balanced circular-grating mapping trials.

p = cfg.stimulus;
if p.autoGridFromDisplay
    [azLimits, elLimits] = vstim.mappingLimits(cfg);
    supportDeg = p.diameterDeg + p.edgeBlurDeg;
    [azAxis, azPositionsCm] = vstim.regionAxis(cfg, "azimuth", ...
        cfg.display.azimuthLimitsDeg, supportDeg, p.positionSpacingDeg(1));
    [elAxis, elPositionsCm] = vstim.regionAxis(cfg, "elevation", ...
        cfg.display.elevationLimitsDeg, supportDeg, p.positionSpacingDeg(2));
    azKeep = azAxis >= azLimits(1) & azAxis <= azLimits(2);
    elKeep = elAxis >= elLimits(1) & elAxis <= elLimits(2);
    azAxis = azAxis(azKeep);
    elAxis = elAxis(elKeep);
    azPositionsCm = azPositionsCm(azKeep);
    elPositionsCm = elPositionsCm(elKeep);
    if isempty(azAxis) || isempty(elAxis)
        error('vstim:NoStimuliInTarget', ...
            'The selected target does not contain any Gabor grid centers.')
    end
    [azimuthDeg, elevationDeg] = vstim.gridFromAxes(azAxis, elAxis);
else
    [azimuthDeg, elevationDeg] = vstim.gridCoordinates(p.gridSize, ...
        p.positionSpacingDeg);
    azimuthDeg = azimuthDeg + cfg.display.monitorCenterAzimuthDeg;
    elevationDeg = elevationDeg + cfg.display.monitorCenterElevationDeg;
end
nPositions = numel(azimuthDeg);

[positionIndex, orientationDeg] = ndgrid(1:nPositions, p.orientationsDeg);
base = table(positionIndex(:), azimuthDeg(positionIndex(:)), ...
    elevationDeg(positionIndex(:)), orientationDeg(:), ...
    'VariableNames', {'positionIndex', 'azimuthDeg', 'elevationDeg', ...
    'orientationDeg'});
% Block randomization presents every position/orientation combination once
% before beginning the next repetition.
blocks = cell(p.repetitionsPerCondition, 1);
for repetition = 1:p.repetitionsPerCondition
    blocks{repetition} = base(randperm(height(base)), :);
    blocks{repetition}.repetition = repmat(repetition, height(base), 1);
end
trials = vertcat(blocks{:});
trials.trialIndex = (1:height(trials))';
trials.durationSec = repmat(round(p.durationSec*frameRate)/frameRate, height(trials), 1);
trials.interStimulusSec = repmat(p.interStimulusSec, height(trials), 1);

sequence.trials = trials;
sequence.grid = table((1:nPositions)', azimuthDeg, elevationDeg, ...
    'VariableNames', {'locationIndex', 'azimuthDeg', 'elevationDeg'});
sequence.orientationDefinition = p.orientationDefinition;
sequence.mappingAzimuthLimitsDeg = vstim.mappingLimits(cfg);
[~, sequence.mappingElevationLimitsDeg] = vstim.mappingLimits(cfg);
sequence.azimuthAxisDeg = unique(azimuthDeg, 'stable');
sequence.elevationAxisDeg = unique(elevationDeg, 'stable');
if p.autoGridFromDisplay
    sequence.azimuthPositionsCm = azPositionsCm;
    sequence.elevationPositionsCm = elPositionsCm;
end
sequence.estimatedDurationSec = sum(trials.durationSec + trials.interStimulusSec);
sequence.ttlMode = "onset_frame_pulse";
sequence.ttlModeReason = "one_display_frame_pulse_for_every_trial";
end
