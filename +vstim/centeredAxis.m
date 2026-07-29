function positions = centeredAxis(limitsDeg, centerDeg, spacingDeg)
%CENTEREDAXIS Tile an angular interval outward from a specified center.
% The center is always included when it lies within the monitor limits.

arguments
    limitsDeg (1,2) double
    centerDeg (1,1) double
    spacingDeg (1,1) double {mustBePositive}
end

if centerDeg < limitsDeg(1) || centerDeg > limitsDeg(2)
    error('vstim:CenterOutsideDisplay', ...
        'Monitor center %.2f deg lies outside [%.2f %.2f].', ...
        centerDeg, limitsDeg(1), limitsDeg(2))
end
nBelow = floor((centerDeg-limitsDeg(1))/spacingDeg);
nAbove = floor((limitsDeg(2)-centerDeg)/spacingDeg);
positions = centerDeg + (-nBelow:nAbove)*spacingDeg;
end
