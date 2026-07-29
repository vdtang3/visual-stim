function sequence = generateGaborInverse(cfg, frameRate)
%GENERATEGABORINVERSE Build balanced classical and inverse grating trials.

p = cfg.stimulus;
[stimulusType, orientationDeg] = ndgrid( ...
    string(p.stimulusTypes), p.orientationsDeg);
nConditions = numel(stimulusType);
base = table(stimulusType(:), orientationDeg(:), ...
    repmat(p.centerAzimuthDeg, nConditions, 1), ...
    repmat(p.centerElevationDeg, nConditions, 1), ...
    'VariableNames', {'stimulusType', 'orientationDeg', ...
    'azimuthDeg', 'elevationDeg'});

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
sequence.centerAzimuthDeg = p.centerAzimuthDeg;
sequence.centerElevationDeg = p.centerElevationDeg;
sequence.stimulusTypes = string(p.stimulusTypes);
sequence.orientationDefinition = p.orientationDefinition;
sequence.estimatedDurationSec = sum( ...
    trials.durationSec + trials.interStimulusSec);
sequence.ttlMode = "epoch";
end
