function data = preprocessForAnalysis(data)
%PREPROCESSFORANALYSIS Prepare voltage and spikes for visual RF analysis.
% This deliberately excludes crop-table validation, plateau/PSP filtering,
% plateau extraction, and Vm summary statistics used by the full pipeline.

assert(isfield(data,'ai') && isfield(data.ai,'volt'), ...
    '[vstim.preprocessForAnalysis] Missing data.ai.volt.')
assert(isfield(data,'meta') && isfield(data.meta,'fs'), ...
    '[vstim.preprocessForAnalysis] Missing data.meta.fs.')

spikeThresholdMv = -42;
outlierThresholdZ = -6;
lowpassCutoffHz = 5e3;
filterOrder = 2;
fs = double(data.meta.fs);
if fs <= 2*lowpassCutoffHz
    error('vstim:SamplingRateTooLow', ...
        ['Voltage sampling rate must exceed %.0f Hz for the %.0f Hz ' ...
         'quick-analysis low-pass filter.'],2*lowpassCutoffHz, ...
        lowpassCutoffHz)
end

[b,a] = butter(filterOrder,lowpassCutoffHz/(fs/2),'low');
data.ai.volt = filtfilt(b,a,data.ai.volt);
data.ai.volt = cleanSharpNegativeArtifacts( ...
    data.ai.volt,outlierThresholdZ);
if ~isfield(data.meta,'samples') || isempty(data.meta.samples)
    data.meta.samples = numel(data.ai.volt);
end
% Drift adjustment must precede spike detection because getSpikes uses
% absolute voltage and prominence thresholds.
data = adjustVoltage(data,spikeThresholdMv);
data = removeSpikes(data);
data.proc.info = 'vstim.preprocessForAnalysis';
end

function cleanTrace = cleanSharpNegativeArtifacts(rawTrace,thresholdZ)
medianValue = median(rawTrace);
madValue = mad(rawTrace,1);
if ~isfinite(madValue) || madValue == 0
    cleanTrace = rawTrace;
    return
end
artifact = logical(movmax( ...
    (rawTrace-medianValue)/madValue < thresholdZ,3));
cleanTrace = rawTrace;
if any(artifact) && any(~artifact)
    cleanTrace(artifact) = interp1(find(~artifact),rawTrace(~artifact), ...
        find(artifact),'linear','extrap');
end
end
