function tbl = loadCropTable()
    % LOADCROPTABLE Load the recordings QC table used to crop/exclude sweeps.
    %   Returns a table with an 'id' key (<date><pipette>_<sweep>) plus the
    %   new_start / new_end / include columns consumed by validateDataset.
    %   Returns an empty table (cropping disabled) if the file or required
    %   columns are missing.

    % load config
    config = readstruct('config/config.json');

    crop_path = fullfile(config.dropbox_path, 'recordings.csv');

    if ~isfile(crop_path)
        warning(['[preprocess:loadCropTable] Recordings file not found. ', ...
            'Skipping QC table...'])
        tbl = table();
        return
    end

    tbl = readtable(crop_path, 'TextType', 'string', 'VariableNamingRule', 'preserve');

    % Build the match key (<date><pipette>_<sweep>) from sweep_id by dropping
    % the leading "<animalID>-" prefix, so it matches the key built in
    % validateDataset: data.meta.id + "_" + sweep.
    if ~ismember('sweep_id', tbl.Properties.VariableNames)
        warning(['[preprocess:loadCropTable] recordings.csv missing expected column (sweep_id). ', ...
            'Cropping disabled.']);
        tbl = table();
        return
    end
    tbl.id = extractAfter(string(tbl.sweep_id), "-");

    % ensure required columns exist
    req = {'new_start', 'new_end', 'include'};
    if ~all(ismember(req, tbl.Properties.VariableNames))
        missing = req(~ismember(req, tbl.Properties.VariableNames));
        warning('[preprocess:loadCropTable] recordings.csv missing required columns: %s. Cropping disabled.', ...
            strjoin(missing, ', '));
        tbl = table();
    end
end