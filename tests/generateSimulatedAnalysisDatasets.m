function manifest = generateSimulatedAnalysisDatasets(outputDirectory)
%GENERATESIMULATEDANALYSISDATASETS Create paired runData and WaveSurfer H5s.
% The five recordings share a known RF center at azimuth +5 degrees and
% elevation -5 degrees. Files use the minimal HDF5 layout consumed by the
% laboratory loadws -> WaveSurfer loadDataFile pipeline.

if nargin < 1
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    outputDirectory = fullfile(projectRoot,'test_data','simulated_rf');
end
if ~exist(outputDirectory,'dir')
    mkdir(outputDirectory);
end
rng(17);
fs = 20000;
truth = [5 -5];
builders = {@movingRun,@flashedRun,@sparseRun,@gaborRun,@targetedRun};
slugs = ["moving_bars","flashed_bars","sparse_noise", ...
    "fast_gabor_tiling","targeted_gabor_grid"];
protocols = ["Moving bars","Flashed bars","Sparse noise", ...
    "Fast Gabor tiling","Targeted Gabor grid"];
n = numel(builders);
h5Files = strings(n,1);
runDataFiles = strings(n,1);
expectedAzimuthDeg = repmat(truth(1),n,1);
expectedElevationDeg = repmat(truth(2),n,1);
sessionRuns = repmat(struct('runDataFile',"",'waveSurferFile',"", ...
    'h5Pairing',"Metadata",'protocol',"",'parameterSummary',"Synthetic", ...
    'status',"Ready",'analysisResult',[],'analysisOverrides',struct(), ...
    'stimulusTiming',struct(),'dataMetrics',struct()),n,1);

for i = 1:n
    [runData,spikeSamples] = builders{i}(fs,truth);
    h5Name = sprintf('simcell_%04d.h5',i);
    h5File = fullfile(outputDirectory,h5Name);
    writeWaveSurferH5(h5File,runData.sequence,spikeSamples,fs);
    runData.params.session.wavesurferFile = string(h5File);
    runData.params.session.wavesurferDetected = true;
    runData.params.session.wavesurferFilename = string(h5Name);
    runData.params.session.wavesurferFolder = string(outputDirectory);
    runData.status.savedFile = "";
    runName = sprintf('simcell_%04d_%s_runData.mat',i,slugs(i));
    runFile = fullfile(outputDirectory,runName);
    runData.status.savedFile = string(runFile);
    save(runFile,'runData','-v7.3');
    h5Files(i) = string(h5File);
    runDataFiles(i) = string(runFile);
    [analysisOverrides,stimulusTiming] = ...
        vstim.analysisOptionsForRun(runData);
    sessionRuns(i).runDataFile = string(runFile);
    sessionRuns(i).waveSurferFile = string(h5File);
    sessionRuns(i).protocol = protocols(i);
    sessionRuns(i).analysisOverrides = analysisOverrides;
    sessionRuns(i).stimulusTiming = stimulusTiming;
    fprintf('Created %s and %s\n',h5Name,runName);
end

manifest = table(protocols(:),h5Files,runDataFiles, ...
    expectedAzimuthDeg,expectedElevationDeg, ...
    'VariableNames',{'protocol','h5File','runDataFile', ...
    'expectedAzimuthDeg','expectedElevationDeg'});
save(fullfile(outputDirectory,'simulated_dataset_manifest.mat'), ...
    'manifest','-v7.3');
cellAnalysisSession.schemaVersion = "1.0.0";
cellAnalysisSession.cellID = "simcell";
cellAnalysisSession.createdAt = datetime(2026,1,1);
cellAnalysisSession.updatedAt = datetime(2026,1,1);
cellAnalysisSession.runs = sessionRuns;
cellAnalysisSession.consensusResult = [];
save(fullfile(outputDirectory,'simcell_rf_session.mat'), ...
    'cellAnalysisSession','-v7.3');
end

function [runData,spikes] = movingRun(fs,truth)
directions = ["left_to_right","right_to_left", ...
    "bottom_to_top","top_to_bottom"];
[direction,polarity,repetition] = ndgrid(directions,[-1 1],1:4);
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
runData = baseRun("Moving bars",trials);
onsets = trialOnsets(trials,fs);
spikes = [];
for i = 1:height(trials)
    if trials.axis(i)=="azimuth"
        center = truth(1);
    else
        center = truth(2);
    end
    trajectory = trials.frameCentersDeg{i};
    [~,frame] = min(abs(trajectory-center));
    visualTime = (frame-1)/(numel(trajectory)-1)*trials.durationSec(i);
    spikeTime = visualTime+0.08+(0:3)*0.003;
    spikes = [spikes;onsets(i)+round(spikeTime(:)*fs)]; %#ok<AGROW>
end
end

function [runData,spikes] = flashedRun(fs,truth)
positions = (-25:10:25)';
[axisName,position,polarity,repetition] = ndgrid( ...
    ["azimuth","elevation"],positions,[-1 1],1:5);
trials = table(axisName(:),position(:),polarity(:),repetition(:), ...
    'VariableNames',{'axis','positionDeg','polarity','repetition'});
trials.durationSec = repmat(0.1,height(trials),1);
trials.interStimulusSec = repmat(0.3,height(trials),1);
runData = baseRun("Flashed bars",trials);
onsets = trialOnsets(trials,fs);
spikes = [];
for i = 1:height(trials)
    if trials.axis(i)=="azimuth", center=truth(1); else, center=truth(2); end
    rate = 2+42*exp(-0.5*((trials.positionDeg(i)-center)/8)^2);
    count = stochasticCount(rate*0.17);
    spikes = [spikes;windowSpikes(onsets(i),count,[0.025 0.185],fs)]; %#ok<AGROW>
end
end

function [runData,spikes] = sparseRun(fs,truth)
[az,el] = ndgrid(-20:10:20,-15:10:15);
az = az(:); el = el(:);
nLocations = numel(az);
nPatterns = 400;
patterns = zeros(nLocations,nPatterns,'int8');
for i = 1:nPatterns
    chosen = randperm(nLocations,6);
    patterns(chosen(1:3),i) = 1;
    patterns(chosen(4:6),i) = -1;
end
trials = table((1:nPatterns)',repmat(0.05,nPatterns,1), ...
    repmat(0.05,nPatterns,1), ...
    'VariableNames',{'trialIndex','durationSec','interStimulusSec'});
runData = baseRun("Sparse noise",trials);
runData.sequence.ttlMode = "onset_pulse";
runData.sequence.stimulusMatrix = patterns;
runData.sequence.grid = table((1:nLocations)',az,el, ...
    'VariableNames',{'locationIndex','azimuthDeg','elevationDeg'});
runData.params.protocolAnalysis.testedLagsMs = 0:10:100;
runData.params.protocolAnalysis.spikeBinMs = 20;
onsets = trialOnsets(trials,fs);
rf = exp(-0.5*(((az-truth(1))/9).^2+ ...
    ((el-truth(2))/8).^2));
rate = 2+85*(double(patterns==1)'*rf)+ ...
    60*(double(patterns==-1)'*rf);
spikes = [];
for i = 1:nPatterns
    count = min(4,stochasticCount(rate(i)*0.02));
    spikes = [spikes;windowSpikes(onsets(i),count,[0.05 0.068],fs)]; %#ok<AGROW>
end
end

function [runData,spikes] = gaborRun(fs,truth)
[az,el] = ndgrid(-20:10:20,-15:10:15);
[runData,spikes] = makeGabor("Fast Gabor tiling",az(:),el(:), ...
    fs,truth,3);
end

function [runData,spikes] = targetedRun(fs,truth)
[azOffset,elOffset] = ndgrid(-10:10:10,-10:10:10);
az = truth(1)+azOffset(:);
el = truth(2)+elOffset(:);
[runData,spikes] = makeGabor("Targeted Gabor grid",az,el,fs,truth,3);
end

function [runData,spikes] = makeGabor(protocol,az,el,fs,truth,repetitions)
[positionIndex,orientationDeg,repetition] = ndgrid( ...
    (1:numel(az))',[0 45 90 135],1:repetitions);
trials = table(positionIndex(:),az(positionIndex(:)), ...
    el(positionIndex(:)),orientationDeg(:),repetition(:), ...
    'VariableNames',{'positionIndex','azimuthDeg','elevationDeg', ...
    'orientationDeg','repetition'});
trials.durationSec = repmat(0.2,height(trials),1);
trials.interStimulusSec = repmat(0.1,height(trials),1);
runData = baseRun(protocol,trials);
runData.sequence.grid = table((1:numel(az))',az,el, ...
    'VariableNames',{'locationIndex','azimuthDeg','elevationDeg'});
onsets = trialOnsets(trials,fs);
rate = 2+42*exp(-0.5*( ...
    ((trials.azimuthDeg-truth(1))/9).^2+ ...
    ((trials.elevationDeg-truth(2))/8).^2));
spikes = [];
for i = 1:height(trials)
    count = stochasticCount(rate(i)*0.17);
    spikes = [spikes;windowSpikes(onsets(i),count,[0.025 0.19],fs)]; %#ok<AGROW>
end
end

function runData = baseRun(protocol,trials)
cfg = vstim.defaultConfig(protocol);
cfg.session.randomSeed = 17;
runData.params = cfg;
runData.sequence.trials = trials;
runData.sequence.ttlMode = "epoch";
runData.sequence.estimatedDurationSec = ...
    sum(trials.durationSec+trials.interStimulusSec);
runData.presentation = struct('simulated',true);
runData.sync = struct('simulated',true);
runData.status = struct('completed',true,'aborted',false, ...
    'message',"Synthetic RF dataset",'startedAt',datetime(2026,1,1), ...
    'endedAt',datetime(2026,1,1));
end

function onsets = trialOnsets(trials,fs)
cycle = trials.durationSec+trials.interStimulusSec;
onsets = round((0.5+[0;cumsum(cycle(1:end-1))])*fs)+1;
end

function samples = windowSpikes(onset,count,windowSec,fs)
if count==0
    samples = zeros(0,1);
    return
end
times = linspace(windowSec(1),windowSec(2),count+2);
samples = onset+round(times(2:end-1)'*fs);
end

function n = stochasticCount(expected)
n = floor(expected)+(rand<expected-floor(expected));
end

function writeWaveSurferH5(filename,sequence,spikeSamples,fs)
if isfile(filename)
    delete(filename);
end
onsets = trialOnsets(sequence.trials,fs);
lastTrialEnd = onsets(end)+round( ...
    (sequence.trials.durationSec(end)+ ...
    sequence.trials.interStimulusSec(end)+0.5)*fs);
nSamples = lastTrialEnd;
voltageMv = -65+0.7*randn(nSamples,1);
halfWidth = round(0.0015*fs);
offset = (-halfWidth:halfWidth)';
waveform = 95*exp(-0.5*(offset/(0.00045*fs)).^2);
for i = 1:numel(spikeSamples)
    indices = spikeSamples(i)+offset;
    keep = indices>=1 & indices<=nSamples;
    voltageMv(indices(keep)) = voltageMv(indices(keep))+waveform(keep);
end
voltsPerCount = 10/32768;
channelScale = 0.001; % volts per mV
mvPerCount = voltsPerCount/channelScale;
analogScans = int16(round(voltageMv/mvPerCount));
digitalScans = zeros(nSamples,1,'uint8');
for i = 1:numel(onsets)
    if string(sequence.ttlMode)~="epoch"
        highSamples = round(fs/sequence.nominalFrameRate);
    else
        highSamples = round(sequence.trials.durationSec(i)*fs);
    end
    stop = min(nSamples,onsets(i)+highSamples-1);
    digitalScans(onsets(i):stop) = bitset( ...
        digitalScans(onsets(i):stop),1,1);
end

writeNumeric(filename,'/header/AcquisitionSampleRate',double(fs));
writeNumeric(filename,'/header/ClockAtRunStart', ...
    [2026 1 1 12 0 0]);
writeString(filename,'/header/VersionString',"0.982");
writeNumeric(filename,'/header/NAIChannels',1);
writeString(filename,'/header/AIChannelNames',"Vm");
writeNumeric(filename,'/header/AIChannelScales',channelScale);
writeNumeric(filename,'/header/AIScalingCoefficients', ...
    [0;voltsPerCount;0;0]);
writeNumeric(filename,'/header/IsAIChannelActive',1);
writeString(filename,'/header/DIChannelNames',"Screen");
writeNumeric(filename,'/header/IsDIChannelActive',1);
writeNumeric(filename,'/header/IsStimulationEnabled',0);
writeNumeric(filename,'/sweep_0001/timestamp',0);
writeLarge(filename,'/sweep_0001/analogScans',analogScans);
writeLarge(filename,'/sweep_0001/digitalScans',digitalScans);
end

function writeNumeric(filename,path,value)
h5create(filename,path,size(value),'Datatype',class(value));
h5write(filename,path,value);
end

function writeString(filename,path,value)
h5create(filename,path,1,'Datatype','string');
h5write(filename,path,string(value));
end

function writeLarge(filename,path,value)
chunk = [min(size(value,1),20000),size(value,2)];
h5create(filename,path,size(value),'Datatype',class(value), ...
    'ChunkSize',chunk,'Deflate',1);
h5write(filename,path,value);
end
