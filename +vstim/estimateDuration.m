function estimate = estimateDuration(cfg, frameRate)
%ESTIMATEDURATION Quickly estimate run length without generating a sequence.
% This is suitable for live GUI updates, including sparse-noise protocols
% whose full constrained sequence is more expensive to construct.

arguments
    cfg (1,1) struct
    frameRate (1,1) double {mustBePositive} = 60
end

cfg = vstim.normalizeDisplayGeometry(cfg);
p = cfg.stimulus;

switch string(cfg.protocol)
    case "Moving bars"
        [azLimits, elLimits] = vstim.mappingLimits(cfg);
        nPolarities = numel(p.polarities);
        nDirections = numel(p.directions);
        estimate.trialCount = nPolarities*nDirections* ...
            p.repetitionsPerCondition;

        horizontalTravelDeg = diff(azLimits) + ...
            p.barWidthDeg;
        verticalTravelDeg = diff(elLimits) + ...
            p.barWidthDeg;
        horizontalFrames = max(2, ceil( ...
            horizontalTravelDeg/p.barSpeedDegPerSec*frameRate) + 1);
        verticalFrames = max(2, ceil( ...
            verticalTravelDeg/p.barSpeedDegPerSec*frameRate) + 1);
        horizontalSweepSec = horizontalFrames/frameRate;
        verticalSweepSec = verticalFrames/frameRate;
        secondsPerRepetition = nPolarities * ...
            (2*horizontalSweepSec + 2*verticalSweepSec + ...
            nDirections*p.interSweepSec);
        estimate.durationSec = p.repetitionsPerCondition * ...
            secondsPerRepetition;

    case "Flashed bars"
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
        horizontal = horizontal(horizontal >= elLimits(1) & ...
            horizontal <= elLimits(2));
        estimate.trialCount = (numel(vertical)+numel(horizontal)) * ...
            numel(p.polarities) * p.repetitionsPerCondition;
        estimate.durationSec = estimate.trialCount * ...
            (round(p.durationSec*frameRate)/frameRate + p.interStimulusSec);

    case "Sparse noise"
        patternPeriod = p.patternDurationSec + p.interPatternSec;
        estimate.trialCount = max(1, floor(p.totalDurationSec/patternPeriod));
        estimate.durationSec = estimate.trialCount * ...
            (round(p.patternDurationSec*frameRate)/frameRate + ...
            p.interPatternSec);

    case "Fast Gabor tiling"
        if p.autoGridFromDisplay
            [azLimits, elLimits] = vstim.mappingLimits(cfg);
            supportDeg = p.diameterDeg + p.edgeBlurDeg;
            az = vstim.regionAxis(cfg, "azimuth", ...
                cfg.display.azimuthLimitsDeg, ...
                supportDeg, p.positionSpacingDeg(1));
            el = vstim.regionAxis(cfg, "elevation", ...
                cfg.display.elevationLimitsDeg, ...
                supportDeg, p.positionSpacingDeg(2));
            az = az(az >= azLimits(1) & az <= azLimits(2));
            el = el(el >= elLimits(1) & el <= elLimits(2));
            nPositions = numel(az)*numel(el);
        else
            nPositions = prod(p.gridSize);
        end
        estimate.trialCount = nPositions * numel(p.orientationsDeg) * ...
            p.repetitionsPerCondition;
        estimate.durationSec = estimate.trialCount * ...
            (round(p.durationSec*frameRate)/frameRate + p.interStimulusSec);

    case "Targeted Gabor grid"
        nPositions = (2*p.gridRadius+1)^2;
        estimate.trialCount = nPositions * numel(p.orientationsDeg) * ...
            p.repetitionsPerCondition;
        estimate.durationSec = estimate.trialCount * ...
            (round(p.durationSec*frameRate)/frameRate + p.interStimulusSec);

    case "Gabor + inverse stimuli"
        estimate.trialCount = numel(p.stimulusTypes) * ...
            numel(p.orientationsDeg) * p.repetitionsPerCondition;
        estimate.durationSec = estimate.trialCount * ...
            (round(p.durationSec*frameRate)/frameRate + p.interStimulusSec);
end

estimate.formatted = formatDuration(estimate.durationSec);
end

function text = formatDuration(seconds)
hours = floor(seconds/3600);
minutes = floor(mod(seconds,3600)/60);
remainingSeconds = mod(seconds,60);
if hours > 0
    text = sprintf('%d:%02d:%02.0f', hours, minutes, remainingSeconds);
else
    text = sprintf('%d:%02.0f', minutes, remainingSeconds);
end
end
