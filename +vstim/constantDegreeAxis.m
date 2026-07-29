function anglesDeg = constantDegreeAxis(limitsDeg, extentDeg, spacingDeg)
%CONSTANTDEGREEAXIS Uniform angular centers that cover a selected interval.

centerDeg = mean(limitsDeg);
nBelow = max(0, ceil((centerDeg-extentDeg/2-limitsDeg(1))/spacingDeg));
nAbove = max(0, ceil((limitsDeg(2)-centerDeg-extentDeg/2)/spacingDeg));
anglesDeg = centerDeg + (-nBelow:nAbove)*spacingDeg;
end
