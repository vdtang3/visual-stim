function sequence = generateFlashedBars(cfg, frameRate)
%GENERATEFLASHEDBARS Make randomized, balanced flashed-bar conditions.

p = cfg.stimulus;
[azLimits, elLimits] = vstim.mappingLimits(cfg);
if isempty(p.verticalPositionsDeg)
    vertical = vstim.regionAxis(cfg, "azimuth", ...
        cfg.display.azimuthLimitsDeg, ...
        p.barWidthDeg, p.positionSpacingDeg);
else
    vertical = p.verticalPositionsDeg;
end
vertical = vertical(vertical >= azLimits(1) & vertical <= azLimits(2));
if isempty(p.horizontalPositionsDeg)
    horizontal = vstim.regionAxis(cfg, "elevation", ...
        cfg.display.elevationLimitsDeg, ...
        p.barWidthDeg, p.positionSpacingDeg);
else
    horizontal = p.horizontalPositionsDeg;
end
horizontal = horizontal(horizontal >= elLimits(1) & horizontal <= elLimits(2));
if isempty(vertical) && isempty(horizontal)
    error('vstim:NoStimuliInTarget', ...
        'The selected target does not contain any flashed-bar positions.')
end

axisName = [repmat("azimuth", numel(vertical)*numel(p.polarities), 1); ...
    repmat("elevation", numel(horizontal)*numel(p.polarities), 1)];
position = [repelem(vertical(:), numel(p.polarities)); ...
    repelem(horizontal(:), numel(p.polarities))];
polarity = repmat(p.polarities(:), numel(vertical)+numel(horizontal), 1);
base = table(axisName, position, polarity, ...
    'VariableNames', {'axis', 'positionDeg', 'polarity'});
trials = repmat(base, p.repetitionsPerCondition, 1);
trials = trials(randperm(height(trials)), :);
trials.trialIndex = (1:height(trials))';
trials.durationSec = repmat(round(p.durationSec*frameRate)/frameRate, height(trials), 1);
trials.interStimulusSec = repmat(p.interStimulusSec, height(trials), 1);

sequence.trials = trials;
sequence.verticalPositionsDeg = vertical(:);
sequence.horizontalPositionsDeg = horizontal(:);
sequence.mappingAzimuthLimitsDeg = azLimits;
sequence.mappingElevationLimitsDeg = elLimits;
sequence.estimatedDurationSec = sum(trials.durationSec + trials.interStimulusSec);
sequence.ttlMode = "epoch";
end
