function metrics = analysisDataMetrics(runData,data,result)
%ANALYSISDATAMETRICS Compact recording and synchronization diagnostics.

metrics.samplingRateHz = data.meta.fs;
metrics.recordingDurationSec = numel(data.ai.volt)/data.meta.fs;
metrics.detectedSpikeCount = numel(data.spikes.spks);
metrics.overallSpikeRateHz = metrics.detectedSpikeCount / ...
    metrics.recordingDurationSec;
if isfield(data,'stats')
    if isfield(data.stats,'vm_mode')
        metrics.spikeRemovedVmModeMv = data.stats.vm_mode;
    end
    if isfield(data.stats,'vm_mean')
        metrics.spikeRemovedVmMeanMv = data.stats.vm_mean;
    end
    if isfield(data.stats,'vm_sd')
        metrics.spikeRemovedVmSdMv = data.stats.vm_sd;
    end
end
metrics.plannedTrialCount = result.sync.plannedTrialCount;
metrics.recordedTTLCount = result.sync.recordedTrialCount;
metrics.matchedTrialCount = result.sync.matchedTrialCount;
metrics.completeTTLMatch = result.sync.completeMatch;
metrics.ttlMode = result.sync.ttlMode;
if isfield(result.sync,'ignoredLeadingEdgeCount')
    metrics.ignoredLeadingTTLCount = result.sync.ignoredLeadingEdgeCount;
    metrics.ignoredTrailingTTLCount = result.sync.ignoredTrailingEdgeCount;
end
if isfield(result.sync,'expectedPulseWidthSec') && ...
        isfinite(result.sync.expectedPulseWidthSec)
    metrics.expectedTTLPulseWidthMs = ...
        result.sync.expectedPulseWidthSec*1000;
    metrics.medianRecordedTTLPulseWidthMs = ...
        result.sync.medianPulseWidthSec*1000;
    metrics.maximumTTLPulseWidthErrorMs = ...
        result.sync.maximumPulseWidthErrorSec*1000;
    metrics.ttlPulseWidthViolationCount = ...
        result.sync.pulseWidthViolationCount;
    metrics.missingTTLFallingEdgeCount = ...
        result.sync.missingFallingEdgeCount;
end
trials = runData.sequence.trials;
metrics.medianStimulusDurationMs = median(trials.durationSec)*1000;
if ismember('interStimulusSec',trials.Properties.VariableNames)
    metrics.medianInterStimulusMs = ...
        median(trials.interStimulusSec)*1000;
else
    metrics.medianInterStimulusMs = 0;
end
if isfield(result.analysisOptions,'responseWindowMs')
    metrics.responseWindowMs = result.analysisOptions.responseWindowMs;
end
if isfield(result.analysisOptions,'baselineWindowMs')
    metrics.baselineWindowMs = result.analysisOptions.baselineWindowMs;
end
protocol = string(runData.params.protocol);
if any(protocol==["Flashed bars","Fast Gabor tiling", ...
        "Targeted Gabor grid"])
    alignment = vstim.alignRecordedStimuli(runData,data);
    responseTrials = vstim.extractSpikeResponses(alignment,data, ...
        result.analysisOptions.responseWindowMs, ...
        result.analysisOptions.baselineWindowMs);
    metrics.meanBaselineSpikeRateHz = ...
        mean(responseTrials.baselineSpikeRateHz,'omitnan');
    metrics.meanResponseSpikeRateHz = ...
        mean(responseTrials.responseSpikeRateHz,'omitnan');
    metrics.meanEvokedSpikeRateHz = ...
        mean(responseTrials.evokedSpikeRateHz,'omitnan');
    metrics.medianEvokedSpikeRateHz = ...
        median(responseTrials.evokedSpikeRateHz,'omitnan');
end
if isfield(result,'preferredLatencyMs') && ...
        isfinite(result.preferredLatencyMs)
    metrics.selectedLatencyMs = result.preferredLatencyMs;
end
if isfield(result,'peakLagMs') && isfinite(result.peakLagMs)
    metrics.peakResponseLagMs = result.peakLagMs;
end
metrics.spikePeakMinimumMv = -20;
metrics.spikeMinimumProminenceMv = 20;
metrics.spikeMinimumWidthMs = 0.5;
metrics.spikeMinimumDistanceSamples = 10;
end
