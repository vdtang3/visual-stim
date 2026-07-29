function [azimuthDeg, elevationDeg] = gridCoordinates(gridSize, spacingDeg)
%GRIDCOORDINATES Return centered visual-field coordinates for a grid.

if isscalar(spacingDeg)
    spacingDeg = [spacingDeg spacingDeg];
end

az = ((1:gridSize(1)) - (gridSize(1)+1)/2) * spacingDeg(1);
el = ((1:gridSize(2)) - (gridSize(2)+1)/2) * spacingDeg(2);
[AZ, EL] = ndgrid(az, el);
azimuthDeg = AZ(:);
elevationDeg = EL(:);
end
