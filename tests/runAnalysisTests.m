function runAnalysisTests
%RUNANALYSISTESTS Exercise every quick-analysis estimator on synthetic spikes.

addpath(fileparts(fileparts(mfilename('fullpath'))));
rng(7);
testStartupTTLAlignment;
testFramePulseAlignment;
testRunFilePairing;
testFlashedBars;
testGaborGrid;
testFlatGaborRejected;
testSparseNoise;
testMovingBars;
testConsensus;
testRobustConsensus;
testRunSpecificOptions;
fprintf('All spike RF analysis tests passed.\n');
end

function testStartupTTLAlignment
nTrials = 6;
trials = table((1:nTrials)',repmat(0.1,nTrials,1), ...
    repmat(0.3,nTrials,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
runData = makeRun("Flashed bars",trials);
fs = 10000;
trueOnsets = round((2+(0:nTrials-1)'*0.4)*fs);
data = makeDataFromSpikes(trueOnsets,[],trials.durationSec,fs);
startupOnsets = [100;240;390];
for i = 1:numel(startupOnsets)
    data.di.screen(startupOnsets(i):startupOnsets(i)+20) = true;
end
alignment = vstim.alignRecordedStimuli(runData,data);
assert(isequal(alignment.trials.onsetSample,trueOnsets));
assert(alignment.ignoredLeadingEdgeCount==numel(startupOnsets));
assert(alignment.ignoredTrailingEdgeCount==0);
assert(alignment.completeMatch);
assert(~alignment.exactRecordedCountMatch);
end

function testRunFilePairing
testFolder = string(tempname);
mkdir(testFolder);
testCleanup = onCleanup(@() rmdir(char(testFolder),'s'));
h5File = fullfile(testFolder,'cell_001.h5');
fileIdentifier = fopen(h5File,'w');
assert(fileIdentifier>=0)
fclose(fileIdentifier);
runData.params = vstim.defaultConfig("Fast Gabor tiling");
runData.params.session.wavesurferFile = string(h5File);
runData.sequence = struct();
runData.presentation = struct();
runData.sync = struct();
runData.status = struct();
runDataFile = fullfile(testFolder, ...
    'cell_001_fast_gabor_tiling_visual_stim_20260803_143015.mat');
save(runDataFile,'runData','-v7.3');
loadedRun = vstim.loadRun(runDataFile);
assert(vstim.detectedH5ForRun(loadedRun)==string(h5File))
assert(isfile(vstim.detectedH5ForRun(loadedRun)))
clear testCleanup
end

function testFramePulseAlignment
nTrials = 6;
trials = table((1:nTrials)',repmat(0.1,nTrials,1),zeros(nTrials,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
runData = makeRun("Flashed bars",trials);
runData.sequence.ttlMode = "onset_frame_pulse";
runData.display.ifiSec = 1/60;
runData.sync.expectedOnsetPulseSec = 1/60;
fs = 12000;
onsets = round((1+(0:nTrials-1)'*0.1)*fs);
nSamples = onsets(end)+round(0.2*fs);
data.di.screen = false(nSamples,1);
data.meta.fs = fs;
data.spikes.spks = [];
pulseSamples = round(fs/60);
for i = 1:nTrials
    data.di.screen(onsets(i):onsets(i)+pulseSamples-1) = true;
end
alignment = vstim.alignRecordedStimuli(runData,data);
assert(isequal(alignment.trials.onsetSample,onsets))
assert(alignment.ttlMode=="onset_frame_pulse")
assert(alignment.pulseWidthViolationCount==0)
assert(abs(alignment.medianPulseWidthSec-1/60)<1/fs)

% An abnormally long first-frame TTL is treated as a synchronization or
% presentation-hang warning.
data.di.screen(onsets(3):onsets(3)+3*pulseSamples-1) = true;
alignment = vstim.alignRecordedStimuli(runData,data);
assert(alignment.pulseWidthViolationCount==1)
assert(~isempty(alignment.warnings))
end

function testFlashedBars
positions = (-20:10:20)';
[axisName,position,polarity,repetition] = ndgrid( ...
    ["azimuth","elevation"],positions,[-1 1],1:6);
trials = table(axisName(:),position(:),polarity(:),repetition(:), ...
    'VariableNames',{'axis','positionDeg','polarity','repetition'});
trials.durationSec = repmat(0.1,height(trials),1);
trials.interStimulusSec = repmat(0.3,height(trials),1);
runData = makeRun("Flashed bars",trials);
onsets = round((1:height(trials))*0.4*10000)';
counts = zeros(height(trials),1);
for i = 1:height(trials)
    center = 5*(trials.axis(i)=="azimuth")-5*(trials.axis(i)=="elevation");
    counts(i) = stochasticCount(0.18*(2+45*exp( ...
        -0.5*((trials.positionDeg(i)-center)/8)^2)));
end
data = makeData(onsets,counts,[0.03 0.17],trials.durationSec,10000);
result = vstim.analyzeSpikeReceptiveField(runData,data, ...
    struct('bootstrapRepetitions',30));
assert(abs(result.rfCenterAzimuthDeg-5)<7);
assert(abs(result.rfCenterElevationDeg+5)<7);
assert(size(result.bootstrapCentersDeg,1)>=10);
end

function testGaborGrid
[az,el] = ndgrid(-20:10:20,-15:10:15);
az = az(:); el = el(:);
[positionIndex,orientationDeg,repetition] = ndgrid( ...
    (1:numel(az))',[0 45 90 135],1:5);
trials = table(positionIndex(:),az(positionIndex(:)), ...
    el(positionIndex(:)),orientationDeg(:),repetition(:), ...
    'VariableNames',{'positionIndex','azimuthDeg','elevationDeg', ...
    'orientationDeg','repetition'});
trials.durationSec = repmat(0.3,height(trials),1);
trials.interStimulusSec = repmat(0.2,height(trials),1);
runData = makeRun("Fast Gabor tiling",trials);
runData.sequence.grid = table((1:numel(az))',az,el, ...
    'VariableNames',{'locationIndex','azimuthDeg','elevationDeg'});
onsets = round((1:height(trials))*0.5*10000)';
rate = 2+55*exp(-0.5*( ...
    ((trials.azimuthDeg-5)/9).^2+((trials.elevationDeg+5)/8).^2));
counts = arrayfun(@(r) stochasticCount(0.25*r),rate);
data = makeData(onsets,counts,[0.03 0.28],trials.durationSec,10000);
result = vstim.analyzeSpikeReceptiveField(runData,data, ...
    struct('bootstrapRepetitions',30));
assert(abs(result.rfCenterAzimuthDeg-5)<7);
assert(abs(result.rfCenterElevationDeg+5)<7);
assert(isnan(result.preferredOrientationDeg));
end

function testFlatGaborRejected
[az,el] = ndgrid(-10:10:10,-10:10:10);
az = az(:); el = el(:);
[positionIndex,orientationDeg,repetition] = ndgrid( ...
    (1:numel(az))',[0 90],1:3);
trials = table(positionIndex(:),az(positionIndex(:)), ...
    el(positionIndex(:)),orientationDeg(:),repetition(:), ...
    'VariableNames',{'positionIndex','azimuthDeg','elevationDeg', ...
    'orientationDeg','repetition'});
trials.durationSec = repmat(0.1,height(trials),1);
trials.interStimulusSec = repmat(0.1,height(trials),1);
runData = makeRun("Fast Gabor tiling",trials);
onsets = round((1:height(trials))*0.2*10000)';
data = makeDataFromSpikes(onsets,[],trials.durationSec,10000);
result = vstim.analyzeSpikeReceptiveField(runData,data, ...
    struct('bootstrapRepetitions',20,'responseWindowMs',[0 2]));
assert(~result.usableCenter);
assert(~result.fitSuccessful);
assert(isnan(result.fitQuality));
assert(isnan(result.uncertaintyRadiusDeg));
end

function testSparseNoise
[az,el] = ndgrid(-20:10:20,-15:10:15);
az = az(:); el = el(:);
nLocations = numel(az);
nPatterns = 700;
patterns = zeros(nLocations,nPatterns,'int8');
for i = 1:nPatterns
    chosen = randperm(nLocations,6);
    patterns(chosen(1:3),i) = 1;
    patterns(chosen(4:6),i) = -1;
end
trials = table((1:nPatterns)',repmat(0.05,nPatterns,1), ...
    repmat(0.05,nPatterns,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
runData = makeRun("Sparse noise",trials);
runData.sequence.stimulusMatrix = patterns;
runData.sequence.grid = table((1:nLocations)',az,el, ...
    'VariableNames',{'locationIndex','azimuthDeg','elevationDeg'});
onsets = round((1:nPatterns)*0.1*10000)';
rf = exp(-0.5*(((az-5)/9).^2+((el+5)/8).^2));
rate = 2+100*(double(patterns==1)'*rf)+ ...
    70*(double(patterns==-1)'*rf);
counts = arrayfun(@(r) stochasticCount(0.02*r),rate);
data = makeData(onsets,counts,[0.04 0.06],trials.durationSec,10000);
overrides = struct('bootstrapRepetitions',20,'testedLagsMs', ...
    20:10:70,'spikeBinMs',20,'crossValidationFolds',5);
result = vstim.analyzeSpikeReceptiveField(runData,data,overrides);
assert(abs(result.rfCenterAzimuthDeg-5)<10);
assert(abs(result.rfCenterElevationDeg+5)<10);
assert(isfinite(result.fitQuality));
end

function testMovingBars
directions = ["left_to_right","right_to_left", ...
    "bottom_to_top","top_to_bottom"];
[direction,polarity,repetition] = ndgrid(directions,[-1 1],1:6);
trials = table(direction(:),polarity(:),repetition(:), ...
    'VariableNames',{'direction','polarity','repetition'});
trials.axis = strings(height(trials),1);
trials.durationSec = repmat(1.2,height(trials),1);
trials.interStimulusSec = repmat(0.3,height(trials),1);
trials.frameCentersDeg = cell(height(trials),1);
for i = 1:height(trials)
    forward = any(trials.direction(i)== ...
        ["left_to_right","bottom_to_top"]);
    if any(trials.direction(i)==["left_to_right","right_to_left"])
        trials.axis(i) = "azimuth";
    else
        trials.axis(i) = "elevation";
    end
    if forward
        trials.frameCentersDeg{i} = linspace(-30,30,121);
    else
        trials.frameCentersDeg{i} = linspace(30,-30,121);
    end
end
runData = makeRun("Moving bars",trials);
onsets = round((1:height(trials))*1.5*10000)';
spikesByTrial = cell(height(trials),1);
for i = 1:height(trials)
    if trials.axis(i)=="azimuth", center=5; else, center=-5; end
    trajectory = trials.frameCentersDeg{i};
    [~,frame] = min(abs(trajectory-center));
    visualTime = (frame-1)/(numel(trajectory)-1)*trials.durationSec(i);
    spikeTime = visualTime+0.08+(0:3)*0.003;
    spikesByTrial{i} = onsets(i)+round(spikeTime*10000);
end
data = makeDataFromSpikes(onsets,vertcat(spikesByTrial{:}), ...
    trials.durationSec,10000);
result = vstim.analyzeSpikeReceptiveField(runData,data, ...
    struct('bootstrapRepetitions',20,'spikeLatencyRangeMs',[20 140], ...
    'spikeBinMs',10,'positionBinDeg',5));
assert(abs(result.rfCenterAzimuthDeg-5)<9);
assert(abs(result.rfCenterElevationDeg+5)<9);
end

function testConsensus
results = cell(3,1);
results{1} = mockResult("Moving bars",[0 0],eye(2));
results{2} = mockResult("Moving bars",[2 0],eye(2));
results{3} = mockResult("Sparse noise",[10 0],eye(2));
consensus = vstim.consensusReceptiveField(results);
assert(consensus.runCount==3);
assert(consensus.protocolFamilyCount==2);
assert(abs(consensus.rfCenterAzimuthDeg-4)<1e-9);
assert(consensus.inflationFactor>1);

gaborResults = {
    mockResult("Fast Gabor tiling",[4 -2],eye(2))
    mockResult("Targeted Gabor grid",[6 -2],eye(2))};
gaborConsensus = vstim.consensusReceptiveField(gaborResults);
assert(gaborConsensus.protocolFamilyCount==1);
assert(abs(gaborConsensus.rfCenterAzimuthDeg-5)<1e-9);
end

function testRobustConsensus
results = {
    mockResult("Flashed bars",[5.0 -5.0],0.25*eye(2))
    mockResult("Sparse noise",[5.1 -4.9],0.25*eye(2))
    mockResult("Fast Gabor tiling",[4.9 -5.1],0.25*eye(2))
    mockResult("Moving bars",[7.4 -4.3],0.01*eye(2))};
consensus = vstim.consensusReceptiveField(results);
assert(consensus.rfCenterAzimuthDeg<5.5);
moving = consensus.protocolFamilies.protocolFamily=="Moving bars";
assert(consensus.protocolFamilies.consensusRobustWeight(moving)<0.5);
end

function testRunSpecificOptions
trials = table((1:3)',repmat(0.1,3,1),repmat(0.05,3,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
trials.axis = repmat("azimuth",3,1);
trials.positionDeg = [-10;0;10];
trials.polarity = ones(3,1);
runData = makeRun("Flashed bars",trials);
[options,timing] = vstim.analysisOptionsForRun(runData);
assert(max(abs(options.responseWindowMs-[20 149]))<1e-9);
assert(max(abs(options.baselineWindowMs-[-50 0]))<1e-9);
assert(abs(timing.minimumOnsetIntervalMs-150)<1e-9);
end

function result = mockResult(protocol,center,covariance)
result = vstim.emptyAnalysisResult(protocol);
result.usableCenter = true;
result.rfCenterAzimuthDeg = center(1);
result.rfCenterElevationDeg = center(2);
result.centerCovarianceDeg2 = covariance;
end

function runData = makeRun(protocol,trials)
cfg = vstim.defaultConfig(protocol);
runData.params = cfg;
runData.sequence.trials = trials;
runData.sequence.ttlMode = "epoch";
runData.presentation = struct();
runData.sync = struct();
runData.status = struct();
end

function data = makeData(onsets,counts,responseWindow,durations,fs)
spikes = [];
for i = 1:numel(onsets)
    if counts(i)>0
        offsets = linspace(responseWindow(1),responseWindow(2),counts(i)+2);
        spikes = [spikes;onsets(i)+round(offsets(2:end-1)'*fs)]; %#ok<AGROW>
    end
end
data = makeDataFromSpikes(onsets,spikes,durations,fs);
end

function data = makeDataFromSpikes(onsets,spikes,durations,fs)
nSamples = ceil(max(onsets+round((durations+0.3)*fs)));
screen = false(nSamples,1);
for i = 1:numel(onsets)
    screen(onsets(i):min(nSamples,onsets(i)+round(durations(i)*fs))) = true;
end
data.di.screen = screen;
data.meta.fs = fs;
data.spikes.spks = sort(double(spikes(:)));
end

function n = stochasticCount(expected)
n = floor(expected)+(rand < expected-floor(expected));
end
