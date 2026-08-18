function result = analyzeMovingBarsSpikes(runData,data,alignment,options)
%ANALYZEMOVINGBARSSPIKES Reconstruct spatial spike profiles during sweeps.

trials = alignment.trials;
result = vstim.emptyAnalysisResult(runData.params.protocol);
result.trialCount = height(trials);
result.spikeCount = numel(data.spikes.spks);
result.sync = rmfield(alignment,'trials');
result.warnings = alignment.warnings;
[frameIntervalSec,nominalIntervalSource] = nominalFrameInterval(runData);
actualTiming = trials.frameTimingSource == "actual";
result.movingBarTiming.actualTrialCount = sum(actualTiming);
result.movingBarTiming.nominalTrialCount = sum(~actualTiming);
result.movingBarTiming.nominalFrameIntervalSec = frameIntervalSec;
result.movingBarTiming.nominalFrameIntervalSource = nominalIntervalSource;
if any(~actualTiming)
    result.warnings(end+1) = sprintf( ...
        ['Used nominal index-based frame timing for %d moving-bar sweep(s) ' ...
         'because actual saved flip timing was unavailable.'],sum(~actualTiming));
end
if height(trials) < options.minimumSweeps
    result.warnings(end+1) = sprintf( ...
        'Only %d sweeps matched; the configured minimum is %d.', ...
        height(trials),options.minimumSweeps);
end

lags = options.spikeLatencyRangeMs(1):options.spikeBinMs: ...
    options.spikeLatencyRangeMs(2);
agreement = nan(numel(lags),1);
for i = 1:numel(lags)
    profiles = buildProfiles(trials,data,lags(i),options.positionBinDeg, ...
        frameIntervalSec);
    agreement(i) = oppositeDirectionAgreement(profiles);
end
if all(~isfinite(agreement))
    best = ceil(numel(lags)/2);
    result.warnings(end+1) = ...
        "Opposite-direction latency agreement was indeterminate.";
else
    [~,best] = max(agreement);
end
latency = lags(best);
profiles = buildProfiles(trials,data,latency,options.positionBinDeg, ...
    frameIntervalSec);
[azFit,azProfile] = fitAxis(profiles,"azimuth");
[elFit,elProfile] = fitAxis(profiles,"elevation");
result.preferredLatencyMs = latency;
result.peakLagMs = latency;
result.rfCenterAzimuthDeg = azFit.center;
result.rfCenterElevationDeg = elFit.center;
result.rfWidthAzimuthDeg = azFit.sigma;
result.rfWidthElevationDeg = elFit.sigma;
result.fitQuality = mean([azFit.rSquared,elFit.rSquared],'omitnan');
allCombined = [azProfile.combinedResponseHz; ...
    elProfile.combinedResponseHz];
peakResponse = max(allCombined);
result.responseDynamicRange = min([ ...
    range(azProfile.combinedResponseHz), ...
    range(elProfile.combinedResponseHz)]);
result.fitSuccessful = azFit.success && elFit.success;
result.usableCenter = result.fitSuccessful && ...
    peakResponse >= options.minimumPeakResponseHz && ...
    result.responseDynamicRange >= ...
        options.minimumResponseDynamicRangeHz && ...
    result.fitQuality >= options.minimumFitQuality;
result.splitHalfReliability = agreement(best);
result.profiles.azimuth = azProfile;
result.profiles.elevation = elProfile;
result.profiles.latencyAgreement = table(lags(:),agreement, ...
    'VariableNames',{'lagMs','oppositeDirectionCorrelation'});
result.edgeWarning = atProfileEdge(azFit.center,azProfile.positionDeg) || ...
    atProfileEdge(elFit.center,elProfile.positionDeg);

rng(options.randomSeed);
centers = nan(options.bootstrapRepetitions,2);
for b = 1:options.bootstrapRepetitions
    idx = vstim.stratifiedBootstrapIndices(trials, ...
        {'direction','polarity'});
    bootProfiles = buildProfiles(trials(idx,:),data,latency, ...
        options.positionBinDeg,frameIntervalSec);
    azBoot = fitAxis(bootProfiles,"azimuth");
    elBoot = fitAxis(bootProfiles,"elevation");
    centers(b,:) = [azBoot.center,elBoot.center];
end
result = vstim.finalizeRFUncertainty(result,centers);
if ~result.fitSuccessful || peakResponse < options.minimumPeakResponseHz || ...
        result.responseDynamicRange < ...
        options.minimumResponseDynamicRangeHz
    result.warnings(end+1) = sprintf( ...
        ['No usable moving-bar response: peak %.3f spikes/s, minimum axis ' ...
         'dynamic range %.3f spikes/s. RF center withheld.'], ...
        peakResponse,result.responseDynamicRange);
elseif result.fitQuality < options.minimumFitQuality
    result.warnings(end+1) = sprintf( ...
        'Moving-bar fit quality %.3f is below the required %.3f.', ...
        result.fitQuality,options.minimumFitQuality);
end
if result.edgeWarning
    result.warnings(end+1) = ...
        "The fitted center is at the edge of a moving-bar profile.";
end
end

function profiles = buildProfiles( ...
        trials,data,latencyMs,binWidthDeg,frameIntervalSec)
spikes = double(data.spikes.spks(:));
fs = data.meta.fs;
axesUsed = unique(trials.axis);
profiles = table();
for a = 1:numel(axesUsed)
    axisName = axesUsed(a);
    axisRows = trials.axis == axisName;
    allCenters = cat(2,trials.frameCentersDeg{axisRows});
    lo = min(allCenters);
    hi = max(allCenters);
    edges = lo:binWidthDeg:hi;
    if edges(end) < hi
        edges(end+1) = hi; %#ok<AGROW>
    end
    centers = (edges(1:end-1)+edges(2:end))/2;
    directions = unique(trials.direction(axisRows));
    polarities = unique(trials.polarity(axisRows));
    for d = 1:numel(directions)
        for p = 1:numel(polarities)
            selected = find(axisRows & trials.direction==directions(d) & ...
                trials.polarity==polarities(p));
            trialRates = nan(numel(selected),numel(centers));
            for s = 1:numel(selected)
                tr = trials(selected(s),:);
                onset = tr.onsetSample;
                duration = tr.durationSec;
                visualTime = (spikes-onset)/fs-latencyMs/1000;
                use = visualTime >= 0 & visualTime < duration;
                spikePosition = vstim.movingBarSpikePositions( ...
                    visualTime(use),tr,frameIntervalSec);
                counts = histcounts(spikePosition,edges);
                occupancy = duration/numel(centers);
                baseline = sum(spikes >= onset-round(0.1*fs) & ...
                    spikes < onset)/0.1;
                trialRates(s,:) = counts/occupancy-baseline;
            end
            block = table(repmat(axisName,numel(centers),1), ...
                centers(:),repmat(directions(d),numel(centers),1), ...
                repmat(polarities(p),numel(centers),1), ...
                mean(trialRates,1,'omitnan')', ...
                'VariableNames',{'axis','positionDeg','direction', ...
                'polarity','responseHz'});
            profiles = [profiles;block]; %#ok<AGROW>
        end
    end
end
end

function [intervalSec,source] = nominalFrameInterval(runData)
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

function agreement = oppositeDirectionAgreement(profiles)
values = nan(2,1);
values(1) = directionPair(profiles,"left_to_right","right_to_left");
values(2) = directionPair(profiles,"bottom_to_top","top_to_bottom");
agreement = mean(values,'omitnan');
end

function r = directionPair(profiles,first,second)
a = profiles(profiles.direction==first,:);
b = profiles(profiles.direction==second,:);
if isempty(a) || isempty(b)
    r = NaN;
    return
end
[positions,~,group] = unique(a.positionDeg);
responseA = accumarray(group,a.responseHz,[],@mean);
[positionsB,~,groupB] = unique(b.positionDeg);
responseB = accumarray(groupB,b.responseHz,[],@mean);
responseB = interp1(positionsB,responseB,positions,'linear',NaN);
valid = isfinite(responseA) & isfinite(responseB);
if sum(valid)<3 || std(responseA(valid))==0 || std(responseB(valid))==0
    r = NaN;
else
    c = corrcoef(responseA(valid),responseB(valid));
    r = c(1,2);
end
end

function [fit,profile] = fitAxis(profiles,axisName)
rows = profiles.axis == axisName;
positions = unique(profiles.positionDeg(rows));
response = nan(size(positions));
for i = 1:numel(positions)
    values = profiles.responseHz(rows & ...
        profiles.positionDeg==positions(i));
    response(i) = sqrt(mean(max(values,0).^2,'omitnan'));
end
fit = vstim.fitGaussian1D(positions,response);
profile = table(positions,response,fit.prediction, ...
    'VariableNames',{'positionDeg','combinedResponseHz', ...
    'gaussianPredictionHz'});
end

function tf = atProfileEdge(center,positions)
positions = sort(unique(positions));
if numel(positions)<2 || ~isfinite(center)
    tf = true;
else
    tf = center <= positions(1)+median(diff(positions))/2 || ...
        center >= positions(end)-median(diff(positions))/2;
end
end
