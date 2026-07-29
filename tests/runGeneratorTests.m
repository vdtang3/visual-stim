function runGeneratorTests
%RUNGENERATORTESTS Validate all sequence generators without display hardware.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);

protocols = ["Moving bars", "Flashed bars", "Sparse noise", ...
    "Fast Gabor tiling", "Targeted Gabor grid", ...
    "Gabor + inverse stimuli"];
for protocol = protocols
    cfg = vstim.defaultConfig(protocol);
    vstim.validateConfig(cfg);
    sequence = vstim.generateSequence(cfg, 60);
    assert(height(sequence.trials) > 0)
    assert(sequence.estimatedDurationSec > 0)
    fprintf('%s: %d trials/patterns, %.3f s, TTL=%s\n', ...
        protocol, height(sequence.trials), sequence.estimatedDurationSec, ...
        sequence.ttlMode);

    if protocol == "Sparse noise"
        assert(all(sum(sequence.stimulusMatrix ~= 0, 1) == ...
            cfg.stimulus.activeTilesPerPattern))
        assert(all(sum(sequence.stimulusMatrix == 1, 1) == ...
            cfg.stimulus.whiteTilesPerPattern))
        assert(all(sum(sequence.stimulusMatrix == -1, 1) == ...
            cfg.stimulus.blackTilesPerPattern))
        fprintf('  white count range: %d-%d; black count range: %d-%d\n', ...
            min(sequence.whiteCounts), max(sequence.whiteCounts), ...
            min(sequence.blackCounts), max(sequence.blackCounts));
    end
end

aperture = vstim.circularApertureGeometry(20,10,12);
assert(aperture.supportDiameterPx==360);
assert(abs(aperture.halfContrastRadiusPx-120)<1e-12);
assert(abs(2*aperture.halfContrastRadiusPx/12-20)<1e-12);
combined = vstim.defaultConfig("Gabor + inverse stimuli");
assert(combined.stimulus.inverseDiameterDeg == ...
    combined.stimulus.diameterDeg);
gaborAperture = vstim.circularApertureGeometry( ...
    combined.stimulus.diameterDeg,combined.stimulus.edgeBlurDeg,12);
inverseAperture = vstim.circularCoreApertureGeometry( ...
    combined.stimulus.inverseDiameterDeg,combined.stimulus.edgeBlurDeg,12);
assert(inverseAperture.coreDiameterDeg==20);
assert(inverseAperture.supportDiameterDeg==40);
assert(abs(2*inverseAperture.solidCoreRadiusPx/12-20)<1e-12);
assert(inverseAperture.supportDiameterPx > ...
    gaborAperture.supportDiameterPx);
combined.stimulus.inverseDiameterDeg = 26;
inverseAperture = vstim.circularCoreApertureGeometry( ...
    combined.stimulus.inverseDiameterDeg,combined.stimulus.edgeBlurDeg,12);
assert(inverseAperture.supportDiameterPx > ...
    gaborAperture.supportDiameterPx);

result = vstim.emptyAnalysisResult("test");
assert(height(result.durationComparison) == 6)
fprintf('All generator tests passed.\n');
end
