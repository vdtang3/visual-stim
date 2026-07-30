function sequence = generateSparseNoise(cfg, frameRate)
%GENERATESPARSENOISE Generate balanced locally sparse multi-tile patterns.
% The generator greedily minimizes location/polarity count imbalance while
% enforcing spatial and temporal exclusions.

p = cfg.stimulus;
if p.whiteTilesPerPattern + p.blackTilesPerPattern ~= p.activeTilesPerPattern
    error('vstim:InvalidSparseCounts', ...
        'White plus black tiles must equal active tiles per pattern.')
end

if p.lockGridSpacingToTileSize
    effectiveSpacingDeg = p.tileSizeDeg;
else
    effectiveSpacingDeg = p.gridSpacingDeg;
end

if p.autoGridFromDisplay
    [azLimits, elLimits] = vstim.mappingLimits(cfg);
    if string(p.gridCoordinateMode) == "constant_degrees"
        azAxis = vstim.constantDegreeAxis(cfg.display.azimuthLimitsDeg, ...
            p.tileSizeDeg(1), effectiveSpacingDeg(1));
        elAxis = vstim.constantDegreeAxis(cfg.display.elevationLimitsDeg, ...
            p.tileSizeDeg(2), effectiveSpacingDeg(2));
        h = cfg.display.monitorHorizontalDistanceCm;
        azPositionsCm = h*tand( ...
            azAxis-cfg.display.monitorCenterAzimuthDeg);
        elPositionsCm = h*tand(elAxis)-cfg.display.monitorCenterYcm;
    else
        [~, ~, projectedWidthCm, projectedSpacingXCm] = vstim.monitorAxis( ...
            cfg, "azimuth", p.tileSizeDeg(1), effectiveSpacingDeg(1));
        [~, ~, projectedHeightCm, projectedSpacingYCm] = vstim.monitorAxis( ...
            cfg, "elevation", p.tileSizeDeg(2), effectiveSpacingDeg(2));

        if p.forceSquareTiles
            pixelsPerCm = cfg.display.resolutionPx ./ ...
                [cfg.display.monitorWidthCm cfg.display.monitorHeightCm];
            tileSidePx = mean([projectedWidthCm*pixelsPerCm(1), ...
                projectedHeightCm*pixelsPerCm(2)]);
            tileWidthCm = tileSidePx/pixelsPerCm(1);
            tileHeightCm = tileSidePx/pixelsPerCm(2);
            if p.lockGridSpacingToTileSize
                spacingWidthCm = tileWidthCm;
                spacingHeightCm = tileHeightCm;
            else
                spacingWidthCm = projectedSpacingXCm;
                spacingHeightCm = projectedSpacingYCm;
            end
        else
            tileWidthCm = projectedWidthCm;
            tileHeightCm = projectedHeightCm;
            spacingWidthCm = projectedSpacingXCm;
            spacingHeightCm = projectedSpacingYCm;
        end

    end
    azKeep = azAxis >= azLimits(1) & azAxis <= azLimits(2);
    elKeep = elAxis >= elLimits(1) & elAxis <= elLimits(2);
    azAxis = azAxis(azKeep);
    elAxis = elAxis(elKeep);
    azPositionsCm = azPositionsCm(azKeep);
    elPositionsCm = elPositionsCm(elKeep);
    if isempty(azAxis) || isempty(elAxis)
        error('vstim:MappingRegionTooSmall', ...
            'The selected region is too small for one sparse-noise tile.')
    end
    [azimuthDeg, elevationDeg] = vstim.gridFromAxes(azAxis, elAxis);
    effectiveGridSize = [numel(azAxis), numel(elAxis)];
else
    [azimuthDeg, elevationDeg] = vstim.gridCoordinates(p.gridSize, ...
        effectiveSpacingDeg);
    azimuthDeg = azimuthDeg + cfg.display.monitorCenterAzimuthDeg;
    elevationDeg = elevationDeg + cfg.display.monitorCenterElevationDeg;
    effectiveGridSize = p.gridSize;
    azAxis = unique(azimuthDeg, 'stable');
    elAxis = unique(elevationDeg, 'stable');
end
nLocations = numel(azimuthDeg);
nPatterns = max(1, floor(p.totalDurationSec / ...
    (p.patternDurationSec + p.interPatternSec)));
patterns = zeros(nLocations, nPatterns, 'int8');

[gridAz, gridEl] = ndgrid(1:effectiveGridSize(1), 1:effectiveGridSize(2));
gridXY = [gridAz(:), gridEl(:)];
lastUsed = -inf(nLocations, 1);
lastPatternLocations = [];
whiteCounts = zeros(nLocations, 1);
blackCounts = zeros(nLocations, 1);

for k = 1:nPatterns
    baseAllowed = (k-lastUsed) > p.minimumReusePatterns;
    if p.avoidAdjacentNextPattern && ~isempty(lastPatternLocations)
        distanceToPrevious = inf(nLocations, 1);
        for c = lastPatternLocations
            distanceToPrevious = min(distanceToPrevious, ...
                max(abs(gridXY-gridXY(c,:)), [], 2));
        end
        baseAllowed = baseAllowed & distanceToPrevious > 1;
    end

    chosen = chooseSeparatedTiles(baseAllowed, gridXY, ...
        whiteCounts+blackCounts, p.activeTilesPerPattern, ...
        p.minimumGridDistance, min(p.maximumGenerationAttempts, 30));
    if isempty(chosen) && p.avoidAdjacentNextPattern
        % The adjacency rule concerns consecutive patterns and is the first
        % constraint relaxed when it conflicts with the simultaneous-tile
        % separation and reuse rules.
        baseAllowed = (k-lastUsed) > p.minimumReusePatterns;
        chosen = chooseSeparatedTiles(baseAllowed, gridXY, ...
            whiteCounts+blackCounts, p.activeTilesPerPattern, ...
            p.minimumGridDistance, min(p.maximumGenerationAttempts, 60));
    end
    if isempty(chosen)
        error('vstim:SparseConstraintsImpossible', ...
            ['Sparse-noise constraints cannot place %d tiles on a %dx%d ' ...
             'grid. Reduce active tiles or exclusion distance.'], ...
            p.activeTilesPerPattern, effectiveGridSize(1), effectiveGridSize(2))
    end

    % Assign polarity to minimize per-location polarity imbalance.
    imbalance = whiteCounts(chosen) - blackCounts(chosen);
    [~, order] = sort(imbalance, 'ascend');
    white = chosen(order(1:p.whiteTilesPerPattern));
    black = setdiff(chosen, white, 'stable');
    patterns(white, k) = 1;
    patterns(black, k) = -1;
    whiteCounts(white) = whiteCounts(white) + 1;
    blackCounts(black) = blackCounts(black) + 1;
    lastUsed(chosen) = k;
    lastPatternLocations = chosen;
end

trials = table((1:nPatterns)', ...
    repmat(round(p.patternDurationSec*frameRate)/frameRate, nPatterns, 1), ...
    repmat(p.interPatternSec, nPatterns, 1), ...
    'VariableNames', {'trialIndex', 'durationSec', 'interStimulusSec'});

sequence.trials = trials;
sequence.stimulusMatrix = patterns;
sequence.grid = table((1:nLocations)', azimuthDeg, elevationDeg, gridXY(:,1), ...
    gridXY(:,2), 'VariableNames', {'locationIndex', 'azimuthDeg', ...
    'elevationDeg', 'gridAzimuthIndex', 'gridElevationIndex'});
sequence.whiteCounts = whiteCounts;
sequence.blackCounts = blackCounts;
sequence.effectiveGridSize = effectiveGridSize;
sequence.effectiveGridSpacingDeg = effectiveSpacingDeg;
sequence.gridCoordinateMode = string(p.gridCoordinateMode);
[sequence.mappingAzimuthLimitsDeg, ...
    sequence.mappingElevationLimitsDeg] = vstim.mappingLimits(cfg);
if p.autoGridFromDisplay
    sequence.azimuthPositionsCm = azPositionsCm;
    sequence.elevationPositionsCm = elPositionsCm;
    if string(p.gridCoordinateMode) == "constant_pixels"
        sequence.tileSizeCm = [tileWidthCm tileHeightCm];
        sequence.gridSpacingCm = [spacingWidthCm spacingHeightCm];
        if p.forceSquareTiles
            sequence.tileSizePx = [tileSidePx tileSidePx];
        end
    end
end
sequence.azimuthAxisDeg = azAxis;
sequence.elevationAxisDeg = elAxis;
sequence.estimatedDurationSec = sum(trials.durationSec + trials.interStimulusSec);
sequence.ttlMode = "onset_frame_pulse";
sequence.ttlModeReason = "one_display_frame_pulse_for_every_trial";

function chosen = chooseSeparatedTiles(baseAllowed, gridXY, counts, ...
        numberToChoose, minimumDistance, maximumAttempts)
% Random-restart greedy selection avoids failures caused by an unlucky
% first tile while still favoring underrepresented locations.
chosen = [];
eligible = find(baseAllowed);
bestObjective = [Inf Inf];
for attempt = 1:maximumAttempts
    current = [];
    available = eligible;
    while numel(current) < numberToChoose && ~isempty(available)
        % Favor underused locations while allowing random restarts to move
        % past a locally attractive tile that prevents a complete pattern.
        score = counts(available) + 2*rand(size(available));
        [~, best] = min(score);
        pick = available(best);
        current(end+1) = pick; %#ok<AGROW>
        distances = sqrt(sum((gridXY(available,:)-gridXY(pick,:)).^2, 2));
        available = available(distances >= minimumDistance);
    end
    if numel(current) == numberToChoose
        objective = [max(counts(current)), sum(counts(current))];
        if objective(1) < bestObjective(1) || ...
                (objective(1) == bestObjective(1) && objective(2) < bestObjective(2))
            chosen = current;
            bestObjective = objective;
        end
    end
end
end
end
