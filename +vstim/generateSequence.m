function sequence = generateSequence(cfg, frameRate)
%GENERATESEQUENCE Generate the complete balanced stimulus sequence.

arguments
    cfg (1,1) struct
    frameRate (1,1) double {mustBePositive} = 60
end

rng(cfg.session.randomSeed, 'twister');

switch string(cfg.protocol)
    case "Moving bars"
        sequence = vstim.generateMovingBars(cfg, frameRate);
    case "Flashed bars"
        sequence = vstim.generateFlashedBars(cfg, frameRate);
    case "Sparse noise"
        sequence = vstim.generateSparseNoise(cfg, frameRate);
    case "Fast Gabor tiling"
        sequence = vstim.generateGaborTiling(cfg, frameRate);
    case "Targeted Gabor grid"
        sequence = vstim.generateTargetedGaborGrid(cfg, frameRate);
    case "Gabor + inverse stimuli"
        sequence = vstim.generateGaborInverse(cfg, frameRate);
    otherwise
        error('vstim:UnknownProtocol', 'Unknown protocol "%s".', cfg.protocol)
end

% All protocols use the same synchronization convention: the TTL is high
% for the first displayed frame of every trial or pattern.
sequence.ttlMode = "onset_frame_pulse";
sequence.ttlModeReason = "one_display_frame_pulse_for_every_trial";
sequence.schemaVersion = cfg.schemaVersion;
sequence.protocol = cfg.protocol;
sequence.randomSeed = cfg.session.randomSeed;
sequence.nominalFrameRate = frameRate;
sequence.createdAt = datetime('now');
end
