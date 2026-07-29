function data = loadws(wspath)
% LOADWS Load and simplify WaveSurfer data file into a compact struct.
%   data = loadws(wspath) loads a WaveSurfer data file specified by
%   wspath (file or folder input accepted by dir) and returns a simplified
%   scalar struct with three main fields:
%     data.ai   — struct of analog channels (volt, curr, locomotion, lfp, opto)
%     data.di   — struct of digital channels (screen, licks, cam, opto, rew_win, valve, distractor)
%     data.meta — metadata (date, id, pipette, sweep, start, samples, fs, time, isStimEnabled, fpath, wavesurfer_version)
%
%   This function is extensible. The default channel maps can be renamed as
%   necessary by the end user, in the format:
%       {'WaveSurferChannelName1', 'OutputStructChannelName1';
%        'WaveSurferChannelName2', 'OutputStructChannelName2'} 
%
%   The function:
%     - resolves the provided path via dir and extracts filename and folder
%     - reads raw WaveSurfer data using ws.loadDataFile
%     - maps available AI/DI channels into the fixed sets above using
%       helper functions getAIByName and getDIByName
%     - computes acquisition start time (POSIX) using header.ClockAtRunStart
%     - populates data.meta with sampling info and derived time vector
%
%   Inputs
%     wspath — path to a WaveSurfer file or pattern accepted by dir
%               (char vector or string). If multiple matches exist, the
%               first matching file is used.
%
%   Output
%     data — scalar struct with fields described above. Analog and digital
%            channel fields contain the channel data arrays (empty if
%            channel not present in file). data.meta.time is a 1-by-N
%            vector where N equals data.meta.samples.
%
%   Example
%     % Load a single WaveSurfer file by full path
%     d = loadws('C:\data\20230501_p1_001.h5');
%
%   Notes
%     - Requires WaveSurfer MATLAB API function ws.loadDataFile and the
%       helper functions getAIByName/getDIByName on the MATLAB path.
%     - Time zone used for ClockAtRunStart is America/New_York in the
%       current implementation.
%
%   See also ws.loadDataFile, getAIByName, getDIByName
    
    wspath = dir(wspath);
    fname = wspath.name;
    fpath = wspath.folder;

    [~, DATE] = fileparts(fpath);
    fparts = strsplit(fname, '_');
    CELL = fparts{1};
    tmp = strsplit(fparts{2}, '.');
    SWEEP = tmp{1};
    ID = [DATE CELL];

    raw_data = loadDataFile(fullfile(fpath, fname));
    fields = fieldnames(raw_data);
    header = raw_data.header;
    scans = raw_data.(fields{2});

    % create channel map
    AIChannelMap = { ...
        'Vm', 'volt'; ...
        'Iinj', 'curr'; ...
        'Loco', 'locomotion'; ...
        'LFP', 'lfp'; ...
        'Opto', 'opto'; ...
        'Voltage', 'volt'; ...  % ensure backward compatibility with older WaveSurfer files
        'Current', 'curr'; ...
        'Treadmill', 'locomotion';
        };

    DIChannelMap = { ...
        'Screen', 'screen'; ...
        'Lick', 'licks'; ...
        'OptoDI', 'opto'; ...
        'RewWin', 'rew_win'; ...
        'ValveIn', 'valve'; ...
        'Cam', 'cam'; ...
        'Distractor', 'distractor' ...
        };

    % initialize output structs based off provided map
    aiFields = unique(AIChannelMap(:,2), 'stable');
    diFields = unique(DIChannelMap(:,2), 'stable');

    data.ai = cell2struct(repmat({[]}, numel(aiFields), 1), aiFields, 1);
    data.di = cell2struct(repmat({[]}, numel(diFields), 1), diFields, 1);

    % fill optional analog channels (indexed within active AI list)
    % Multiple WaveSurfer names may map to the same output field (e.g.
    % 'Vm' and the legacy 'Voltage' both map to 'volt'); only assign when a
    % match is found so a non-matching alias does not clobber a good value.
    for k = 1:size(AIChannelMap, 1)
        channelName = AIChannelMap{k, 1};
        fieldname = AIChannelMap{k, 2};
        val = getAIByName(scans, header, channelName);
        if ~isempty(val)
            data.ai.(fieldname) = val;
        end
    end

    % fill optional digital channels
    for k = 1:size(DIChannelMap, 1)
        channelName = DIChannelMap{k, 1};
        fieldname = DIChannelMap{k, 2};
        val = getDIByName(scans, header, channelName);
        if ~isempty(val)
            data.di.(fieldname) = val;
        end
    end

    % there's a delay between hitting the start button and actual data acquisition start
    % with timezone set to local
    clock_at_start = posixtime(datetime(header.ClockAtRunStart, 'TimeZone', 'local'));
    offset = scans.timestamp;
    acqisition_start = double(clock_at_start + offset);  

    % Metadata
    data.meta.date = DATE;
    data.meta.id = ID;
    data.meta.pipette = CELL;
    data.meta.sweep = SWEEP;
    data.meta.start = acqisition_start;
    data.meta.samples = length(data.ai.volt);
    data.meta.fs = header.AcquisitionSampleRate;
    data.meta.time = (0:data.meta.samples-1) ./ data.meta.fs;
    data.meta.isStimEnabled = header.IsStimulationEnabled;
    data.meta.fpath = fpath;
    data.meta.wavesurfer_version = header.VersionString;

end

%% HELPER FUNCTIONS
function ai = getAIByName(scans, header, channelName)
    % Returns analog channel data by WaveSurfer channel name.
    % NOTE: analogScans columns correspond to active channels only

    % Identify active analog channel names for lookup
    isActive = logical(header.IsAIChannelActive);
    activeNames = string(strtrim(header.AIChannelNames(isActive)));

    ch_idx = find(strcmpi(activeNames, channelName), 1);
    if isempty(ch_idx)
        ai = [];
    else
        ai = scans.analogScans(:, ch_idx)';
    end
end

function di = getDIByName(scans, header, channelName)
    % Returns digital channel data by WaveSurfer channel name
    % NOTE: bitget() index MUST match the DI line number in
    % header.DIChannelNames

    % Identify active digital channel names for lookup
    isActive = logical(header.IsDIChannelActive);
    activeNames = string(strtrim(header.DIChannelNames(isActive)));

    ch_idx = find(strcmpi(activeNames, channelName), 1);
    if isempty(ch_idx)
        di = [];
    else
        di = double(bitget(scans.digitalScans, ch_idx))';
    end
end
