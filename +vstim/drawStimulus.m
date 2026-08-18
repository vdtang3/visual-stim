function drawInfo = drawStimulus(win, geometry, cfg, sequence, trialIndex, frameIndex, elapsedSec)
%DRAWSTIMULUS Draw one frame of any supported protocol.

p = cfg.stimulus;
tr = sequence.trials(trialIndex, :);
drawInfo = struct();
[azLimits, elLimits] = vstim.mappingLimits(cfg);
mappingRectPx = [geometry.degToPxX(azLimits(1)), ...
    geometry.degToPxY(elLimits(2)), geometry.degToPxX(azLimits(2)), ...
    geometry.degToPxY(elLimits(1))];

switch string(cfg.protocol)
    case "Moving bars"
        centers = tr.frameCentersDeg{1};
        center = centers(min(frameIndex, numel(centers)));
        color = vstim.polarityColor(tr.polarity, cfg);
        if tr.axis == "azimuth"
            centerPx = [geometry.degToPxX(center), mean(mappingRectPx([2 4]))];
            barWidthPx = geometry.sizeDegToPx([p.barWidthDeg, p.barWidthDeg]);
            sizePx = [barWidthPx(1), RectHeight(mappingRectPx)];
        else
            centerPx = [mean(mappingRectPx([1 3])), geometry.degToPxY(center)];
            barWidthPx = geometry.sizeDegToPx([p.barWidthDeg, p.barWidthDeg]);
            sizePx = [RectWidth(mappingRectPx), barWidthPx(2)];
        end
        rect = CenterRectOnPointd([0 0 sizePx], centerPx(1), centerPx(2));
        rect = [max(rect(1), mappingRectPx(1)), ...
            max(rect(2), mappingRectPx(2)), ...
            min(rect(3), mappingRectPx(3)), ...
            min(rect(4), mappingRectPx(4))];
        % A sweep begins and ends with the bar fully outside the target.
        % Clipping those frames produces an empty/inverted rectangle, which
        % must not be passed to Psychtoolbox.
        if rect(3) > rect(1) && rect(4) > rect(2)
            Screen('FillRect', win, color, rect);
        end
        drawInfo.centerDeg = center;

    case "Flashed bars"
        color = vstim.polarityColor(tr.polarity, cfg);
        barWidthPx = geometry.sizeDegToPx( ...
            [p.barWidthDeg, p.barWidthDeg]);
        if tr.axis == "azimuth"
            centerPx = [geometry.degToPxX(tr.positionDeg), ...
                mean(mappingRectPx([2 4]))];
        else
            centerPx = [mean(mappingRectPx([1 3])), ...
                geometry.degToPxY(tr.positionDeg)];
        end
        rect = vstim.barRectanglePx( ...
            mappingRectPx,centerPx,barWidthPx,tr.axis);
        if rect(3) > rect(1) && rect(4) > rect(2)
            Screen('FillRect', win, color, rect);
        end
        drawInfo.rectPx = rect;

    case "Sparse noise"
        pattern = sequence.stimulusMatrix(:, trialIndex);
        active = find(pattern ~= 0);
        tilePx = geometry.sizeDegToPx(p.tileSizeDeg);
        if p.forceSquareTiles
            tilePx(:) = mean(tilePx);
        end
        rects = zeros(4, numel(active));
        colors = zeros(3, numel(active));
        for i = 1:numel(active)
            idx = active(i);
            azimuthDeg = sequence.grid.azimuthDeg(idx);
            elevationDeg = sequence.grid.elevationDeg(idx);
            centerPx = [geometry.degToPxX(azimuthDeg), ...
                geometry.degToPxY(elevationDeg)];
            % With the default linear mapping, tile dimensions are constant
            % everywhere on screen. forceSquareTiles uses one common pixel
            % side length and does not apply any position-dependent warp.
            rect = CenterRectOnPointd([0 0 tilePx], ...
                centerPx(1), centerPx(2));
            rects(:,i) = rect';
            color = vstim.polarityColor(pattern(idx), cfg);
            colors(:,i) = color;
        end
        Screen('FillRect', win, colors, rects);

    case {"Fast Gabor tiling", "Targeted Gabor grid"}
        % Draw a sine grating through a circular aperture. edgeBlurDeg is
        % the radial distance over which contrast falls smoothly to zero;
        % it is not the sigma of a Gaussian envelope.
        angle = tr.orientationDeg;
        if p.orientationDefinition == "spatial_frequency_vector"
            angle = angle + 90;
        end
        centerPx = [geometry.degToPxX(tr.azimuthDeg), ...
            geometry.degToPxY(tr.elevationDeg)];
        pxPerDeg = geometry.pixelsPerDegAtCenter;
        tex = geometry.gaborTexture;
        supportPx = geometry.aperture.supportDiameterPx;
        textureRect = CenterRectOnPointd([0 0 supportPx supportPx], ...
            centerPx(1), centerPx(2));
        frequencyCyclesPerPx = p.spatialFrequencyCyclesPerDeg / pxPerDeg;
        switch string(p.temporalModulation)
            case "drifting"
                phaseDeg = p.spatialPhaseDeg + ...
                    360*p.temporalFrequencyHz*elapsedSec;
                contrast = p.contrast;
            case "counterphasing"
                phaseDeg = p.spatialPhaseDeg;
                contrast = p.contrast * ...
                    cos(2*pi*p.temporalFrequencyHz*elapsedSec);
            otherwise
                error('vstim:UnknownTemporalModulation', ...
                    'Unknown Gabor temporal modulation "%s".', ...
                    p.temporalModulation)
        end
        properties = [phaseDeg, frequencyCyclesPerPx, contrast, 0];
        Screen('DrawTexture', win, tex, [], textureRect, angle, [], [], ...
            [1 1 1 1], [], 0, properties);

    case "Gabor + inverse stimuli"
        angle = tr.orientationDeg;
        if p.orientationDefinition == "spatial_frequency_vector"
            angle = angle + 90;
        end
        centerPx = [geometry.degToPxX(tr.azimuthDeg), ...
            geometry.degToPxY(tr.elevationDeg)];
        pxPerDeg = geometry.pixelsPerDegAtCenter;
        supportPx = geometry.aperture.supportDiameterPx;
        patchRect = CenterRectOnPointd([0 0 supportPx supportPx], ...
            centerPx(1), centerPx(2));
        switch string(p.temporalModulation)
            case "drifting"
                phaseDeg = p.spatialPhaseDeg + ...
                    360*p.temporalFrequencyHz*elapsedSec;
                contrast = p.contrast;
            case "counterphasing"
                phaseDeg = p.spatialPhaseDeg;
                contrast = p.contrast * ...
                    cos(2*pi*p.temporalFrequencyHz*elapsedSec);
        end
        properties = [phaseDeg, ...
            p.spatialFrequencyCyclesPerDeg/pxPerDeg, contrast, 0];
        switch tr.stimulusType
            case "classical"
                Screen('DrawTexture', win, geometry.gaborTexture, [], ...
                    patchRect, angle, [], [], [1 1 1 1], [], 0, ...
                    properties);
            case "inverse"
                Screen('DrawTexture', win, ...
                    geometry.fullFieldGratingTexture, [], ...
                    geometry.fullFieldGratingRect, angle, [], [], ...
                    [1 1 1 0], [], geometry.fullFieldRotationMode, ...
                    properties);
                % The zero-contrast draw uses the exact same shader,
                % but inverseDiameterDeg defines the fully gray core.
                % edgeBlurDeg begins at that core boundary and fades
                % radially outward. A separate texture permits this
                % independent size convention.
                inverseSupportPx = ...
                    geometry.inverseAperture.supportDiameterPx;
                inverseRect = CenterRectOnPointd( ...
                    [0 0 inverseSupportPx inverseSupportPx], ...
                    centerPx(1),centerPx(2));
                Screen('DrawTexture', win, ...
                    geometry.inverseTexture, [], inverseRect, angle, [], [], ...
                    [1 1 1 1], [], 0, [0 0 0 0]);
            case "full_field"
                Screen('DrawTexture', win, ...
                    geometry.fullFieldGratingTexture, [], ...
                    geometry.fullFieldGratingRect, angle, [], [], ...
                    [1 1 1 0], [], geometry.fullFieldRotationMode, ...
                    properties);
        end
end
end
