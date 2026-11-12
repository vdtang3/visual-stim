function interStimulusSec = sampleInterStimulusSec(rangeSec, nTrials)
%SAMPLEINTERSTIMULUSSEC Draw one inter-stimulus interval per trial.
% rangeSec is [minimum maximum] in seconds. Equal values give a fixed
% interval; otherwise each interval is drawn uniformly from that range.
% Draws use the global stream seeded by generateSequence, so a run is
% reproducible from cfg.session.randomSeed. A scalar is accepted as a
% fixed interval so configurations saved before ranges existed still run.

rangeSec = double(rangeSec);
if isscalar(rangeSec)
    rangeSec = [rangeSec rangeSec];
end
if rangeSec(1) == rangeSec(2)
    % No draw is made, so fixed-interval sequences are identical to those
    % generated before jitter was supported.
    interStimulusSec = repmat(rangeSec(1), nTrials, 1);
else
    interStimulusSec = rangeSec(1) + diff(rangeSec)*rand(nTrials, 1);
end
end
