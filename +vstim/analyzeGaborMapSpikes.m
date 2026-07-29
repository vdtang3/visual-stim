function result = analyzeGaborMapSpikes(runData, data, alignment, options)
%ANALYZEGABORMAPSPIKES Map spike responses after pooling orientations.

trials = vstim.extractSpikeResponses(alignment, data, ...
    options.responseWindowMs, options.baselineWindowMs);
result = vstim.emptyAnalysisResult(runData.params.protocol);
result.trialCount = height(trials);
result.spikeCount = numel(data.spikes.spks);
result.sync = rmfield(alignment,'trials');
result.warnings = alignment.warnings;

[fit, map] = fitMap(trials);
result.rfCenterAzimuthDeg = fit.centerAzimuthDeg;
result.rfCenterElevationDeg = fit.centerElevationDeg;
result.rfWidthAzimuthDeg = fit.sigmaAzimuthDeg;
result.rfWidthElevationDeg = fit.sigmaElevationDeg;
result.fitQuality = fit.rSquared;
fitResponse = max(map.responseHz,0);
result.fitSuccessful = fit.success;
result.responseDynamicRange = max(fitResponse)-min(fitResponse);
peakResponse = max(fitResponse);
result.usableCenter = fit.success && ...
    peakResponse >= options.minimumPeakResponseHz && ...
    result.responseDynamicRange >= ...
        options.minimumResponseDynamicRangeHz && ...
    fit.rSquared >= options.minimumFitQuality;
result.maps.combined = map;
result.preferredOrientationDeg = NaN;
result.splitHalfReliability = vstim.mapReliability(trials, ...
    {'positionIndex','orientationDeg'}, 'evokedSpikeRateHz');
result.edgeWarning = atMapEdge(fit,map);

rng(options.randomSeed);
centers = nan(options.bootstrapRepetitions,2);
for b = 1:options.bootstrapRepetitions
    idx = vstim.stratifiedBootstrapIndices(trials, ...
        {'positionIndex','orientationDeg'});
    bootFit = fitMap(trials(idx,:));
    centers(b,:) = [bootFit.centerAzimuthDeg,bootFit.centerElevationDeg];
end
result = vstim.finalizeRFUncertainty(result,centers);
if ~result.fitSuccessful || peakResponse < options.minimumPeakResponseHz || ...
        result.responseDynamicRange < ...
        options.minimumResponseDynamicRangeHz
    result.warnings(end+1) = sprintf( ...
        ['No usable spatial response: peak %.3f spikes/s, dynamic range ' ...
         '%.3f spikes/s. RF center withheld.'], ...
        peakResponse,result.responseDynamicRange);
elseif fit.rSquared < options.minimumFitQuality
    result.warnings(end+1) = sprintf( ...
        'Gaussian fit quality %.3f is below the required %.3f.', ...
        fit.rSquared,options.minimumFitQuality);
end
if result.edgeWarning
    result.warnings(end+1) = ...
        "The fitted center is at the edge of the sampled Gabor grid.";
end
end

function [fit,map] = fitMap(trials)
positions = unique(trials.positionIndex,'stable');
azimuth = nan(numel(positions),1);
elevation = azimuth;
response = azimuth;
for i = 1:numel(positions)
    rows = trials.positionIndex == positions(i);
    azimuth(i) = trials.azimuthDeg(find(rows,1));
    elevation(i) = trials.elevationDeg(find(rows,1));
    % Orientation is intentionally pooled; this GUI does not estimate
    % orientation preference from the fast or targeted Gabor grids.
    response(i) = mean(trials.evokedSpikeRateHz(rows),'omitnan');
end
fit = vstim.fitGaussian2D(azimuth,elevation,max(response,0));
map = table(positions,azimuth,elevation,response,fit.prediction, ...
    'VariableNames', {'positionIndex','azimuthDeg','elevationDeg', ...
    'responseHz','gaussianPredictionHz'});
end

function tf = atMapEdge(fit,map)
az = unique(map.azimuthDeg);
el = unique(map.elevationDeg);
if ~fit.success || numel(az)<2 || numel(el)<2
    tf = true;
    return
end
azMargin = median(diff(sort(az)))/2;
elMargin = median(diff(sort(el)))/2;
tf = fit.centerAzimuthDeg <= min(az)+azMargin || ...
    fit.centerAzimuthDeg >= max(az)-azMargin || ...
    fit.centerElevationDeg <= min(el)+elMargin || ...
    fit.centerElevationDeg >= max(el)-elMargin;
end
