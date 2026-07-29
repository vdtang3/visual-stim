function aperture = circularCoreApertureGeometry(coreDiameterDeg, ...
        outwardEdgeBlurDeg, pixelsPerDeg)
%CIRCULARCOREAPERTUREGEOMETRY Aperture with a solid core and outward blur.
% coreDiameterDeg is the fully opaque/fully modulated diameter. The radial
% transition begins at that boundary and extends outward by
% outwardEdgeBlurDeg on every side.

aperture.coreDiameterDeg = double(coreDiameterDeg);
aperture.edgeBlurDeg = double(outwardEdgeBlurDeg);
aperture.supportDiameterDeg = double( ...
    coreDiameterDeg + 2*outwardEdgeBlurDeg);
aperture.supportDiameterPx = max(2, ...
    round(aperture.supportDiameterDeg*pixelsPerDeg));
aperture.outerRadiusPx = aperture.supportDiameterPx/2;
aperture.edgeBlurPx = double(outwardEdgeBlurDeg*pixelsPerDeg);
aperture.solidCoreRadiusPx = aperture.outerRadiusPx - ...
    aperture.edgeBlurPx;
aperture.halfOpacityRadiusPx = aperture.outerRadiusPx - ...
    aperture.edgeBlurPx/2;
end
