function detection = detectLatestWaveSurferFile(session)
%DETECTLATESTWAVESURFERFILE Find today's newest recent H5 acquisition file.

detection.enabled = logical(session.autoDetectWaveSurferFile);
detection.found = false;
detection.file = "";
detection.filename = "";
detection.parentDirectory = string(session.wavesurferParentDirectory);
detection.dateFolderName = string(datetime('today','Format','yyyyMMdd'));
detection.folder = string(fullfile(detection.parentDirectory, ...
    detection.dateFolderName));
detection.modifiedAt = NaT;
detection.ageMinutes = NaN;
detection.maximumAgeMinutes = session.wavesurferMaximumAgeMinutes;
detection.message = "WaveSurfer autodetection disabled";

if ~detection.enabled
    return
end
folder = char(detection.folder);
if isempty(folder) || ~isfolder(folder)
    detection.message = sprintf( ...
        ['Today''s WaveSurfer folder was not found: %s; continuing ' ...
         'without association'], folder);
    return
end

files = [dir(fullfile(folder, '*.h5')); dir(fullfile(folder, '*.H5'))];
if isempty(files)
    detection.message = sprintf( ...
        ['No WaveSurfer H5 file found in today''s folder %s; ' ...
         'continuing without association'], folder);
    return
end
[~, newest] = max([files.datenum]);
candidate = files(newest);
modifiedAt = datetime(candidate.datenum,'ConvertFrom','datenum');
ageMinutes = max(0,minutes(datetime('now')-modifiedAt));
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
detection.modifiedAt = modifiedAt;
detection.ageMinutes = ageMinutes;
detection.message = sprintf( ...
    'Found WaveSurfer file %s (%.1f min old); saved in run metadata', ...
    candidate.name, ageMinutes);
end
