function [azimuthLimitsDeg, elevationLimitsDeg] = mappingLimits(cfg)
%MAPPINGLIMITS Return the selected target region or the full display.

p = cfg.stimulus;
if isfield(p, 'mappingAzimuthLimitsDeg') && ...
        ~isempty(p.mappingAzimuthLimitsDeg)
    azimuthLimitsDeg = p.mappingAzimuthLimitsDeg;
else
    azimuthLimitsDeg = cfg.display.azimuthLimitsDeg;
end
if isfield(p, 'mappingElevationLimitsDeg') && ...
        ~isempty(p.mappingElevationLimitsDeg)
    elevationLimitsDeg = p.mappingElevationLimitsDeg;
else
    elevationLimitsDeg = cfg.display.elevationLimitsDeg;
end

azimuthLimitsDeg = double(azimuthLimitsDeg(:)');
elevationLimitsDeg = double(elevationLimitsDeg(:)');
end
