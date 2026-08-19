function runInspectionTests
%RUNINSPECTIONTESTS Exercise the Vm/trial and response-inspection helpers.
%   Covers vstim.buildTrialInspection, vstim.analyzeMovingBarInspection,
%   vstim.analyzeGaborMapInspection, vstim.detectBurstSpikes, and
%   vstim.rfOverlayStyle - the computational products behind
%   VisualAnalysisGUI's Response/RF and Vm/Trials views.
%
%   GUI rendering itself (uiaxes construction, layout, callbacks) is not
%   covered here: it was verified manually by driving a live
%   VisualAnalysisGUI instance (mocking uigetfile/uiputfile/questdlg to
%   avoid modal dialogs) and inspecting exported screenshots, per this
%   project's own preference for testing computational helpers
%   independently of GUI rendering. That includes confirming session
%   save/load compatibility (a run missing INSPECTIONRESULT - the new
%   field this change adds to EMPTYRUN - loads through the GUI's existing
%   generic per-field backfill in upgradeSession, which is unmodified by
%   this change); upgradeSession is a file-local function and cannot be
%   called from an external test file, so it is not re-verified here.

addpath(fileparts(fileparts(mfilename('fullpath'))));
rng(11);
testBurstDetection;
testRfOverlayStyle;
testTrialInspectionAlignsToOnset;
testTrialInspectionHandlesIncompleteRun;
testTrialInspectionHandlesZeroSpikeTrial;
testMovingBarInspectionReusesLatencyAndAxes;
testGaborMapInspectionPositionsAndPooling;
fprintf('All inspection tests passed.\n');
end

function testBurstDetection
% Three widely-spaced isolated spikes, then four spikes within a
% tight 5 ms run: only the tight run should be marked as a burst.
spikeTimesSec = [0;1;2; 5.000;5.005;5.010;5.015]; %#ok<NBRAK>
isBurst = vstim.detectBurstSpikes(spikeTimesSec,3,0.010);
assert(isequal(isBurst,[false;false;false;true;true;true;true]))

% Fewer than the minimum run length anywhere: nothing is a burst.
isBurst = vstim.detectBurstSpikes([0;0.005;1;1.005],3,0.010);
assert(~any(isBurst))
end

function testRfOverlayStyle
usableInterior = struct('usableCenter',true,'edgeWarning',false);
[~,~,note] = vstim.rfOverlayStyle(usableInterior);
assert(note=="usable")

usableEdge = struct('usableCenter',true,'edgeWarning',true);
[edgeColor,edgeLineStyle,edgeNote] = vstim.rfOverlayStyle(usableEdge);
assert(edgeNote=="at grid edge, uncertain")
assert(edgeLineStyle=="--")

notUsable = struct('usableCenter',false,'edgeWarning',true);
[~,notUsableLineStyle,notUsableNote] = vstim.rfOverlayStyle(notUsable);
assert(notUsableNote=="flagged not usable")
assert(notUsableLineStyle=="-")

% The three tiers must be visually distinct from one another.
[usableColor] = vstim.rfOverlayStyle(usableInterior);
[notUsableColor] = vstim.rfOverlayStyle(notUsable);
assert(~isequal(usableColor,edgeColor))
assert(~isequal(usableColor,notUsableColor))
assert(~isequal(edgeColor,notUsableColor))
end

function testTrialInspectionAlignsToOnset
fs = 20000;
nTrials = 6;
trials = table((1:nTrials)',repmat(0.1,nTrials,1),repmat(0.3,nTrials,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
trials.axis = repmat("azimuth",nTrials,1);
trials.positionDeg = [-20;-10;0;10;20;0];
trials.polarity = ones(nTrials,1);
runData = makeRun("Flashed bars",trials);

onsets = round((1:nTrials)*0.4*fs)';
% Exactly one known spike per trial, 15 ms after that trial's onset.
spikeOffsetSec = 0.015;
spikes = onsets+round(spikeOffsetSec*fs);
data = makePreprocessedData(onsets,spikes,trials.durationSec,fs);
alignment = vstim.alignRecordedStimuli(runData,data);

inspection = vstim.buildTrialInspection(runData,data,alignment);
assert(inspection.protocol=="Flashed bars")
assert(height(inspection.trials)==nTrials)
for i = 1:nTrials
    spikeTimesMs = inspection.trials.spikeTimesMs{i};
    assert(numel(spikeTimesMs)==1)
    assert(abs(spikeTimesMs-spikeOffsetSec*1000)<1e-6)
end
assert(numel(inspection.overview.spikeTimesSec)==nTrials)
assert(~isempty(inspection.overview.timeSec))
end

function testTrialInspectionHandlesIncompleteRun
% Fewer recorded TTLs than planned trials (an aborted run) must still
% produce a valid, shorter inspection rather than erroring.
fs = 20000;
nPlanned = 8;
trials = table((1:nPlanned)',repmat(0.1,nPlanned,1),repmat(0.2,nPlanned,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
runData = makeRun("Sparse noise",trials);

nRecorded = 5; % Run canceled partway through.
onsets = round((1:nRecorded)*0.3*fs)';
data = makePreprocessedData(onsets,[],trials.durationSec(1:nRecorded),fs);
alignment = vstim.alignRecordedStimuli(runData,data);
assert(alignment.matchedTrialCount==nRecorded)
assert(~alignment.completeMatch)

inspection = vstim.buildTrialInspection(runData,data,alignment);
assert(height(inspection.trials)==nRecorded)
end

function testTrialInspectionHandlesZeroSpikeTrial
fs = 20000;
nTrials = 4;
trials = table((1:nTrials)',repmat(0.1,nTrials,1),repmat(0.2,nTrials,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
runData = makeRun("Sparse noise",trials);
onsets = round((1:nTrials)*0.3*fs)';
data = makePreprocessedData(onsets,[],trials.durationSec,fs); % No spikes at all.
alignment = vstim.alignRecordedStimuli(runData,data);
inspection = vstim.buildTrialInspection(runData,data,alignment);
for i = 1:nTrials
    assert(isempty(inspection.trials.spikeTimesMs{i}))
end
assert(isempty(inspection.overview.spikeTimesSec))
end

function testMovingBarInspectionReusesLatencyAndAxes
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
    forward = any(trials.direction(i)==["left_to_right","bottom_to_top"]);
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
fs = 10000;
onsets = round((1:height(trials))*1.5*fs)';
spikesByTrial = cell(height(trials),1);
for i = 1:height(trials)
    if trials.axis(i)=="azimuth", center = 5; else, center = -5; end
    trajectory = trials.frameCentersDeg{i};
    [~,frame] = min(abs(trajectory-center));
    visualTime = (frame-1)/(numel(trajectory)-1)*trials.durationSec(i);
    spikeTime = visualTime+0.08+(0:3)*0.003;
    spikesByTrial{i} = onsets(i)+round(spikeTime*fs);
end
data = makeDataFromSpikes(onsets,vertcat(spikesByTrial{:}),trials.durationSec,fs);
options = struct('bootstrapRepetitions',20,'spikeLatencyRangeMs',[20 140], ...
    'spikeBinMs',10,'positionBinDeg',5);
result = vstim.analyzeSpikeReceptiveField(runData,data,options);
alignment = vstim.alignRecordedStimuli(runData,data);
fullOptions = vstim.analysisOptions(runData,options);
inspection = vstim.analyzeMovingBarInspection(runData,data,alignment,fullOptions,result);

assert(inspection.preferredLatencyMs==result.preferredLatencyMs)
assert(numel(inspection.directions)==4)
for d = 1:numel(inspection.directions)
    block = inspection.directions{d};
    if block.axis=="azimuth"
        expectedCenter = result.rfCenterAzimuthDeg;
    else
        expectedCenter = result.rfCenterElevationDeg;
    end
    % The renderer reads this same center from inspection.rfProfiles, so
    % confirm the copied profile is exactly the fit's own, not re-derived.
    if block.axis=="azimuth"
        assert(isequal(inspection.rfProfiles.azimuth,result.profiles.azimuth))
    else
        assert(isequal(inspection.rfProfiles.elevation,result.profiles.elevation))
    end
    assert(isfinite(expectedCenter))
    for p = 1:numel(block.polarities)
        pol = block.polarities{p};
        assert(numel(pol.spikePositionsDegByTrial)==6)
        assert(all(pol.upperBandSpikesPerTrial>=pol.lowerBandSpikesPerTrial | ...
            isnan(pol.upperBandSpikesPerTrial)))
    end
end
end

function testGaborMapInspectionPositionsAndPooling
[az,el] = ndgrid(-20:10:20,-15:10:15);
az = az(:); el = el(:);
[positionIndex,orientationDeg,repetition] = ndgrid( ...
    (1:numel(az))',[0 45 90 135],1:5);
trials = table(positionIndex(:),az(positionIndex(:)),el(positionIndex(:)), ...
    orientationDeg(:),repetition(:), ...
    'VariableNames',{'positionIndex','azimuthDeg','elevationDeg', ...
    'orientationDeg','repetition'});
trials.durationSec = repmat(0.3,height(trials),1);
trials.interStimulusSec = repmat(0.2,height(trials),1);
runData = makeRun("Fast Gabor tiling",trials);
runData.sequence.grid = table((1:numel(az))',az,el, ...
    'VariableNames',{'locationIndex','azimuthDeg','elevationDeg'});
fs = 10000;
onsets = round((1:height(trials))*0.5*fs)';
data = makeDataFromSpikes(onsets,[],trials.durationSec,fs);

overrides = struct('bootstrapRepetitions',20);
alignment = vstim.alignRecordedStimuli(runData,data);
fullOptions = vstim.analysisOptions(runData,overrides);
inspection = vstim.analyzeGaborMapInspection(runData,data,alignment,fullOptions);

assert(numel(inspection.positions)==numel(az))
for i = 1:numel(inspection.positions)
    p = inspection.positions{i};
    assert(p.azimuthDeg==az(p.positionIndex))
    assert(p.elevationDeg==el(p.positionIndex))
    % 4 orientations x 5 repetitions pooled into one PSTH per position.
    assert(p.trialCount==20)
    assert(numel(p.binCentersMs)==numel(p.meanRateHz))
end
assert(isequal(inspection.azimuthAxisDeg,sort(unique(az))))
assert(isequal(inspection.elevationAxisDeg,sort(unique(el))))
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

function data = makeDataFromSpikes(onsets,spikes,durations,fs)
% Matches tests/runAnalysisTests.m's own fixture convention: no real
% preprocessing (fs can be any value, including the 10000 Hz used by the
% moving-bar/Gabor tests below), since vstim.analyzeMovingBarInspection
% and vstim.analyzeGaborMapInspection only need data.meta.fs/data.spikes.
% spks, the same as the underlying RF-fit functions they accompany.
nSamples = ceil(max(onsets+round((durations+0.3)*fs)));
screen = false(1,nSamples);
for i = 1:numel(onsets)
    screen(onsets(i):min(nSamples,onsets(i)+round(durations(i)*fs))) = true;
end
data.di.screen = screen;
data.meta.fs = fs;
data.spikes.spks = sort(double(spikes(:)))';
end

function data = makePreprocessedData(onsets,spikes,durations,fs)
% Unlike makeDataFromSpikes, vstim.buildTrialInspection needs real
% data.proc.volt/data.spikes.peaks, so this fixture goes through
% vstim.preprocessForAnalysis (which requires fs > 10000 Hz for its
% low-pass filter, hence the separate helper).
nSamples = ceil(max(onsets+round((durations+0.3)*fs)));
screen = false(1,nSamples);
for i = 1:numel(onsets)
    screen(onsets(i):min(nSamples,onsets(i)+round(durations(i)*fs))) = true;
end
volt = -65+0.1*randn(1,nSamples);
data.ai.volt = volt;
data.meta.fs = fs;
data.meta.samples = nSamples;
data = vstim.preprocessForAnalysis(data);
data.di.screen = screen;
% Override the (near-empty, noise-only) detected spikes with the exact
% known spike samples this fixture is built around, so downstream
% inspection functions are exercised against precisely known ground
% truth rather than whatever removeSpikes happened to find in noise.
data.spikes.spks = sort(double(spikes(:)))';
data.spikes.peaks = repmat(-20,size(data.spikes.spks));
end
