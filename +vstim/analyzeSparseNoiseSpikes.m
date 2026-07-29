function result = analyzeSparseNoiseSpikes(runData, data, alignment, options)
%ANALYZESPARSENOISESPIKES Fit lagged ridge maps to sparse-noise spike counts.

result = vstim.emptyAnalysisResult(runData.params.protocol);
result.trialCount = alignment.matchedTrialCount;
result.spikeCount = numel(data.spikes.spks);
result.sync = rmfield(alignment,'trials');
result.warnings = alignment.warnings;

n = alignment.matchedTrialCount;
patterns = double(runData.sequence.stimulusMatrix(:,1:n)');
stimulus = [patterns == 1, patterns == -1];
lags = options.testedLagsMs(:);
cvScores = nan(size(lags));
responses = cell(numel(lags),1);
for i = 1:numel(lags)
    responses{i} = laggedSpikeRates(alignment,data,lags(i), ...
        options.spikeBinMs);
    cvScores(i) = ridgeCrossValidation(stimulus,responses{i}, ...
        options.regularizationStrength,options.crossValidationFolds);
end
if all(~isfinite(cvScores))
    best = ceil(numel(lags)/2);
    result.warnings(end+1) = ...
        "Lag cross-validation was indeterminate; using the middle tested lag.";
else
    [~,best] = max(cvScores);
end
result.preferredLatencyMs = lags(best);
result.peakLagMs = lags(best);
y = responses{best};
[fit,map] = fitSparseMap(stimulus,y,runData.sequence.grid, ...
    options.regularizationStrength);
result.rfCenterAzimuthDeg = fit.centerAzimuthDeg;
result.rfCenterElevationDeg = fit.centerElevationDeg;
result.rfWidthAzimuthDeg = fit.sigmaAzimuthDeg;
result.rfWidthElevationDeg = fit.sigmaElevationDeg;
result.fitQuality = cvScores(best);
result.fitSuccessful = fit.success;
result.responseDynamicRange = range(map.combinedWeight);
peakResponse = max(map.combinedWeight);
result.usableCenter = fit.success && ...
    peakResponse >= options.minimumPeakResponseHz && ...
    result.responseDynamicRange >= ...
        options.minimumResponseDynamicRangeHz && ...
    cvScores(best) >= options.minimumFitQuality;
result.maps.white = map(:,{'locationIndex','azimuthDeg', ...
    'elevationDeg','whiteWeight'});
result.maps.black = map(:,{'locationIndex','azimuthDeg', ...
    'elevationDeg','blackWeight'});
result.maps.combined = map;
result.profiles.lagCrossValidation = table(lags,cvScores, ...
    'VariableNames',{'lagMs','crossValidatedCorrelation'});
result.edgeWarning = atMapEdge(fit,map);

odd = 1:2:n;
even = 2:2:n;
if numel(odd) >= 3 && numel(even) >= 3
    [~,oddMap] = fitSparseMap(stimulus(odd,:),y(odd), ...
        runData.sequence.grid,options.regularizationStrength);
    [~,evenMap] = fitSparseMap(stimulus(even,:),y(even), ...
        runData.sequence.grid,options.regularizationStrength);
    result.splitHalfReliability = vectorCorrelation( ...
        oddMap.combinedWeight,evenMap.combinedWeight);
end

rng(options.randomSeed);
centers = nan(options.bootstrapRepetitions,2);
for b = 1:options.bootstrapRepetitions
    idx = randi(n,n,1);
    bootFit = fitSparseMap(stimulus(idx,:),y(idx), ...
        runData.sequence.grid,options.regularizationStrength);
    centers(b,:) = [bootFit.centerAzimuthDeg,bootFit.centerElevationDeg];
end
result = vstim.finalizeRFUncertainty(result,centers);
if ~result.fitSuccessful || peakResponse < options.minimumPeakResponseHz || ...
        result.responseDynamicRange < ...
        options.minimumResponseDynamicRangeHz
    result.warnings(end+1) = sprintf( ...
        ['No usable sparse-noise map: peak weight %.3f, dynamic range ' ...
         '%.3f. RF center withheld.'],peakResponse,result.responseDynamicRange);
elseif cvScores(best) < options.minimumFitQuality
    result.warnings(end+1) = sprintf( ...
        'Peak-lag CV correlation %.3f is below the required %.3f.', ...
        cvScores(best),options.minimumFitQuality);
end
if result.edgeWarning
    result.warnings(end+1) = ...
        "The fitted sparse-noise center is at the edge of the sampled grid.";
end
end

function rates = laggedSpikeRates(alignment,data,lagMs,binMs)
spikes = double(data.spikes.spks(:));
fs = data.meta.fs;
startOffset = round(lagMs/1000*fs);
stopOffset = round((lagMs+binMs)/1000*fs);
rates = zeros(alignment.matchedTrialCount,1);
for i = 1:alignment.matchedTrialCount
    onset = alignment.trials.onsetSample(i);
    rates(i) = sum(spikes >= onset+startOffset & ...
        spikes < onset+stopOffset)/(binMs/1000);
end
end

function score = ridgeCrossValidation(X,y,lambda,foldCount)
n = size(X,1);
foldCount = min(max(2,foldCount),n);
fold = mod((1:n)'-1,foldCount)+1;
prediction = nan(n,1);
for k = 1:foldCount
    test = fold == k;
    beta = ridgeCoefficients(X(~test,:),y(~test),lambda);
    prediction(test) = beta(1)+X(test,:)*beta(2:end);
end
score = vectorCorrelation(y,prediction);
end

function [fit,map] = fitSparseMap(X,y,grid,lambda)
beta = ridgeCoefficients(X,y,lambda);
nLocations = size(X,2)/2;
white = beta(2:1+nLocations);
black = beta(2+nLocations:end);
% Only spike-rate increases contribute to the depolarizing RF estimate.
combined = hypot(max(white,0),max(black,0));
fit = vstim.fitGaussian2D(grid.azimuthDeg,grid.elevationDeg,combined);
map = table(grid.locationIndex,grid.azimuthDeg,grid.elevationDeg, ...
    white,black,combined,fit.prediction, ...
    'VariableNames',{'locationIndex','azimuthDeg','elevationDeg', ...
    'whiteWeight','blackWeight','combinedWeight', ...
    'gaussianPrediction'});
end

function beta = ridgeCoefficients(X,y,lambda)
X = double(X);
y = double(y(:));
muX = mean(X,1);
muY = mean(y);
Xc = X-muX;
yc = y-muY;
weights = (Xc'*Xc+lambda*eye(size(X,2)))\(Xc'*yc);
intercept = muY-muX*weights;
beta = [intercept;weights];
end

function r = vectorCorrelation(a,b)
valid = isfinite(a) & isfinite(b);
if sum(valid)<3 || std(a(valid))==0 || std(b(valid))==0
    r = NaN;
else
    c = corrcoef(a(valid),b(valid));
    r = c(1,2);
end
end

function tf = atMapEdge(fit,map)
az = unique(map.azimuthDeg);
el = unique(map.elevationDeg);
if ~fit.success || numel(az)<2 || numel(el)<2
    tf = true;
else
    tf = fit.centerAzimuthDeg <= min(az)+median(diff(sort(az)))/2 || ...
        fit.centerAzimuthDeg >= max(az)-median(diff(sort(az)))/2 || ...
        fit.centerElevationDeg <= min(el)+median(diff(sort(el)))/2 || ...
        fit.centerElevationDeg >= max(el)-median(diff(sort(el)))/2;
end
end
