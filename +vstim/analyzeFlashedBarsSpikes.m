function result = analyzeFlashedBarsSpikes(runData, data, alignment, options)
%ANALYZEFLASHEDBARSSPIKES Estimate orthogonal RF profiles from spike counts.

trials = vstim.extractSpikeResponses(alignment, data, ...
    options.responseWindowMs, options.baselineWindowMs);
result = vstim.emptyAnalysisResult(runData.params.protocol);
result.trialCount = height(trials);
result.spikeCount = numel(data.spikes.spks);
result.sync = rmfield(alignment, 'trials');
result.warnings = alignment.warnings;

[azFit, azProfile] = fitAxis(trials, "azimuth");
[elFit, elProfile] = fitAxis(trials, "elevation");
result.rfCenterAzimuthDeg = azFit.center;
result.rfCenterElevationDeg = elFit.center;
result.rfWidthAzimuthDeg = azFit.sigma;
result.rfWidthElevationDeg = elFit.sigma;
result.fitQuality = mean([azFit.rSquared elFit.rSquared], 'omitnan');
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
result.profiles.azimuth = azProfile;
result.profiles.elevation = elProfile;
result.splitHalfReliability = mean([ ...
    vstim.mapReliability(trials(trials.axis=="azimuth",:), ...
        {'positionDeg','polarity'}, 'evokedSpikeRateHz'), ...
    vstim.mapReliability(trials(trials.axis=="elevation",:), ...
        {'positionDeg','polarity'}, 'evokedSpikeRateHz')], 'omitnan');

polarities = unique(trials.polarity);
polarityMean = nan(size(polarities));
for i = 1:numel(polarities)
    polarityMean(i) = mean(trials.evokedSpikeRateHz( ...
        trials.polarity == polarities(i)),'omitnan');
end
[~, preferred] = max(polarityMean);
result.preferredPolarity = polarities(preferred);
result.edgeWarning = atProfileEdge(azFit.center, azProfile.positionDeg) || ...
    atProfileEdge(elFit.center, elProfile.positionDeg);

rng(options.randomSeed);
centers = nan(options.bootstrapRepetitions,2);
for b = 1:options.bootstrapRepetitions
    idx = vstim.stratifiedBootstrapIndices(trials, ...
        {'axis','positionDeg','polarity'});
    sampled = trials(idx,:);
    azBoot = fitAxis(sampled,"azimuth");
    elBoot = fitAxis(sampled,"elevation");
    centers(b,1) = azBoot.center;
    centers(b,2) = elBoot.center;
end
result = vstim.finalizeRFUncertainty(result, centers);
if ~result.fitSuccessful || peakResponse < options.minimumPeakResponseHz || ...
        result.responseDynamicRange < ...
        options.minimumResponseDynamicRangeHz
    result.warnings(end+1) = sprintf( ...
        ['No usable two-axis bar response: peak %.3f spikes/s, minimum ' ...
         'axis dynamic range %.3f spikes/s. RF center withheld.'], ...
        peakResponse,result.responseDynamicRange);
elseif result.fitQuality < options.minimumFitQuality
    result.warnings(end+1) = sprintf( ...
        'Bar fit quality %.3f is below the required %.3f.', ...
        result.fitQuality,options.minimumFitQuality);
end
if result.edgeWarning
    result.warnings(end+1) = ...
        "The fitted center is at the edge of a sampled bar profile.";
end
end

function [fit, profile] = fitAxis(trials, axisName)
rows = trials.axis == axisName;
positions = unique(trials.positionDeg(rows));
polarities = unique(trials.polarity(rows));
responses = nan(numel(positions),numel(polarities));
for i = 1:numel(positions)
    for j = 1:numel(polarities)
        select = rows & trials.positionDeg == positions(i) & ...
            trials.polarity == polarities(j);
        responses(i,j) = mean(trials.evokedSpikeRateHz(select),'omitnan');
    end
end
% Polarity channels are kept separate and combined by magnitude so that
% ON and OFF responses cannot cancel each other.
combined = sqrt(sum(max(responses,0).^2,2));
fit = vstim.fitGaussian1D(positions,combined);
profile = table(positions,responses,combined,fit.prediction, ...
    'VariableNames', {'positionDeg','polarityResponsesHz', ...
    'combinedResponseHz','gaussianPredictionHz'});
profile.Properties.UserData.polarities = polarities;
end

function tf = atProfileEdge(center, positions)
positions = sort(unique(positions));
if numel(positions) < 2 || ~isfinite(center)
    tf = true;
else
    margin = median(diff(positions))/2;
    tf = center <= positions(1)+margin || center >= positions(end)-margin;
end
end
