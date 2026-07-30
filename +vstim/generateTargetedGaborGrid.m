function sequence = generateTargetedGaborGrid(cfg, frameRate)
%GENERATETARGETEDGABORGRID Build a degree-centered square Gabor lattice.

p = cfg.stimulus;
offsets = -p.gridRadius:p.gridRadius;
[offsetX, offsetY] = ndgrid(offsets, offsets);
azimuthDeg = p.centerAzimuthDeg + offsetX(:)*p.gridSpacingDeg(1);
elevationDeg = p.centerElevationDeg + offsetY(:)*p.gridSpacingDeg(2);
nPositions = numel(azimuthDeg);
pixelX = (azimuthDeg-cfg.display.azimuthLimitsDeg(1)) / ...
    diff(cfg.display.azimuthLimitsDeg)*cfg.display.resolutionPx(1);
pixelY = (cfg.display.elevationLimitsDeg(2)-elevationDeg) / ...
    diff(cfg.display.elevationLimitsDeg)*cfg.display.resolutionPx(2);

[positionIndex, orientationDeg] = ndgrid(1:nPositions, p.orientationsDeg);
base = table(positionIndex(:), pixelX(positionIndex(:)), ...
    pixelY(positionIndex(:)), azimuthDeg(positionIndex(:)), ...
    elevationDeg(positionIndex(:)), orientationDeg(:), ...
    'VariableNames', {'positionIndex', 'pixelX', 'pixelY', 'azimuthDeg', ...
    'elevationDeg', 'orientationDeg'});

blocks = cell(p.repetitionsPerCondition, 1);
for repetition = 1:p.repetitionsPerCondition
    blocks{repetition} = base(randperm(height(base)), :);
    blocks{repetition}.repetition = repmat(repetition, height(base), 1);
end
trials = vertcat(blocks{:});
trials.trialIndex = (1:height(trials))';
trials.durationSec = repmat(round(p.durationSec*frameRate)/frameRate, ...
    height(trials), 1);
trials.interStimulusSec = repmat(p.interStimulusSec, height(trials), 1);

sequence.trials = trials;
sequence.grid = table((1:nPositions)', pixelX, pixelY, azimuthDeg, ...
    elevationDeg, 'VariableNames', {'locationIndex', 'pixelX', 'pixelY', ...
    'azimuthDeg', 'elevationDeg'});
sequence.orientationDefinition = p.orientationDefinition;
sequence.gridRadius = p.gridRadius;
sequence.gridSpacingDeg = p.gridSpacingDeg;
sequence.estimatedDurationSec = sum( ...
    trials.durationSec + trials.interStimulusSec);
sequence.ttlMode = "onset_frame_pulse";
sequence.ttlModeReason = "one_display_frame_pulse_for_every_trial";
end
