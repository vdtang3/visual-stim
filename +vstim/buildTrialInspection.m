function inspection = buildTrialInspection(runData, data, alignment)
%BUILDTRIALINSPECTION Generic Vm/trial acquisition-QC product for any protocol.
%   INSPECTION = BUILDTRIALINSPECTION(RUNDATA, DATA, ALIGNMENT) builds the
%   data a fast Vm/trial viewer needs to answer "is this recording worth
%   keeping" and "are responses repeatable across trials": a decimated
%   whole-recording overview (stable/drifting/artifacts, at a glance), and
%   one onset-aligned window per matched trial (Vm, spikes, and burst
%   membership), with a short condition label for whichever trial-design
%   columns this protocol's trial table happens to have.
%
%   DATA must already have passed through VSTIM.PREPROCESSFORANALYSIS
%   (needs DATA.PROC.VOLT and DATA.SPIKES.SPKS/.PEAKS). ALIGNMENT must
%   already have passed through VSTIM.ALIGNRECORDEDSTIMULI.
%
%   This is deliberately independent of any protocol-specific RF fit: it
%   is the same for every protocol, and never feeds into
%   VSTIM.ANALYZESPIKERECEPTIVEFIELD or VSTIM.CONSENSUSRECEPTIVEFIELD.
%
%   Every per-trial Vm window is capped at MAXSAMPLESPERTRIALWINDOW points
%   via a min/max-envelope decimation (same technique as the overview),
%   so total storage stays bounded even for protocols with hundreds of
%   short trials (e.g. sparse noise): this keeps a saved session's
%   inspection data small without ever storing the full raw trace.

maxOverviewPoints = 4000;
maxSamplesPerTrialWindow = 4000;
paddingBeforeMs = 100;
paddingAfterMs = 200;
minBurstSpikeCount = 3;
maxBurstIntervalMs = 10;

fs = data.meta.fs;
volt = data.proc.volt(:);
spikeSamples = double(data.spikes.spks(:));
spikeTimesSec = (spikeSamples-1)/fs;
spikeVoltageMv = double(data.spikes.peaks(:));
isBurstSpike = vstim.detectBurstSpikes(spikeTimesSec, minBurstSpikeCount, ...
    maxBurstIntervalMs/1000);

trials = alignment.trials;
nTrials = height(trials);
conditionLabels = buildConditionLabels(trials);

inspection.schemaVersion = "1.0.0";
inspection.protocol = string(runData.params.protocol);

[overviewTimeSec,overviewVoltMv] = decimateEnvelope( ...
    (0:numel(volt)-1)'/fs,volt,maxOverviewPoints);
inspection.overview.timeSec = overviewTimeSec;
inspection.overview.voltMv = overviewVoltMv;
inspection.overview.spikeTimesSec = spikeTimesSec;
inspection.overview.spikeVoltageMv = spikeVoltageMv;
inspection.overview.spikeIsBurst = isBurstSpike;
inspection.overview.trialOnsetTimesSec = trials.onsetSec;
inspection.overview.trialLabels = conditionLabels;
inspection.overview.recordingDurationSec = numel(volt)/fs;

inspection.stimulusTiming = vstim.assessPresentationQuality(runData);

windowMs = [-paddingBeforeMs,max(trials.durationSec)*1000+paddingAfterMs];
sampleOffsets = round(windowMs(1)/1000*fs):round(windowMs(2)/1000*fs);
[windowTimeMs,decimationStride] = decimatedTimeAxis( ...
    sampleOffsets/fs*1000,maxSamplesPerTrialWindow);
nSamples = numel(volt);

vmMv = nan(nTrials,numel(windowTimeMs));
spikeTimesMsByTrial = cell(nTrials,1);
spikeVoltageMvByTrial = cell(nTrials,1);
spikeIsBurstByTrial = cell(nTrials,1);
outOfBoundsTrialCount = 0;
for i = 1:nTrials
    onsetSample = trials.onsetSample(i);
    sampleIndices = onsetSample+sampleOffsets;
    if sampleIndices(1) < 1 || sampleIndices(end) > nSamples
        outOfBoundsTrialCount = outOfBoundsTrialCount+1;
    else
        vmMv(i,:) = decimateStride(volt(sampleIndices),decimationStride, ...
            numel(windowTimeMs));
    end
    windowBounds = onsetSample+[sampleOffsets(1),sampleOffsets(end)];
    inWindow = spikeSamples >= windowBounds(1) & spikeSamples <= windowBounds(2);
    spikeTimesMsByTrial{i} = (spikeSamples(inWindow)-onsetSample)/fs*1000;
    spikeVoltageMvByTrial{i} = spikeVoltageMv(inWindow);
    spikeIsBurstByTrial{i} = isBurstSpike(inWindow);
end
if outOfBoundsTrialCount > 0
    inspection.warnings = "%d trial(s) omitted from the Vm window because " + ...
        "the display window reached outside the recording.";
    inspection.warnings = sprintf(inspection.warnings,outOfBoundsTrialCount);
else
    inspection.warnings = strings(0,1);
end

inspection.trialWindowTimeMs = windowTimeMs;
inspection.trials = table(trials.onsetSec,conditionLabels, ...
    'VariableNames',{'onsetSec','conditionLabel'});
inspection.trials.vmMv = vmMv;
inspection.trials.spikeTimesMs = spikeTimesMsByTrial;
inspection.trials.spikeVoltageMv = spikeVoltageMvByTrial;
inspection.trials.spikeIsBurst = spikeIsBurstByTrial;
end

function labels = buildConditionLabels(trials)
% A short, human-readable condition label built from whichever of these
% trial-design columns this protocol's trial table happens to carry, so
% the generic viewer's condition filter works across every protocol
% without a protocol-specific switch statement here.
candidateColumns = ["direction","axis","positionDeg","polarity", ...
    "positionIndex","orientationDeg","stimulusType"];
presentColumns = candidateColumns(ismember(candidateColumns, ...
    trials.Properties.VariableNames));
if isempty(presentColumns)
    labels = "Trial "+string((1:height(trials))');
    return
end
parts = strings(height(trials),numel(presentColumns));
for i = 1:numel(presentColumns)
    parts(:,i) = presentColumns(i)+"="+formattedColumn(trials.(presentColumns(i)));
end
labels = strings(height(trials),1);
for row = 1:height(trials)
    labels(row) = strjoin(parts(row,:),", ");
end
end

function text = formattedColumn(values)
if isnumeric(values)
    text = compose("%g",values);
else
    text = string(values);
end
end

function [timeSec,voltMv] = decimateEnvelope(sourceTimeSec,sourceVolt,maxPoints)
% Min/max-envelope decimation: each output bin keeps both the minimum and
% maximum source sample, so a brief spike or artifact stays visible even
% at very low output resolution, unlike a plain stride/mean decimation
% that would smooth transients away.
n = numel(sourceVolt);
if n <= maxPoints
    timeSec = sourceTimeSec;
    voltMv = sourceVolt;
    return
end
nBins = floor(maxPoints/2);
edges = round(linspace(1,n+1,nBins+1));
timeSec = zeros(2*nBins,1);
voltMv = zeros(2*nBins,1);
for b = 1:nBins
    binRange = edges(b):edges(b+1)-1;
    [binMin,minIndex] = min(sourceVolt(binRange));
    [binMax,maxIndex] = max(sourceVolt(binRange));
    firstIndex = binRange(1)+min(minIndex,maxIndex)-1;
    secondIndex = binRange(1)+max(minIndex,maxIndex)-1;
    if minIndex <= maxIndex
        firstValue = binMin; secondValue = binMax;
    else
        firstValue = binMax; secondValue = binMin;
    end
    timeSec(2*b-1) = sourceTimeSec(firstIndex);
    voltMv(2*b-1) = firstValue;
    timeSec(2*b) = sourceTimeSec(secondIndex);
    voltMv(2*b) = secondValue;
end
end

function [timeMs,stride] = decimatedTimeAxis(fullTimeMs,maxPoints)
n = numel(fullTimeMs);
stride = max(1,ceil(n/maxPoints));
timeMs = fullTimeMs(1:stride:end);
end

function decimated = decimateStride(values,stride,targetLength)
% Min/max-envelope decimation of one trial's window at a fixed stride, so
% every trial (which shares one window length) produces the same number
% of output points and can be stored as one row of a shared-width matrix.
if stride <= 1
    decimated = values(:)';
    return
end
n = numel(values);
decimated = nan(1,targetLength);
for i = 1:targetLength
    binStart = (i-1)*stride+1;
    binEnd = min(n,i*stride);
    if binStart > n
        break
    end
    binValues = values(binStart:binEnd);
    [~,extremeIndex] = max(abs(binValues-mean(binValues)));
    decimated(i) = binValues(extremeIndex);
end
end
