function [azimuthDeg, elevationDeg] = gridFromAxes(azimuthAxisDeg, elevationAxisDeg)
%GRIDFROMAXES Expand azimuth and elevation axes into location vectors.
[AZ, EL] = ndgrid(azimuthAxisDeg, elevationAxisDeg);
azimuthDeg = AZ(:);
elevationDeg = EL(:);
end
