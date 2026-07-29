function detection = detectLatestWaveSurferFile(session)
%DETECTLATESTWAVESURFERFILE Find the newest recent H5 acquisition file.

detection.enabled = logical(session.autoDetectWaveSurferFile);
detection.found = false;
detection.file = "";
detection.filename = "";
detection.folder = string(session.wavesurferSearchDirectory);
detection.modifiedAt = NaT;
detection.ageMinutes = NaN;
detection.maximumAgeMinutes = session.wavesurferMaximumAgeMinutes;
detection.message = "WaveSurfer autodetection disabled";

if ~detection.enabled
    return
end
folder = char(detection.folder);
if isempty(folder) || ~isfolder(folder)
    detection.message = "WaveSurfer folder not found; continuing without association";
    return
end

files = [dir(fullfile(folder, '*.h5')); dir(fullfile(folder, '*.H5'))];
if isempty(files)
    detection.message = "No WaveSurfer H5 file found; continuing without association";
    return
end
[~, newest] = max([files.datenum]);
candidate = files(newest);
ageMinutes = max(0, (now-candidate.datenum)*24*60);
if ageMinutes > detection.maximumAgeMinutes
    detection.message = sprintf( ...
        'Newest WaveSurfer file is %.1f min old; continuing without association', ...
        ageMinutes);
    return
end

detection.found = true;
detection.file = string(fullfile(candidate.folder, candidate.name));
detection.filename = string(candidate.name);
detection.folder = string(candidate.folder);
detection.modifiedAt = datetime(candidate.datenum, ...
    'ConvertFrom', 'datenum');
detection.ageMinutes = ageMinutes;
detection.message = sprintf( ...
    'Found WaveSurfer file %s (%.1f min old); saved in run metadata', ...
    candidate.name, ageMinutes);
end
