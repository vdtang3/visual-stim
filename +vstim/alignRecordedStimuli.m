function alignment = alignRecordedStimuli(runData, data)
%ALIGNRECORDEDSTIMULI Match recorded Screen TTL onsets to planned trials.

if ~isfield(data, 'di') || ~isfield(data.di, 'screen') || ...
        isempty(data.di.screen)
    error('vstim:MissingScreenTTL', ...
        'WaveSurfer data does not contain the Screen digital channel.')
end

screenHigh = data.di.screen(:) > 0.5;
risingSamples = find(diff([false; screenHigh]) == 1);
fallingSamples = find(diff([screenHigh; false]) == -1);
nPlanned = height(runData.sequence.trials);
nRecorded = numel(risingSamples);
nMatched = min(nPlanned, nRecorded);
if nMatched == 0
    error('vstim:NoScreenTTL', 'No Screen TTL rising edges were detected.')
end

selectedEdgeIndices = (1:nMatched)';
candidateScores = [];
if nRecorded >= nPlanned
    [selectedEdgeIndices, candidateScores] = selectBestEdgeBlock( ...
        risingSamples, fallingSamples, runData.sequence.trials, ...
        runData, string(runData.sequence.ttlMode), data.meta.fs);
end

trials = runData.sequence.trials(1:nMatched,:);
trials.recordedTrialIndex = selectedEdgeIndices;
trials.onsetSample = risingSamples(selectedEdgeIndices);
trials.onsetSec = (trials.onsetSample-1)/data.meta.fs;
trials.offsetSample = nan(nMatched,1);
trials.recordedDurationSec = nan(nMatched,1);

if string(runData.sequence.ttlMode) == "epoch"
    for i = 1:nMatched
        offset = fallingSamples(find( ...
            fallingSamples >= trials.onsetSample(i), 1, 'first'));
        if ~isempty(offset)
            trials.offsetSample(i) = offset;
            trials.recordedDurationSec(i) = ...
                (offset-trials.onsetSample(i))/data.meta.fs;
        end
    end
end

alignment.trials = trials;
alignment.risingSamples = risingSamples;
alignment.fallingSamples = fallingSamples;
alignment.selectedRisingEdgeIndices = selectedEdgeIndices;
alignment.ignoredLeadingEdgeCount = selectedEdgeIndices(1)-1;
alignment.ignoredTrailingEdgeCount = ...
    nRecorded-selectedEdgeIndices(end);
alignment.candidateMatchScores = candidateScores;
alignment.plannedTrialCount = nPlanned;
alignment.recordedTrialCount = nRecorded;
alignment.matchedTrialCount = nMatched;
alignment.completeMatch = nMatched == nPlanned;
alignment.exactRecordedCountMatch = nPlanned == nRecorded;
alignment.ttlMode = string(runData.sequence.ttlMode);
alignment.warnings = strings(0,1);
if nRecorded < nPlanned
    alignment.warnings(end+1) = sprintf( ...
        'Planned %d trials but detected %d Screen TTL onsets; using %d.', ...
        nPlanned, nRecorded, nMatched);
elseif nRecorded > nPlanned
    alignment.warnings(end+1) = sprintf( ...
        ['Detected %d extra Screen TTL onset(s). Ignored %d before and %d ' ...
        'after the sequence block that best matched the saved protocol.'], ...
        nRecorded-nPlanned, alignment.ignoredLeadingEdgeCount, ...
        alignment.ignoredTrailingEdgeCount);
end
if any(diff(risingSamples) <= 0)
    alignment.warnings(end+1) = ...
        "Screen TTL onset samples were not strictly increasing.";
end
end

function [selected, scores] = selectBestEdgeBlock( ...
        risingSamples, fallingSamples, plannedTrials, runData, ttlMode, fs)
% Pick a contiguous recorded block by its agreement with saved timing.

nPlanned = height(plannedTrials);
nCandidates = numel(risingSamples)-nPlanned+1;
scores = inf(nCandidates,1);
expectedIntervals = plannedTrials.durationSec(1:end-1);
if ismember('interStimulusSec', plannedTrials.Properties.VariableNames)
    expectedIntervals = expectedIntervals + ...
        plannedTrials.interStimulusSec(1:end-1);
end
expectedDurations = plannedTrials.durationSec;

% Prefer actual command timestamps saved during presentation. Nominal
% sequence timing remains the fallback for old or interrupted run files.
if isfield(runData,'presentation') && istable(runData.presentation)
    names = runData.presentation.Properties.VariableNames;
    if ismember('ttlHighSec',names)
        actualHigh = runData.presentation.ttlHighSec;
        actualIntervals = diff(actualHigh);
        valid = isfinite(actualIntervals);
        expectedIntervals(valid) = actualIntervals(valid);
    end
    if ttlMode == "epoch" && all(ismember( ...
            {'ttlHighSec','ttlLowSec'},names))
        actualDurations = runData.presentation.ttlLowSec - ...
            runData.presentation.ttlHighSec;
        valid = isfinite(actualDurations) & actualDurations > 0;
        expectedDurations(valid) = actualDurations(valid);
    end
end

for startIndex = 1:nCandidates
    edgeIndices = startIndex:(startIndex+nPlanned-1);
    observedIntervals = diff(risingSamples(edgeIndices))/fs;
    intervalScale = max(0.020, expectedIntervals);
    intervalError = sqrt(mean( ...
        ((observedIntervals-expectedIntervals)./intervalScale).^2));
    if isempty(intervalError) || isnan(intervalError)
        intervalError = 0;
    end

    durationError = 0;
    if ttlMode == "epoch"
        observedDurations = nan(nPlanned,1);
        for i = 1:nPlanned
            onset = risingSamples(edgeIndices(i));
            offset = fallingSamples(find(fallingSamples >= onset, ...
                1, 'first'));
            if ~isempty(offset)
                observedDurations(i) = (offset-onset)/fs;
            end
        end
        valid = isfinite(observedDurations);
        if any(valid)
            durationScale = max(0.020, expectedDurations(valid));
            durationError = sqrt(mean(((observedDurations(valid)- ...
                expectedDurations(valid))./durationScale).^2));
        else
            durationError = 1;
        end
    end
    scores(startIndex) = intervalError + durationError;
end

bestScore = min(scores);
% Prefer the later block only when scores are numerically indistinguishable.
% This resolves the common case of otherwise ambiguous reset pulses before
% the real sequence without overriding timing evidence for a leading block.
bestStart = find(scores <= bestScore+1e-12, 1, 'last');
selected = (bestStart:(bestStart+nPlanned-1))';
end
