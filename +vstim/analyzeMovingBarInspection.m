function inspection = analyzeMovingBarInspection(runData,data,alignment,options,rfResult)
%ANALYZEMOVINGBARINSPECTION Per-direction spike-position raster/PSTH evidence.
%   INSPECTION = ANALYZEMOVINGBARINSPECTION(RUNDATA,DATA,ALIGNMENT,OPTIONS,
%   RFRESULT) builds the raw response-structure evidence behind an already
%   -computed moving-bar RF estimate: for each sweep direction actually
%   presented, every trial's spike positions along the bar's trajectory
%   (raster material) and a smoothed, bootstrapped rate-vs-position PSTH
%   per polarity.
%
%   RFRESULT must be the VSTIM.ANALYZESPIKERECEPTIVEFIELD result already
%   computed for this run. Its own winning latency
%   (RFRESULT.PREFERREDLATENCYMS) is reused verbatim - this inspection
%   never re-derives a latency independently, so the raster reflects
%   exactly the same spike-to-position mapping the RF fit itself used.
%   RFRESULT.PROFILES.AZIMUTH/.ELEVATION (the RF fit's own combined-across-
%   direction Gaussian fit, including its predicted curve) are copied
%   through for the renderer to overlay directly, rather than re-fit here.
%
%   Position bin width reuses OPTIONS.POSITIONBINDEG (the same value the
%   RF fit used); bootstrap repetitions/seed reuse
%   OPTIONS.BOOTSTRAPREPETITIONS/OPTIONS.RANDOMSEED. Smoothing window width
%   is a display-only choice with no RF-fit equivalent to reuse.

smoothingWindowBins = 7;

trials = alignment.trials;
fs = data.meta.fs;
spikes = double(data.spikes.spks(:));
latencyMs = rfResult.preferredLatencyMs;
frameIntervalSec = nominalFrameInterval(runData);

nTrials = height(trials);
spikePositionsDegByTrial = cell(nTrials,1);
for i = 1:nTrials
    onset = trials.onsetSample(i);
    duration = trials.durationSec(i);
    visualTime = (spikes-onset)/fs-latencyMs/1000;
    use = visualTime >= 0 & visualTime < duration;
    spikePositionsDegByTrial{i} = vstim.movingBarSpikePositions( ...
        visualTime(use),trials(i,:),frameIntervalSec);
end

inspection.schemaVersion = "1.0.0";
inspection.preferredLatencyMs = latencyMs;
inspection.rfProfiles = rfResult.profiles;

directionOrder = ["left_to_right","right_to_left", ...
    "top_to_bottom","bottom_to_top"];
presentDirections = directionOrder(ismember(directionOrder,trials.direction));
directionBlocks = cell(numel(presentDirections),1);
for d = 1:numel(presentDirections)
    direction = presentDirections(d);
    directionRows = find(trials.direction==direction);
    axisName = trials.axis(directionRows(1));
    allCenters = cat(2,trials.frameCentersDeg{directionRows});
    lo = min(allCenters); hi = max(allCenters);
    edges = lo:options.positionBinDeg:hi;
    if edges(end) < hi
        edges(end+1) = hi; %#ok<AGROW>
    end
    binCenters = (edges(1:end-1)+edges(2:end))/2;

    polarities = unique(trials.polarity(directionRows));
    polarityBlocks = cell(numel(polarities),1);
    for p = 1:numel(polarities)
        polarityRows = directionRows(trials.polarity(directionRows)==polarities(p));
        nPolarityTrials = numel(polarityRows);
        countsPerTrial = nan(nPolarityTrials,numel(binCenters));
        for row = 1:nPolarityTrials
            countsPerTrial(row,:) = histcounts( ...
                spikePositionsDegByTrial{polarityRows(row)},edges);
        end
        smoothedCountsPerTrial = smoothdata(countsPerTrial,2,'gaussian', ...
            smoothingWindowBins);
        meanSpikesPerTrial = mean(smoothedCountsPerTrial,1);

        rng(options.randomSeed);
        bootstrapMeans = nan(options.bootstrapRepetitions,numel(binCenters));
        for b = 1:options.bootstrapRepetitions
            resampled = vstim.stratifiedBootstrapIndices(trials(polarityRows,:),{});
            bootstrapMeans(b,:) = mean(smoothedCountsPerTrial(resampled,:),1);
        end
        lowerBand = percentile(bootstrapMeans,2.5);
        upperBand = percentile(bootstrapMeans,97.5);

        polarityBlocks{p} = struct( ...
            'polarity',polarities(p), ...
            'spikePositionsDegByTrial',{spikePositionsDegByTrial(polarityRows)}, ...
            'binCentersDeg',binCenters, ...
            'meanSpikesPerTrial',meanSpikesPerTrial, ...
            'lowerBandSpikesPerTrial',lowerBand, ...
            'upperBandSpikesPerTrial',upperBand);
    end
    directionBlocks{d} = struct('direction',direction,'axis',axisName, ...
        'polarities',{polarityBlocks});
end
inspection.directions = directionBlocks;
end

function [intervalSec,source] = nominalFrameInterval(runData)
% Same fallback order vstim.analyzeMovingBarsSpikes.m uses, so this
% inspection reconstructs frame timing identically to the RF fit.
intervalSec = NaN;
source = "trial duration / frame count";
if isfield(runData,'display') && isfield(runData.display,'ifiSec')
    intervalSec = double(runData.display.ifiSec);
    source = "measured display IFI";
elseif isfield(runData.sequence,'nominalFrameRate')
    intervalSec = 1/double(runData.sequence.nominalFrameRate);
    source = "nominal frame rate";
end
if ~isscalar(intervalSec) || ~isfinite(intervalSec) || intervalSec <= 0
    intervalSec = NaN;
end
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
