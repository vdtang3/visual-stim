function options = analysisOptions(runData, overrides)
%ANALYSISOPTIONS Collect saved protocol settings and quick-analysis choices.

options = struct();
if isfield(runData.params, 'protocolAnalysis')
    options = runData.params.protocolAnalysis;
end
if isfield(runData.params, 'analysis') && ...
        isfield(runData.params.analysis, 'bootstrapRepetitions')
    options.bootstrapRepetitions = ...
        runData.params.analysis.bootstrapRepetitions;
end
if nargin > 1 && ~isempty(overrides)
    names = fieldnames(overrides);
    for i = 1:numel(names)
        options.(names{i}) = overrides.(names{i});
    end
end

options = setDefault(options, 'bootstrapRepetitions', 200);
options = setDefault(options, 'responseWindowMs', [20 200]);
options = setDefault(options, 'baselineWindowMs', [-100 0]);
options = setDefault(options, 'spikeBinMs', 10);
options = setDefault(options, 'testedLagsMs', 0:10:200);
options = setDefault(options, 'regularizationStrength', 1);
options = setDefault(options, 'crossValidationFolds', 5);
options = setDefault(options, 'positionBinDeg', 4.8);
options = setDefault(options, 'spikeLatencyRangeMs', [20 200]);
options = setDefault(options, 'minimumSweeps', 8);
options = setDefault(options, 'minimumPeakResponseHz', 1);
options = setDefault(options, 'minimumResponseDynamicRangeHz', 1);
options = setDefault(options, 'minimumFitQuality', 0.05);
options.randomSeed = 1;
if isfield(runData.params, 'session') && ...
        isfield(runData.params.session, 'randomSeed')
    options.randomSeed = runData.params.session.randomSeed;
end
end

function s = setDefault(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
