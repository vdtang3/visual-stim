function detected = detectedH5ForRun(runData)
%DETECTEDH5FORRUN Return the WaveSurfer file saved in run metadata.

detected = "";
if ~isfield(runData,'params') || ...
        ~isfield(runData.params,'session')
    return
end
session = runData.params.session;
if isfield(session,'wavesurferFile') && ...
        strlength(string(session.wavesurferFile)) > 0
    detected = string(session.wavesurferFile);
elseif isfield(session,'wavesurferFolder') && ...
        isfield(session,'wavesurferFilename')
    detected = string(fullfile( ...
        session.wavesurferFolder,session.wavesurferFilename));
end
end
