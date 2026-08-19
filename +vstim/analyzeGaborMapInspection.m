function inspection = analyzeGaborMapInspection(runData,data,alignment,options)
%ANALYZEGABORMAPINSPECTION Per-position time-resolved PSTH evidence.
%   INSPECTION = ANALYZEGABORMAPINSPECTION(RUNDATA,DATA,ALIGNMENT,OPTIONS)
%   builds the raw response-structure evidence behind an already-computed
%   Gabor-map RF estimate: for each tested visual-field position, a
%   smoothed, bootstrapped, time-binned PSTH (onset-aligned), with
%   orientation pooled the same way VSTIM.ANALYZEGABORMAPSPIKES.M pools it
%   for the RF fit itself.
%
%   Unlike moving bars, the RF fit here produces one scalar evoked rate per
%   position with no time-resolved equivalent, so the time bin width and
%   smoothing window are new, display-only choices (no existing value to
%   reuse). Bootstrap repetitions/seed reuse OPTIONS.BOOTSTRAPREPETITIONS/
%   OPTIONS.RANDOMSEED, matching the RF fit's own bootstrap.
%
%   Azimuth/elevation axes are derived directly from the tested trials
%   (not from protocol-specific sequence fields), so this also works for
%   Targeted Gabor grid data if ever wired into a caller.

binWidthMs = 10;
smoothingWindowBins = 5;

trials = alignment.trials;
fs = data.meta.fs;
spikes = double(data.spikes.spks(:));
displayWindowMs = [-100,max(trials.durationSec)*1000+100];

positions = unique(trials.positionIndex,'stable');
azimuthAxisDeg = sort(unique(trials.azimuthDeg));
elevationAxisDeg = sort(unique(trials.elevationDeg));

positionBlocks = cell(numel(positions),1);
for i = 1:numel(positions)
    rows = find(trials.positionIndex==positions(i));
    azimuthDeg = trials.azimuthDeg(rows(1));
    elevationDeg = trials.elevationDeg(rows(1));

    displaySpikeTimesMs = cell(numel(rows),1);
    for row = 1:numel(rows)
        onset = trials.onsetSample(rows(row));
        bounds = onset+round(displayWindowMs/1000*fs);
        inWindow = spikes >= bounds(1) & spikes < bounds(2);
        displaySpikeTimesMs{row} = (spikes(inWindow)-onset)/fs*1000;
    end

    [meanRateHz,lowerBandHz,upperBandHz,binCentersMs] = bootstrappedPsth( ...
        displaySpikeTimesMs,trials(rows,:),displayWindowMs,binWidthMs, ...
        smoothingWindowBins,options.bootstrapRepetitions,options.randomSeed);

    positionBlocks{i} = struct('positionIndex',positions(i), ...
        'azimuthDeg',azimuthDeg,'elevationDeg',elevationDeg, ...
        'trialCount',numel(rows),'binCentersMs',binCentersMs, ...
        'meanRateHz',meanRateHz,'lowerBandHz',lowerBandHz, ...
        'upperBandHz',upperBandHz);
end

inspection.schemaVersion = "1.0.0";
inspection.displayWindowMs = displayWindowMs;
inspection.responseWindowMs = options.responseWindowMs;
inspection.baselineWindowMs = options.baselineWindowMs;
inspection.azimuthAxisDeg = azimuthAxisDeg;
inspection.elevationAxisDeg = elevationAxisDeg;
inspection.positions = positionBlocks;
end

function [meanRateHz,lowerBandHz,upperBandHz,binCentersMs] = bootstrappedPsth( ...
        displaySpikeTimesMs,positionTrials,displayWindowMs,binWidthMs, ...
        smoothingWindowBins,bootstrapRepetitions,randomSeed)
binEdgesMs = displayWindowMs(1):binWidthMs:displayWindowMs(2);
binCentersMs = binEdgesMs(1:end-1)+binWidthMs/2;
nTrials = numel(displaySpikeTimesMs);

countsPerTrial = nan(nTrials,numel(binCentersMs));
for i = 1:nTrials
    countsPerTrial(i,:) = histcounts(displaySpikeTimesMs{i},binEdgesMs);
end
ratePerTrial = countsPerTrial/(binWidthMs/1000);
smoothedRatePerTrial = smoothdata(ratePerTrial,2,'gaussian',smoothingWindowBins);

meanRateHz = mean(smoothedRatePerTrial,1);
rng(randomSeed);
bootstrapMeans = nan(bootstrapRepetitions,numel(binCentersMs));
for b = 1:bootstrapRepetitions
    resampled = vstim.stratifiedBootstrapIndices(positionTrials,{});
    bootstrapMeans(b,:) = mean(smoothedRatePerTrial(resampled,:),1);
end
lowerBandHz = percentile(bootstrapMeans,2.5);
upperBandHz = percentile(bootstrapMeans,97.5);
end

function q = percentile(bootstrapMeans,p)
% Same order-statistic interpolation as vstim.finalizeRFUncertainty's own
% (private) percentile helper, applied per bin (column) instead of scalar.
sortedMeans = sort(bootstrapMeans,1);
n = size(sortedMeans,1);
position = 1+(n-1)*p/100;
lo = floor(position); hi = ceil(position);
if lo==hi
    q = sortedMeans(lo,:);
else
    q = sortedMeans(lo,:)+(position-lo)*(sortedMeans(hi,:)-sortedMeans(lo,:));
end
end
