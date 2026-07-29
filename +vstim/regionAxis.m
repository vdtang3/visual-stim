function [anglesDeg, positionsCm] = regionAxis( ...
        cfg, axisName, limitsDeg, extentDeg, spacingDeg)
%REGIONAXIS Uniform nominal-degree centers covering a selected interval.

g = cfg.display;
h = g.monitorHorizontalDistanceCm;
anglesDeg = vstim.constantDegreeAxis(limitsDeg, extentDeg, spacingDeg);
switch string(axisName)
    case "azimuth"
        positionsCm = h*tand(anglesDeg-g.monitorCenterAzimuthDeg);
    case "elevation"
        positionsCm = h*tand(anglesDeg)-g.monitorCenterYcm;
    otherwise
        error('vstim:UnknownAxis', 'Unknown monitor axis "%s".', axisName)
end
end
