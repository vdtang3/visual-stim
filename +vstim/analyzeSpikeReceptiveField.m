function result = analyzeSpikeReceptiveField(runData,data,overrides)
%ANALYZESPIKERECEPTIVEFIELD Dispatch the approved quick spike analysis.
%
% data must already have passed through preprocess(data,"sweep",true).
% The force flag is important here: this quick-look tool never applies the
% laboratory dataset-exclusion criteria.

if nargin < 3
    overrides = struct();
end
protocol = string(runData.params.protocol);
if protocol == "Gabor + inverse stimuli"
    error('vstim:ProtocolNotAnalyzed', ...
        ['Classical, inverse, and full-field responses are intentionally ' ...
         'left for offline analysis.'])
end
if ~isfield(data,'spikes') || ~isfield(data.spikes,'spks')
    error('vstim:PreprocessingRequired', ...
        ['No detected spikes were found. Run the standard in-vivo-patch ' ...
         'preprocess(data,"sweep",true) pipeline first.'])
end

options = vstim.analysisOptions(runData,overrides);
alignment = vstim.alignRecordedStimuli(runData,data);
switch protocol
    case "Moving bars"
        result = vstim.analyzeMovingBarsSpikes( ...
            runData,data,alignment,options);
    case "Flashed bars"
        result = vstim.analyzeFlashedBarsSpikes( ...
            runData,data,alignment,options);
    case "Sparse noise"
        result = vstim.analyzeSparseNoiseSpikes( ...
            runData,data,alignment,options);
    case {"Fast Gabor tiling","Targeted Gabor grid"}
        result = vstim.analyzeGaborMapSpikes( ...
            runData,data,alignment,options);
    otherwise
        error('vstim:UnsupportedAnalysisProtocol', ...
            'No quick analysis is implemented for protocol "%s".',protocol)
end
result.analysisOptions = options;
result.createdAt = datetime('now');
end
