function cfg = normalizeDisplayGeometry(cfg)
%NORMALIZEDISPLAYGEOMETRY Derive angular center and limits from centimeters.
% Angular fields are outputs of the physical geometry, never independent
% calibration inputs.

d = cfg.display.viewingDistanceCm;
x = cfg.display.monitorCenterXcm;
y = cfg.display.monitorCenterYcm;
w = cfg.display.monitorWidthCm;
h = cfg.display.monitorHeightCm;

if abs(y) >= d
    error('vstim:InvalidMonitorGeometry', ...
        'Vertical offset must be smaller than eye-to-monitor-center distance.')
end
horizontalDistance = sqrt(d^2-y^2);
if abs(x) >= horizontalDistance
    error('vstim:InvalidMonitorGeometry', ...
        ['Horizontal offset must be smaller than the horizontal component ' ...
         'of eye-to-monitor-center distance.'])
end
forwardDistance = sqrt(horizontalDistance^2-x^2);

centerAz = atan2d(x, forwardDistance);
centerEl = atan2d(y, horizontalDistance);
halfAz = atand((w/2)/horizontalDistance);

cfg.display.monitorHorizontalDistanceCm = horizontalDistance;
cfg.display.monitorForwardDistanceCm = forwardDistance;
cfg.display.monitorCenterAzimuthDeg = centerAz;
cfg.display.monitorCenterElevationDeg = centerEl;
cfg.display.azimuthLimitsDeg = centerAz + [-halfAz halfAz];
cfg.display.elevationLimitsDeg = atan2d(y + [-h/2 h/2], horizontalDistance);
end
