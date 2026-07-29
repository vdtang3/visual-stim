function [anglesDeg, positionsCm, extentCm, spacingCm] = constantPixelAxis( ...
        monitorCenterCm, monitorSizeCm, distanceCm, extentDeg, spacingDeg)
%CONSTANTPIXELAXIS Uniformly tile a flat monitor in physical/pixel space.
% extentDeg and spacingDeg are converted to centimeters once at the angular
% monitor center. Every resulting tile then has identical physical and pixel
% dimensions. Returned angles describe the actual head-centered direction
% of each tile center and are saved for offline analysis.

centerDeg = atand(monitorCenterCm/distanceCm);
extentEdgesCm = distanceCm*tand(centerDeg + [-1 1]*extentDeg/2);
spacingEdgesCm = distanceCm*tand(centerDeg + [-1 1]*spacingDeg/2);
extentCm = diff(extentEdgesCm);
spacingCm = diff(spacingEdgesCm);

lowerEdgeCm = monitorCenterCm-monitorSizeCm/2;
upperEdgeCm = monitorCenterCm+monitorSizeCm/2;
nBelow = max(0, ceil((monitorCenterCm-extentCm/2-lowerEdgeCm)/spacingCm));
nAbove = max(0, ceil((upperEdgeCm-monitorCenterCm-extentCm/2)/spacingCm));
positionsCm = monitorCenterCm + (-nBelow:nAbove)*spacingCm;
anglesDeg = atand(positionsCm/distanceCm);
end
