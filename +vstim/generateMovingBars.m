function sequence = generateMovingBars(cfg, frameRate)
%GENERATEMOVINGBARS Make randomized, balanced bidirectional bar sweeps.

p = cfg.stimulus;
[azLim, elLim] = vstim.mappingLimits(cfg);

[direction, polarity] = ndgrid(p.directions, p.polarities);
base = table(direction(:), polarity(:), ...
    'VariableNames', {'direction', 'polarity'});
trials = repmat(base, p.repetitionsPerCondition, 1);
trials = trials(randperm(height(trials)), :);

trials.trialIndex = (1:height(trials))';
trials.axis = strings(height(trials), 1);
trials.durationSec = zeros(height(trials), 1);
trials.interStimulusSec = repmat(p.interSweepSec, height(trials), 1);
trials.frameCentersDeg = cell(height(trials), 1);

for t = 1:height(trials)
    d = trials.direction(t);
    if any(d == ["left_to_right", "right_to_left"])
        trials.axis(t) = "azimuth";
        lo = azLim(1) - p.barWidthDeg/2;
        hi = azLim(2) + p.barWidthDeg/2;
    else
        trials.axis(t) = "elevation";
        lo = elLim(1) - p.barWidthDeg/2;
        hi = elLim(2) + p.barWidthDeg/2;
    end
    if any(d == ["right_to_left", "top_to_bottom"])
        endpoints = [hi lo];
    else
        endpoints = [lo hi];
    end

    duration = abs(diff(endpoints)) / p.barSpeedDegPerSec;
    nFrames = max(2, ceil(duration * frameRate) + 1);
    trials.durationSec(t) = nFrames / frameRate;
    trials.frameCentersDeg{t} = linspace(endpoints(1), endpoints(2), nFrames);
end

sequence.trials = trials;
sequence.frameByFrameBarCentersDeg = trials.frameCentersDeg;
sequence.mappingAzimuthLimitsDeg = azLim;
sequence.mappingElevationLimitsDeg = elLim;
sequence.estimatedDurationSec = sum(trials.durationSec + trials.interStimulusSec);
sequence.ttlMode = "onset_frame_pulse";
sequence.ttlModeReason = "one_display_frame_pulse_for_every_trial";
end
