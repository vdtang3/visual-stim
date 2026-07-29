function [data, status] = validateDataset(data, tbl)
    % VALIDATEDATASET Returns false if dataset should be excluded,
    % otherwise true.
    %   Applies exclusion rules (multi-sweep, stimulation enabled) and
    %   optionally crops traces based on the recordings QC table.
    %
    %   Crop window convention (include-driven model):
    %     include == 0          -> sweep excluded entirely
    %     new_start NaN or -1    -> natural start (no crop on that side)
    %     new_end   NaN or -1    -> natural end   (no crop on that side)
    %   Unchanged sweeps (NaN, NaN, include=1) therefore resolve to the full
    %   natural window and are left untouched.

    status = true;

    % Basic check: does the input struct have the volt field
    assert(isfield(data, 'ai') && isfield(data.ai, 'volt'), ...
        '[validateDataset] Missing data.ai.volt');

    sweep_str = string(data.meta.sweep);

    % Exclude multi-sweep / IO session naming convention
    if contains(sweep_str, "-")
        warning('[validateDataset] File has multiple sweeps. Skipping file...');
        status = false;
        data.meta.validated = status;
        return
    end

    % Exclude if stimulation is enabled
    if isfield(data.meta, 'isStimEnabled') && logical(data.meta.isStimEnabled)
        warning('[validateDataset] Stimulation is enabled. Skipping file...');
        status = false;
        data.meta.validated = status;
        return
    end

    key = string(data.meta.id) + "_" + sweep_str;

    % apply QC decisions if this sweep is present in the recordings table
    if ~isempty(tbl) && any(tbl.id == key)
        idx = find(tbl.id == key, 1, 'first');

        % exclusion is governed solely by the include flag
        if tbl.include(idx) == 0
            warning('[validateDataset] Sweep excluded by recordings table (include=0). Skipping file...');
            status = false;
            data.meta.validated = status;
            return
        end

        new_start = tbl.new_start(idx);
        new_end = tbl.new_end(idx);

        % NaN or -1 -> keep the natural start (and shift index for real values)
        if isnan(new_start) || isequal(new_start, -1)
            new_start = 1;
        else
            new_start = double(new_start) + 1;
        end

        % NaN or -1 -> keep the natural end
        if isnan(new_end) || isequal(new_end, -1)
            new_end = data.meta.samples;
        else
            new_end = double(new_end);
        end

        % clamp and validate
        new_start = max(1, new_start);
        new_end = min(data.meta.samples, new_end);

        if new_end <= new_start
            warning('[validateDataset] Invalid crop window (%d:%d). Excluding sweep...', ...
                new_start, new_end)
            status = false;
            data.meta.validated = status;
            return
        end

        % only crop when the window is narrower than the full sweep, so that
        % unchanged sweeps (full natural window) are left untouched
        if new_start > 1 || new_end < data.meta.samples
            data = cropData(data, new_start, new_end);
        end

    end

    data.meta.validated = status;
end

%% HELPER FUNCTIONS
function data = cropData(data, start_idx, end_idx)
    idx = start_idx:end_idx;

    % metadata
    data.meta.time = data.meta.time(idx);
    data.meta.samples = numel(idx);
    data.meta.start = data.meta.start + start_idx/data.meta.fs;

    % analog inputs
    data = cropSignals(data, 'ai', idx);
    data = cropSignals(data, 'di', idx);
end

function data = cropSignals(data, structName, idx)
    % Crop all input fields in data.(structName) using indices idx.

    if ~isfield(data, structName) || isempty(data.(structName))
        return
    end
    
    fields = fieldnames(data.(structName));
    if isempty(fields)
        return
    end

    last_idx = idx(end);

    for k = 1:numel(fields)
        field = fields{k};
        chan = data.(structName).(field);

        % validate if field has samples before attempting to crop
        if isempty(chan)
            continue
        end

        if ~(isnumeric(chan) || islogical(chan))
            % skip non-sampled metadata types
            continue
        end

        % skip scalars or anything that can't possibly contain samples
        if numel(chan) < last_idx && all(size(chan) < last_idx)
            continue
        end

        try
            if numel(chan) >= last_idx
                data.(structName).(field) = chan(idx);
            end
        catch ME
            warning('[validateDataset:cropSignals] Failed to crop %s.%s (%s). Leaving unchanged...', ...
                structName, field, ME.message);
        end
    end

end