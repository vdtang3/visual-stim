function rect = barRectanglePx(mappingRectPx,centerPx,barWidthPx,axisName)
%BARRECTANGLEPX Return a bar rectangle clipped to the mapping rectangle.

mappingRectPx = double(mappingRectPx(:)');
centerPx = double(centerPx(:)');
barWidthPx = double(barWidthPx(:)');
if string(axisName) == "azimuth"
    rect = [centerPx(1)-barWidthPx(1)/2, mappingRectPx(2), ...
        centerPx(1)+barWidthPx(1)/2, mappingRectPx(4)];
else
    rect = [mappingRectPx(1), centerPx(2)-barWidthPx(2)/2, ...
        mappingRectPx(3), centerPx(2)+barWidthPx(2)/2];
end
rect = [max(rect(1),mappingRectPx(1)), ...
    max(rect(2),mappingRectPx(2)), min(rect(3),mappingRectPx(3)), ...
    min(rect(4),mappingRectPx(4))];
end
