function filename = stimulusRunFilename(cfg, stamp)
%STIMULUSRUNFILENAME Name a run for its recording and stimulus protocol.

if nargin < 2 || strlength(string(stamp)) == 0
    stamp = string(datetime('now','Format','yyyyMMdd_HHmmss'));
else
    stamp = string(stamp);
end

protocolSlug = fileSlug(cfg.protocol);
prefixSlug = fileSlug(cfg.session.filePrefix);
sweepSlug = "";
if isfield(cfg.session,'wavesurferSweep') && ...
        strlength(string(cfg.session.wavesurferSweep)) > 0
    [~,sweepName] = fileparts(char(string(cfg.session.wavesurferSweep)));
    sweepSlug = fileSlug(sweepName);
end

parts = strings(0,1);
if strlength(sweepSlug) > 0
    parts(end+1) = sweepSlug;
end
parts(end+1) = protocolSlug;
if strlength(prefixSlug) > 0
    parts(end+1) = prefixSlug;
end
parts(end+1) = fileSlug(stamp);
filename = strjoin(parts,"_") + ".mat";
end

function slug = fileSlug(value)
slug = lower(string(value));
slug = regexprep(slug,'[^a-zA-Z0-9]+','_');
slug = regexprep(slug,'^_+|_+$','');
end
