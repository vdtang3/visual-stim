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
    estimate = vstim.estimateDuration(cfg,60);
    assert(height(sequence.trials) > 0)
    assert(sequence.estimatedDurationSec > 0)
    assert(abs(estimate.durationSec - ...
        (sequence.estimatedDurationSec + ...
        cfg.display.preRunBlankSec + cfg.display.postRunBlankSec)) < 1e-9)
    assert(sequence.ttlMode=="onset_frame_pulse")
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

flashed = vstim.defaultConfig("Flashed bars");
flashed.stimulus.interStimulusSec = 0;
sequence = vstim.generateSequence(flashed, 60);
assert(sequence.ttlMode=="onset_frame_pulse")
flashed.stimulus.interStimulusSec = 0.1;
sequence = vstim.generateSequence(flashed, 60);
assert(sequence.ttlMode=="onset_frame_pulse")

% Flashed bars use the same mapping rectangle as moving bars and retain
% their requested width even when their center lies on a region edge.
mappingRect = [100 200 500 600];
verticalRect = vstim.barRectanglePx( ...
    mappingRect,[300 400],[40 60],"azimuth");
assert(isequal(verticalRect,[280 200 320 600]))
horizontalRect = vstim.barRectanglePx( ...
    mappingRect,[300 250],[40 60],"elevation");
assert(isequal(horizontalRect,[100 220 500 280]))
edgeRect = vstim.barRectanglePx( ...
    mappingRect,[100 400],[40 60],"azimuth");
assert(isequal(edgeRect,[100 200 120 600]))
assert(all(verticalRect([1 3]) >= mappingRect(1)) && ...
    all(verticalRect([1 3]) <= mappingRect(3)))
assert(all(horizontalRect([2 4]) >= mappingRect(2)) && ...
    all(horizontalRect([2 4]) <= mappingRect(4)))

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

mockRun.status.completed = true;
mockRun.display.ifiSec = 0.01;
mockRun.sequence.trials = table([0.10;0.10],[0.05;0], ...
    'VariableNames',{'durationSec','interStimulusSec'});
mockRun.presentation.framesPresented = [10;10];
mockRun.presentation.missedFlipCount = [0;0];
mockRun.presentation.longFrameIntervalCount = [0;0];
mockRun.presentation.estimatedDroppedRefreshCount = [0;0];
mockRun.presentation.maximumMissSec = [0;0];
mockRun.presentation.maximumFrameIntervalSec = [0.01;0.01];
mockRun.presentation.actualInterStimulusSec = [0.05;NaN];
mockRun.presentation.flipOnsetSec = [1.00;1.15];
quality = vstim.assessPresentationQuality(mockRun);
assert(quality.pass && quality.verdict=="PASS")
mockRun.presentation.flipOnsetSec(2) = 1.25;
quality = vstim.assessPresentationQuality(mockRun);
assert(~quality.pass && quality.trialOnsetIntervalViolationCount==1)
mockRun.presentation.flipOnsetSec(2) = 1.15;
mockRun.presentation.estimatedDroppedRefreshCount(1) = 1;
quality = vstim.assessPresentationQuality(mockRun);
assert(~quality.pass && quality.verdict=="WARN")
mockRun.status.completed = false;
quality = vstim.assessPresentationQuality(mockRun);
assert(~quality.pass && quality.verdict=="INCOMPLETE")

waveSurferParent = string(tempname);
waveSurferDate = string(datetime('today','Format','yyyyMMdd'));
waveSurferDateFolder = fullfile(waveSurferParent,waveSurferDate);
mkdir(waveSurferDateFolder);
waveSurferTestCleanup = onCleanup( ...
    @() rmdir(char(waveSurferParent),'s'));
waveSurferTestFile = fullfile(waveSurferDateFolder,'test_sweep.h5');
fileIdentifier = fopen(waveSurferTestFile,'w');
assert(fileIdentifier>=0)
fclose(fileIdentifier);
session.autoDetectWaveSurferFile = true;
session.wavesurferParentDirectory = waveSurferParent;
session.wavesurferMaximumAgeMinutes = 5;
detection = vstim.detectLatestWaveSurferFile(session);
assert(detection.found)
assert(detection.parentDirectory==waveSurferParent)
assert(detection.dateFolderName==waveSurferDate)
assert(detection.folder==string(waveSurferDateFolder))
assert(detection.filename=="test_sweep.h5")
clear waveSurferTestCleanup

filenameCfg = vstim.defaultConfig("Fast Gabor tiling");
filenameCfg.session.filePrefix = "visual_stim";
filenameCfg.session.wavesurferSweep = "cell_001.h5";
filename = vstim.stimulusRunFilename(filenameCfg,"20260803_143015");
assert(filename== ...
    "cell_001_fast_gabor_tiling_visual_stim_20260803_143015.mat")
filenameCfg.session.wavesurferSweep = "";
filename = vstim.stimulusRunFilename(filenameCfg,"20260803_143015");
assert(filename== ...
    "fast_gabor_tiling_visual_stim_20260803_143015.mat")

% One GUI file retains independent parameters for multiple protocols and
% restores the protocol that was active when the file was saved.
movingCfg = vstim.defaultConfig("Moving bars");
movingCfg.stimulus.barWidthDeg = 12.5;
sparseCfg = vstim.defaultConfig("Sparse noise");
sparseCfg.stimulus.totalDurationSec = 47;
protocolConfigs = struct;
protocolConfigs.(vstim.protocolConfigKey(movingCfg.protocol)) = movingCfg;
protocolConfigs.(vstim.protocolConfigKey(sparseCfg.protocol)) = sparseCfg;
guiConfigFilename = vstim.saveGuiConfig(sparseCfg,protocolConfigs);
guiConfigCleanup = onCleanup(@() delete(guiConfigFilename));
[loadedCfg,loadedProtocolConfigs] = ...
    vstim.loadGuiConfig(guiConfigFilename);
assert(loadedCfg.protocol=="Sparse noise")
assert(loadedProtocolConfigs.MovingBars.stimulus.barWidthDeg==12.5)
assert(loadedProtocolConfigs.SparseNoise.stimulus.totalDurationSec==47)
clear guiConfigCleanup

fprintf('All generator tests passed.\n');
end
