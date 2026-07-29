function trials = extractSpikeResponses(alignment, data, ...
        responseWindowMs, baselineWindowMs)
%EXTRACTSPIKERESPONSES Add baseline-corrected spike counts/rates per trial.

if ~isfield(data, 'spikes') || ~isfield(data.spikes, 'spks')
    error('vstim:MissingSpikes', ...
        'Preprocessed WaveSurfer data does not contain detected spikes.')
end
spikes = double(data.spikes.spks(:));
fs = data.meta.fs;
trials = alignment.trials;
n = height(trials);
responseCount = zeros(n,1);
baselineCount = zeros(n,1);
responseDurationSec = diff(responseWindowMs)/1000;
baselineDurationSec = diff(baselineWindowMs)/1000;

for i = 1:n
    onset = trials.onsetSample(i);
    responseBounds = onset + round(responseWindowMs/1000*fs);
    baselineBounds = onset + round(baselineWindowMs/1000*fs);
    responseCount(i) = sum(spikes >= responseBounds(1) & ...
        spikes < responseBounds(2));
    baselineCount(i) = sum(spikes >= baselineBounds(1) & ...
        spikes < baselineBounds(2));
end

trials.responseSpikeCount = responseCount;
trials.baselineSpikeCount = baselineCount;
trials.responseSpikeRateHz = responseCount/responseDurationSec;
trials.baselineSpikeRateHz = baselineCount/baselineDurationSec;
trials.evokedSpikeRateHz = trials.responseSpikeRateHz - ...
    trials.baselineSpikeRateHz;
end
