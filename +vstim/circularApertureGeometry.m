function aperture = circularApertureGeometry(diameterDeg, edgeBlurDeg, ...
        pixelsPerDeg)
%CIRCULARAPERTUREGEOMETRY Shared geometry for Gabor and inverse apertures.
% diameterDeg is the diameter of the 50% contrast/opacity contour.
% edgeBlurDeg is the complete radial transition width, centered on that
% contour. The visible support therefore extends edgeBlurDeg/2 beyond the
% requested radius.

aperture.nominalDiameterDeg = double(diameterDeg);
aperture.edgeBlurDeg = double(edgeBlurDeg);
aperture.supportDiameterDeg = double(diameterDeg + edgeBlurDeg);
aperture.supportDiameterPx = max(2, ...
    round(aperture.supportDiameterDeg * pixelsPerDeg));
aperture.outerRadiusPx = aperture.supportDiameterPx / 2;
aperture.edgeBlurPx = double(edgeBlurDeg * pixelsPerDeg);
aperture.halfContrastRadiusPx = aperture.outerRadiusPx - ...
    aperture.edgeBlurPx/2;
end
