function result = finalizeRFUncertainty(result, bootstrapCenters)
%FINALIZERFUNCERTAINTY Add bootstrap confidence bounds and ellipse summary.

centers = double(bootstrapCenters);
centers = centers(all(isfinite(centers),2),:);
result.bootstrapCentersDeg = centers;
fitWasUsable = result.usableCenter;
if ~fitWasUsable
    result.usableCenter = false;
    return
end
if size(centers,1) < 10
    result.warnings(end+1) = ...
        "Fewer than 10 successful bootstrap fits; uncertainty is unreliable.";
    result.usableCenter = false;
    return
end

result.centerConfidenceIntervalDeg = [ ...
    percentile(centers(:,1),2.5), percentile(centers(:,2),2.5); ...
    percentile(centers(:,1),97.5), percentile(centers(:,2),97.5)];
result.centerCovarianceDeg2 = cov(centers);
[vectors, values] = eig(result.centerCovarianceDeg2);
[eigenvalues, order] = sort(diag(values), 'descend');
vectors = vectors(:,order);
semiAxes = sqrt(max(eigenvalues,0)*5.991); % 95% chi-square contour, df=2
result.confidenceEllipse95.semiMajorDeg = semiAxes(1);
result.confidenceEllipse95.semiMinorDeg = semiAxes(2);
result.confidenceEllipse95.angleDeg = atan2d(vectors(2,1),vectors(1,1));
result.uncertaintyRadiusDeg = semiAxes(1);
result.usableCenter = fitWasUsable && ...
    all(isfinite([result.rfCenterAzimuthDeg, ...
    result.rfCenterElevationDeg])) && isfinite(result.fitQuality);
end

function q = percentile(x, p)
x = sort(x(:));
position = 1+(numel(x)-1)*p/100;
lo = floor(position);
hi = ceil(position);
if lo == hi
    q = x(lo);
else
    q = x(lo)+(position-lo)*(x(hi)-x(lo));
end
end
