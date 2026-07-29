function data = preprocess(data, type, force)
% PREPROCESS Apply standard preprocessing to a dataset struct.
%
%   [data, status] = preprocess(data, type, force)
%
%   Inputs
%   ------
%   data  : struct with fields like data.meta.fs, data.ai.volt, etc.
%   type  : "sweep" (default) or "agg"
%   force : logical (default false). If true, skip validateDataset checks.
%
%   Outputs
%   -------
%   data   : updated struct (may include data.proc, data.stats, etc.)
%   status : 1 if processed, 0 if excluded by validation

    % parse and validate inputs
    if nargin < 2 || isempty(type)
        type = "sweep";
    end

    if nargin < 3 || isempty(force)
        force = false;
    end

    type = string(type);
    type = validatestring(type, ["sweep", "agg"], mfilename, "type");
    force = logical(force);

    % ensure the basic required field is there
    assert(isfield(data, 'ai') && isfield(data.ai, 'volt'), ...
        '[preprocess] Missing data.ai.volt');

    % define constants
    SPIKE_THRESHOLD = -42;
    OUTLIER_THRESHOLD = -6;
    PLATEAU_THRESHOLD = -35;
    LOWPASS_CUTOFF_HZ = 5e3;
    FILTER_ORDER = 2;
    
    FS = data.meta.fs;
    NYQUIST = FS/2;

    % filter raw trace (lowpass)
    [b, a] = butter(FILTER_ORDER, LOWPASS_CUTOFF_HZ/(NYQUIST), 'low');
    data.ai.volt = filtfilt(b, a, data.ai.volt);

    % validate dataset (unless preprcessing is forced)
    crop_table = loadCropTable();
    if force
        status = 1;
        fprintf('\n\t[preprocess] Forcing preprocessing...\n')
    else
        [data, status] = validateDataset(data, crop_table);
    end

    if ~status
        data.proc = [];
        return;
    end

    % clean outliers
    data.ai.volt = cleanTraceOutliers(data.ai.volt, OUTLIER_THRESHOLD);

    % common preprocessing pipeline
    data = adjustVoltage(data, SPIKE_THRESHOLD);  % -> data.proc.volt
    data = removeSpikes(data);                    % -> data.proc.volt_nospikes
    data = filterVmPlateaus(data);                % -> data.proc.plat_filt
    data = filterVmPSPs(data);                    % -> data.proc.psp_filt

    % type-specific steps
    switch type
        case "sweep"
            data.stats.vm_mode = getVmMode(data.proc.volt_nospikes);
            data.stats.vm_mean = mean(data.proc.volt_nospikes);
            data.stats.vm_sd = std(data.proc.volt_nospikes);
            n = numel(data.proc.volt_nospikes);
            data.stats.vm_sem = data.stats.vm_sd / sqrt(max(n, 1));

            data = extractPlateausBetter(data, PLATEAU_THRESHOLD);
            % save_suffix = "_data.mat";
            
        case "agg"
            % save_suffix = "_agg_data.mat";
    end

    % save metadata
    % savepath = buildSavePath(FPATH, data, save_suffix);
    % data.meta.savepath = savepath;
    % data.proc.info = mfilename;
    % data.proc.changed = datetime('now');
    % save(savepath, '-struct', 'data');

end  % func

%% HELPER FUNCTIONS
function [clean_trace, artifact_idx] = cleanTraceOutliers(raw_trace, threshold_z)
% CLEAN_TRACE_OUTLIERS Detects and removes sharp hyperpolarizing noise
%   [clean_trace, artifact_idx] = clean_trace_outliers(raw_trace, threshold_z)
%
% Inputs:
%   raw_trace    - the raw voltage trace (vector)
%   threshold_z  - (optional) z-score threshold for outlier detection (default = -5)
%
% Outputs:
%   clean_trace  - trace with interpolated values at noise artifact points
%   artifact_idx - logical index of points considered noise artifacts

    if nargin < 2
        threshold_z = -5;  % default threshold
    end

    % Compute MAD-based z-score
    med_val = median(raw_trace);
    mad_val = mad(raw_trace, 1);
    zscore = (raw_trace - med_val) / mad_val;

    % Detect sharp negative outliers
    artifact_idx = zscore < threshold_z;

    % Expand region slightly to include neighbors (e.g., 3-sample window)
    artifact_idx = logical(movmax(artifact_idx, 3));

    % Warn if no artifacts were found
    if ~any(artifact_idx)
        fprintf('\t[preprocess:cleanTraceOutliers] No outliers detected.\n');
        clean_trace = raw_trace;
        return;
    end

    % Interpolate over artifact regions
    clean_trace = raw_trace;
    valid_idx = ~artifact_idx;
    interp_points = find(artifact_idx);

    % Use linear interpolation
    clean_trace(artifact_idx) = interp1(find(valid_idx), raw_trace(valid_idx), interp_points, 'linear', 'extrap');

    % Report
    fprintf('\t[preprocess:cleanTraceOutliers] %d points identified as outliers and interpolated.\n', sum(artifact_idx));
end

function savepath = buildSavePath(fpath, data, suffix)
    assert(isfield(data.meta, 'pipette') && isfield(data.meta, 'sweep'), ...
        '[preprocess] Missing data.meta.pipette or data.meta.sweep for save path.');
    fname = sprintf('%s_%s%s', data.meta.pipette, data.meta.sweep, suffix);
    savepath = fullfile(fpath, fname);
end
