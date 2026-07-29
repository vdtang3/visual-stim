function cfg = clampMappingRegion(cfg)
%CLAMPMAPPINGREGION Keep an explicit target rectangle inside the display.

p = cfg.stimulus;
if isfield(p, 'mappingAzimuthLimitsDeg') && ...
        ~isempty(p.mappingAzimuthLimitsDeg)
    limits = sort(double(p.mappingAzimuthLimitsDeg(:)'));
    limits = [max(limits(1), cfg.display.azimuthLimitsDeg(1)), ...
        min(limits(2), cfg.display.azimuthLimitsDeg(2))];
    if diff(limits) <= 0
        limits = cfg.display.azimuthLimitsDeg;
    end
    cfg.stimulus.mappingAzimuthLimitsDeg = limits;
end

if isfield(p, 'mappingElevationLimitsDeg') && ...
        ~isempty(p.mappingElevationLimitsDeg)
    limits = sort(double(p.mappingElevationLimitsDeg(:)'));
    limits = [max(limits(1), cfg.display.elevationLimitsDeg(1)), ...
        min(limits(2), cfg.display.elevationLimitsDeg(2))];
    if diff(limits) <= 0
        limits = cfg.display.elevationLimitsDeg;
    end
    cfg.stimulus.mappingElevationLimitsDeg = limits;
end
end
