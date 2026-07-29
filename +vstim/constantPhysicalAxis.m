function [anglesDeg, positionsCm] = constantPhysicalAxis( ...
        monitorCenterCm, monitorSizeCm, distanceCm, extentCm, spacingCm)
%CONSTANTPHYSICALAXIS Tile uniformly in monitor centimeters.

lowerEdgeCm = monitorCenterCm-monitorSizeCm/2;
upperEdgeCm = monitorCenterCm+monitorSizeCm/2;
nBelow = max(0, ceil((monitorCenterCm-extentCm/2-lowerEdgeCm)/spacingCm));
nAbove = max(0, ceil((upperEdgeCm-monitorCenterCm-extentCm/2)/spacingCm));
positionsCm = monitorCenterCm + (-nBelow:nAbove)*spacingCm;
anglesDeg = atand(positionsCm/distanceCm);
end
