function [positions,timingSource,frameTimesSec] = ...
        movingBarSpikePositions(visualTimesSec,trial,frameIntervalSec)
%MOVINGBARSPIKEPOSITIONS Map TTL-relative times onto a saved trajectory.
% The first nominal frame is index zero; duration is deliberately not
% spread across all frame centers with linspace.

centers = double(trial.frameCentersDeg{1}(:));
frameTimesSec = [];
timingSource = "nominal";
if ismember('framePresentationTimesSec',trial.Properties.VariableNames)
    candidate = double(trial.framePresentationTimesSec{1}(:));
    if numel(candidate) == numel(centers) && all(isfinite(candidate)) && ...
            all(diff(candidate) > 0)
        frameTimesSec = candidate;
        timingSource = "actual";
    end
end
if isempty(frameTimesSec)
    if ~isscalar(frameIntervalSec) || ~isfinite(frameIntervalSec) || ...
            frameIntervalSec <= 0
        frameIntervalSec = double(trial.durationSec)/numel(centers);
    end
    frameTimesSec = (0:numel(centers)-1)'*frameIntervalSec;
end

positions = interp1(frameTimesSec,centers,double(visualTimesSec(:)), ...
    'linear',NaN);
end
