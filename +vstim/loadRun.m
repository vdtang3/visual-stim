function runData = loadRun(filename)
%LOADRUN Load and minimally validate a saved visual-stimulation run.
s = load(filename, 'runData');
if ~isfield(s, 'runData')
    error('vstim:InvalidRunFile', 'File does not contain runData.')
end
runData = s.runData;
required = {'params', 'sequence', 'presentation', 'sync', 'status'};
missing = required(~isfield(runData, required));
if ~isempty(missing)
    error('vstim:InvalidRunFile', 'Missing fields: %s', strjoin(missing, ', '))
end
end
