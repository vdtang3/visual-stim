function [anglesDeg, positionsCm, extentCm, spacingCm] = monitorAxis( ...
        cfg, axisName, extentDeg, spacingDeg)
%MONITORAXIS Constant-physical/pixel positions on a vertical toe-in monitor.
% The monitor's horizontal normal points toward the animal in top view.

g = cfg.display;
h = g.monitorHorizontalDistanceCm;

switch string(axisName)
    case "azimuth"
        % Local horizontal monitor coordinate u=0 is the monitor center.
        % Azimuth is centerAz + atan(u / horizontal center distance).
        extentCm = 2*h*tand(extentDeg/2);
        spacingCm = 2*h*tand(spacingDeg/2);
        [~, positionsCm] = vstim.constantPhysicalAxis(0, ...
            g.monitorWidthCm, h, extentCm, spacingCm);
        anglesDeg = g.monitorCenterAzimuthDeg + atand(positionsCm/h);

    case "elevation"
        % At the horizontal monitor center, local vertical coordinate v is
        % added to the measured eye-relative center height.
        centerEl = g.monitorCenterElevationDeg;
        extentCm = diff(h*tand(centerEl + [-1 1]*extentDeg/2));
        spacingCm = diff(h*tand(centerEl + [-1 1]*spacingDeg/2));
        [~, positionsCm] = vstim.constantPhysicalAxis(0, ...
            g.monitorHeightCm, h, extentCm, spacingCm);
        anglesDeg = atand((g.monitorCenterYcm + positionsCm)/h);

    otherwise
        error('vstim:UnknownAxis', 'Unknown monitor axis "%s".', axisName)
end
end
