function validation = validateSimulatedAnalysisDatasets(datasetDirectory)
%VALIDATESIMULATEDANALYSISDATASETS Run the real H5-to-RF path on test files.

if nargin < 1
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    datasetDirectory = fullfile(projectRoot,'test_data','simulated_rf');
end
loaded = load(fullfile(datasetDirectory, ...
    'simulated_dataset_manifest.mat'),'manifest');
manifest = loaded.manifest;
n = height(manifest);
estimatedAzimuthDeg = nan(n,1);
estimatedElevationDeg = nan(n,1);
durationSec = nan(n,1);
detectedSpikes = nan(n,1);
passed = false(n,1);
for i = 1:n
    runData = vstim.loadRun(manifest.runDataFile(i));
    data = vstim.loadWaveSurferForAnalysis(manifest.h5File(i));
    data = vstim.preprocessForAnalysis(data);
    [options,~] = vstim.analysisOptionsForRun(runData);
    options.bootstrapRepetitions = 20;
    result = vstim.analyzeSpikeReceptiveField(runData,data,options);
    estimatedAzimuthDeg(i) = result.rfCenterAzimuthDeg;
    estimatedElevationDeg(i) = result.rfCenterElevationDeg;
    durationSec(i) = runData.sequence.estimatedDurationSec;
    detectedSpikes(i) = result.spikeCount;
    errorDeg = hypot( ...
        estimatedAzimuthDeg(i)-manifest.expectedAzimuthDeg(i), ...
        estimatedElevationDeg(i)-manifest.expectedElevationDeg(i));
    passed(i) = result.usableCenter && errorDeg<12 && durationSec(i)<=180;
end
validation = table(manifest.protocol,durationSec,detectedSpikes, ...
    manifest.expectedAzimuthDeg,manifest.expectedElevationDeg, ...
    estimatedAzimuthDeg,estimatedElevationDeg,passed, ...
    'VariableNames',{'protocol','durationSec','detectedSpikes', ...
    'expectedAzimuthDeg','expectedElevationDeg','estimatedAzimuthDeg', ...
    'estimatedElevationDeg','passed'});
disp(validation);
assert(all(passed),'One or more simulated datasets failed validation.')
end
