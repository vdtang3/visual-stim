function geometry = visualGeometry(windowRect, cfg)
%VISUALGEOMETRY Build linear conversions between nominal degrees and pixels.
% The calibrated angular limits label the edges of the flat display. No
% position-dependent tangent correction is applied here; optional
% Psychtoolbox geometry correction is handled separately by PsychImaging.

widthPx = RectWidth(windowRect);
heightPx = RectHeight(windowRect);
geometry.windowRect = windowRect;
geometry.centerPx = [mean(windowRect([1 3])), mean(windowRect([2 4]))];
geometry.pixelsPerCm = [widthPx/cfg.display.monitorWidthCm, ...
    heightPx/cfg.display.monitorHeightCm];
% One center-calibrated scale is used for unwarped circular stimuli. It
% preserves a circular pixel shape and the requested size at screen center.
geometry.pixelsPerDegAtCenter = mean(geometry.pixelsPerCm) * ...
    2*cfg.display.monitorHorizontalDistanceCm*tand(0.5);
azimuthSpanDeg = diff(cfg.display.azimuthLimitsDeg);
elevationSpanDeg = diff(cfg.display.elevationLimitsDeg);
pixelsPerDeg = [widthPx/azimuthSpanDeg, heightPx/elevationSpanDeg];
geometry.pixelsPerDeg = pixelsPerDeg;
geometry.degToPxX = @(deg) windowRect(1) + ...
    (deg-cfg.display.azimuthLimitsDeg(1))*pixelsPerDeg(1);
geometry.degToPxY = @(deg) windowRect(4) - ...
    (deg-cfg.display.elevationLimitsDeg(1))*pixelsPerDeg(2);
geometry.sizeDegToPx = @(degXY) double(degXY).*pixelsPerDeg;
end
