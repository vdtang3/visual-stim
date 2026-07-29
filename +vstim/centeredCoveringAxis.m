function positions = centeredCoveringAxis(limitsDeg, centerDeg, spacingDeg, extentDeg)
%CENTEREDCOVERINGAXIS Tile outward until stimulus extents cover both edges.
% The final center may lie just outside a monitor limit; Psychtoolbox clips
% that tile at the window boundary. This avoids untiled edge strips.

arguments
    limitsDeg (1,2) double
    centerDeg (1,1) double
    spacingDeg (1,1) double {mustBePositive}
    extentDeg (1,1) double {mustBePositive}
end

halfExtent = extentDeg/2;
nBelow = max(0, ceil((centerDeg-halfExtent-limitsDeg(1))/spacingDeg));
nAbove = max(0, ceil((limitsDeg(2)-centerDeg-halfExtent)/spacingDeg));
positions = centerDeg + (-nBelow:nAbove)*spacingDeg;
end
