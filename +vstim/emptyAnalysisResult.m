function result = emptyAnalysisResult(protocol)
%EMPTYANALYSISRESULT Shared result schema for offline protocol comparison.
result.schemaVersion = "1.1.0";
result.protocol = string(protocol);
result.responseSource = "spikes";
result.rfCenterAzimuthDeg = NaN;
result.rfCenterElevationDeg = NaN;
result.rfWidthAzimuthDeg = NaN;
result.rfWidthElevationDeg = NaN;
result.preferredLatencyMs = NaN;
result.peakLagMs = NaN;
result.preferredPolarity = NaN;
result.preferredOrientationDeg = NaN;
result.fitQuality = NaN;
result.fitSuccessful = false;
result.responseDynamicRange = NaN;
result.splitHalfReliability = NaN;
result.centerConfidenceIntervalDeg = nan(2,2);
result.centerCovarianceDeg2 = nan(2);
result.confidenceEllipse95 = struct('semiMajorDeg', NaN, ...
    'semiMinorDeg', NaN, 'angleDeg', NaN);
result.uncertaintyRadiusDeg = NaN;
result.edgeWarning = false;
result.usableCenter = false;
result.trialCount = 0;
result.spikeCount = 0;
result.bootstrapCentersDeg = zeros(0,2);
result.sync = struct();
result.durationComparison = table([30;60;90;120;180;Inf], ...
    nan(6,1), nan(6,1), nan(6,1), nan(6,1), nan(6,1), false(6,1), ...
    'VariableNames', {'durationSec', 'azimuthDeg', 'elevationDeg', ...
    'distanceFromFullDeg', 'fitQuality', 'splitHalfReliability', ...
    'usableCenter'});
result.referenceComparison = struct('available', false, ...
    'distanceDeg', NaN, 'azimuthErrorDeg', NaN, ...
    'elevationErrorDeg', NaN, 'within10Deg', false);
result.maps = struct();
result.profiles = struct();
result.warnings = strings(0,1);
end
