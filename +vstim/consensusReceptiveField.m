function consensus = consensusReceptiveField(results)
%CONSENSUSRECEPTIVEFIELD Combine run estimates hierarchically by protocol.
% Each run is first combined within its mapping-protocol family. The family
% estimates are then combined into a cell estimate. At both levels,
% covariance-weighted means are used. The cross-protocol stage caps extreme
% precision and robustly downweights a family separated from the others.

if isstruct(results)
    results = num2cell(results);
end
eligible = false(numel(results),1);
for i = 1:numel(results)
    r = results{i};
    eligible(i) = isfield(r,'usableCenter') && r.usableCenter && ...
        all(isfinite([r.rfCenterAzimuthDeg,r.rfCenterElevationDeg])) && ...
        isfield(r,'centerCovarianceDeg2') && ...
        all(isfinite(r.centerCovarianceDeg2(:)));
end
results = results(eligible);
if isempty(results)
    error('vstim:NoUsableRFEstimates', ...
        'No loaded analysis has a usable RF center and covariance.')
end

n = numel(results);
runProtocol = strings(n,1);
family = strings(n,1);
runCenter = nan(n,2);
runCovariance = cell(n,1);
for i = 1:n
    r = results{i};
    runProtocol(i) = string(r.protocol);
    family(i) = protocolFamily(runProtocol(i));
    runCenter(i,:) = [r.rfCenterAzimuthDeg,r.rfCenterElevationDeg];
    runCovariance{i} = regularizeCovariance(r.centerCovarianceDeg2);
end

families = unique(family,'stable');
familyCenter = nan(numel(families),2);
familyCovariance = cell(numel(families),1);
familyInflation = nan(numel(families),1);
familyReducedDisagreement = nan(numel(families),1);
familyRunCount = zeros(numel(families),1);
for f = 1:numel(families)
    rows = family == families(f);
    [familyCenter(f,:),familyCovariance{f},details] = ...
        combineCenters(runCenter(rows,:),runCovariance(rows),false);
    familyInflation(f) = details.inflationFactor;
    familyReducedDisagreement(f) = details.reducedDisagreement;
    familyRunCount(f) = sum(rows);
end

[center,covariance,details] = combineCenters( ...
    familyCenter,familyCovariance,true);
ellipse = covarianceEllipse(covariance);
consensus.schemaVersion = "1.1.0";
consensus.createdAt = datetime('now');
consensus.rfCenterAzimuthDeg = center(1);
consensus.rfCenterElevationDeg = center(2);
consensus.centerCovarianceDeg2 = covariance;
consensus.confidenceEllipse95 = ellipse;
consensus.uncertaintyRadiusDeg = ellipse.semiMajorDeg;
consensus.inflationFactor = details.inflationFactor;
consensus.reducedDisagreement = details.reducedDisagreement;
consensus.protocolFamilyCount = numel(families);
consensus.runCount = n;
consensus.protocolFamilyRobustWeights = details.robustWeights;
consensus.runEstimates = table(runProtocol,family,runCenter(:,1), ...
    runCenter(:,2),runCovariance, ...
    'VariableNames',{'protocol','protocolFamily','azimuthDeg', ...
    'elevationDeg','centerCovarianceDeg2'});
consensus.protocolFamilies = table(families,familyRunCount, ...
    familyCenter(:,1),familyCenter(:,2),familyCovariance, ...
    familyInflation,familyReducedDisagreement,details.robustWeights, ...
    'VariableNames',{'protocolFamily','runCount','azimuthDeg', ...
    'elevationDeg','centerCovarianceDeg2','inflationFactor', ...
    'reducedDisagreement','consensusRobustWeight'});
consensus.warnings = strings(0,1);
if numel(families) == 1
    consensus.warnings(end+1) = ...
        "Consensus currently contains only one protocol family.";
end
if details.reducedDisagreement > 2
    consensus.warnings(end+1) = sprintf( ...
        ['Protocol families disagree more than expected from their ' ...
         'uncertainties (reduced disagreement %.2f).'], ...
        details.reducedDisagreement);
end
lowWeight = details.robustWeights<0.5;
if any(lowWeight)
    consensus.warnings(end+1) = ...
        "Robust consensus downweighted: "+strjoin(families(lowWeight),", ")+".";
end
end

function family = protocolFamily(protocol)
switch string(protocol)
    case "Moving bars"
        family = "Moving bars";
    case "Flashed bars"
        family = "Flashed bars";
    case "Sparse noise"
        family = "Sparse noise";
    case {"Fast Gabor tiling","Targeted Gabor grid"}
        family = "Gabor mapping";
    otherwise
        family = string(protocol);
end
end

function [center,covariance,details] = combineCenters( ...
        centers,covariances,useRobustWeights)
n = size(centers,1);
precisions = cell(n,1);
for i = 1:n
    precisions{i} = regularizeCovariance(covariances{i})\eye(2);
end

robustWeights = ones(n,1);
if useRobustWeights && n>=3
    % Prevent a nearly singular bootstrap covariance from overwhelming
    % several agreeing mapping methods.
    scalarPrecision = cellfun(@(p) trace(p)/2,precisions);
    precisionCap = 2*median(scalarPrecision);
    for i = 1:n
        if scalarPrecision(i)>precisionCap
            precisions{i} = precisions{i}* ...
                (precisionCap/scalarPrecision(i));
        end
    end
    center = median(centers,1);
    uncertaintyScale = cellfun(@(c) ...
        sqrt(trace(regularizeCovariance(c))/2),covariances);
    robustCutoffDeg = max(1,2.5*median(uncertaintyScale));
    for iteration = 1:20
        distance = sqrt(sum((centers-center).^2,2));
        outside = distance>robustCutoffDeg;
        robustWeights(:) = 1;
        robustWeights(outside) = ...
            (robustCutoffDeg./distance(outside)).^4;
        nextCenter = weightedMean(centers,precisions,robustWeights);
        if norm(nextCenter-center)<1e-6
            center = nextCenter;
            break
        end
        center = nextCenter;
    end
else
    center = weightedMean(centers,precisions,robustWeights);
end

precisionSum = zeros(2);
for i = 1:n
    precisionSum = precisionSum+robustWeights(i)*precisions{i};
end
fixedCovariance = precisionSum\eye(2);
q = 0;
robustQ = 0;
for i = 1:n
    difference = centers(i,:)'-center';
    q = q+difference'*precisions{i}*difference;
    robustQ = robustQ+robustWeights(i)* ...
        difference'*precisions{i}*difference;
end
degreesOfFreedom = max(2*(n-1),1);
if n == 1
    reduced = 0;
    inflation = 1;
else
    reduced = q/degreesOfFreedom;
    inflation = max(1,robustQ/degreesOfFreedom);
end
covariance = fixedCovariance*inflation;
details.q = q;
details.degreesOfFreedom = degreesOfFreedom;
details.reducedDisagreement = reduced;
details.inflationFactor = inflation;
details.robustWeights = robustWeights;
end

function center = weightedMean(centers,precisions,weights)
precisionSum = zeros(2);
weightedCenter = zeros(2,1);
for i = 1:size(centers,1)
    effectivePrecision = weights(i)*precisions{i};
    precisionSum = precisionSum+effectivePrecision;
    weightedCenter = weightedCenter+effectivePrecision*centers(i,:)';
end
center = (precisionSum\weightedCenter)';
end

function covariance = regularizeCovariance(covariance)
covariance = double(covariance);
covariance = (covariance+covariance')/2;
[vectors,values] = eig(covariance);
% A quarter-degree variance floor prevents numerical singularities from a
% small or accidentally identical bootstrap sample.
values = diag(max(diag(values),0.25^2));
covariance = vectors*values*vectors';
end

function ellipse = covarianceEllipse(covariance)
[vectors,values] = eig(covariance);
[eigenvalues,order] = sort(diag(values),'descend');
vectors = vectors(:,order);
semiAxes = sqrt(max(eigenvalues,0)*5.991);
ellipse.semiMajorDeg = semiAxes(1);
ellipse.semiMinorDeg = semiAxes(2);
ellipse.angleDeg = atan2d(vectors(2,1),vectors(1,1));
end
