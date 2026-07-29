function [options,timing] = analysisOptionsForRun(runData)
%ANALYSISOPTIONSFORRUN Initialize analysis settings from the saved run.
% Event-response and baseline windows are constrained to the actual
% stimulus/blank cycle so their defaults cannot enter an adjacent trial.

options = vstim.analysisOptions(runData,struct());
trials = runData.sequence.trials;
timing.medianStimulusDurationMs = ...
    median(double(trials.durationSec))*1000;
timing.minimumStimulusDurationMs = ...
    min(double(trials.durationSec))*1000;
if ismember('interStimulusSec',trials.Properties.VariableNames)
    interStimulusSec = double(trials.interStimulusSec);
else
    interStimulusSec = zeros(height(trials),1);
end
timing.medianInterStimulusMs = median(interStimulusSec)*1000;
timing.minimumInterStimulusMs = min(interStimulusSec)*1000;
timing.minimumOnsetIntervalMs = min( ...
    double(trials.durationSec)+interStimulusSec)*1000;
timing.windowAdjustment = "None";

protocol = string(runData.params.protocol);
if any(protocol == ["Flashed bars","Fast Gabor tiling", ...
        "Targeted Gabor grid"])
    originalResponse = options.responseWindowMs;
    latestResponseEnd = timing.minimumOnsetIntervalMs-1;
    options.responseWindowMs(2) = min( ...
        options.responseWindowMs(2),latestResponseEnd);
    if options.responseWindowMs(2) <= options.responseWindowMs(1)
        options.responseWindowMs(2) = ...
            options.responseWindowMs(1)+1;
    end

    originalBaseline = options.baselineWindowMs;
    if timing.minimumInterStimulusMs > 0
        options.baselineWindowMs(1) = max( ...
            options.baselineWindowMs(1), ...
            -timing.minimumInterStimulusMs);
    end
    if ~isequal(originalResponse,options.responseWindowMs) || ...
            ~isequal(originalBaseline,options.baselineWindowMs)
        timing.windowAdjustment = sprintf( ...
            ['Saved defaults were constrained to the recorded stimulus ' ...
             'cycle: response [%g %g] ms, baseline [%g %g] ms.'], ...
            options.responseWindowMs,options.baselineWindowMs);
    end
end

% Only expose parameters that the current spike estimator actually uses.
% Saved forward-looking or Vm-only settings remain in runData but are not
% shown as if they affected this analysis.
switch protocol
    case "Moving bars"
        keep = {'spikeLatencyRangeMs','spikeBinMs','positionBinDeg', ...
            'minimumSweeps','minimumPeakResponseHz', ...
            'minimumResponseDynamicRangeHz','minimumFitQuality', ...
            'bootstrapRepetitions','randomSeed'};
    case "Flashed bars"
        keep = {'responseWindowMs','baselineWindowMs', ...
            'minimumPeakResponseHz','minimumResponseDynamicRangeHz', ...
            'minimumFitQuality','bootstrapRepetitions','randomSeed'};
    case "Sparse noise"
        keep = {'spikeBinMs','testedLagsMs','regularizationStrength', ...
            'crossValidationFolds','minimumPeakResponseHz', ...
            'minimumResponseDynamicRangeHz','minimumFitQuality', ...
            'bootstrapRepetitions','randomSeed'};
    otherwise
        keep = {'responseWindowMs','baselineWindowMs', ...
            'minimumPeakResponseHz','minimumResponseDynamicRangeHz', ...
            'minimumFitQuality','bootstrapRepetitions','randomSeed'};
end
remove = setdiff(fieldnames(options),keep,'stable');
if ~isempty(remove)
    options = rmfield(options,remove);
end
end
