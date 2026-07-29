function [keepIdx, noiseIdx, pairs] = matchThresholdsToPeaks(thresholds, peakLocs, Fs, varargin)
%MATCHTHRESHOLDSTOPEAKS  One-to-one matching of dv/dt thresholds to spike peaks.
%
% Inputs
%   thresholds : vector of sample indices where dv/dt crossed the criterion
%   peakLocs   : vector of sample indices of spike peaks (from findpeaks)
%   Fs         : sampling rate in Hz
%
% Name-Value pairs (all optional)
%   'DtMin'    : minimum allowed time from threshold to its peak (sec) [default 0]
%   'DtMax'    : maximum allowed time from threshold to its peak (sec) [default 0.002]
%   'ThrRefrac': collapse near-duplicate thresholds closer than this (sec) before matching [default 0]
%
% Outputs
%   keepIdx    : indices (into thresholds) of thresholds that were matched (kept)
%   noiseIdx   : indices (into thresholds) of thresholds that were rejected (noise)
%   pairs      : Nx2 array; rows are [threshold_index_in_thresholds, peak_index_in_peakLocs]
%
% Notes
%   - If multiple thresholds fall before the same peak within [DtMin, DtMax],
%     the one with the smallest (peak - threshold) is kept; others are noise.
%   - Any threshold without a valid future peak within the window is marked noise.

% ---- parse inputs
p = inputParser;
p.addParameter('DtMin', 0, @(x)isnumeric(x)&&isscalar(x));      % sec
p.addParameter('DtMax', 0.002, @(x)isnumeric(x)&&isscalar(x));  % sec (2 ms default)
p.addParameter('ThrRefrac', 0, @(x)isnumeric(x)&&isscalar(x));  % sec
p.parse(varargin{:});
DtMin = p.Results.DtMin;
DtMax = p.Results.DtMax;
ThrRefrac = p.Results.ThrRefrac;

if isempty(thresholds) || isempty(peakLocs)
    keepIdx = [];
    noiseIdx = (1:numel(thresholds)).';
    pairs = zeros(0,2);
    return
end

% ensure column vectors
thresholds = thresholds(:);
peakLocs   = peakLocs(:);

% optional de-duplication of extremely close threshold hits
if ThrRefrac > 0
    thrGap = round(ThrRefrac * Fs);
    mask = true(size(thresholds));
    last = -inf;
    for i = 1:numel(thresholds)
        if thresholds(i) - last < thrGap
            mask(i) = false; % drop near-duplicate; keep earlier one
        else
            last = thresholds(i);
        end
    end
    thrIdxMap = find(mask);        % map from "deduped" -> original threshold indices
    thr = thresholds(mask);
else
    thrIdxMap = (1:numel(thresholds)).';
    thr = thresholds;
end

pk = peakLocs;

% sort (keeps mapping back to original indices)
[thrSorted, iThr] = sort(thr, 'ascend');
[pkSorted,  iPk]  = sort(pk,  'ascend');

nT = numel(thrSorted);
nP = numel(pkSorted);
thrToPk   = zeros(nT,1);     % index into pkSorted (0 => no candidate)
thrToDt   = inf(nT,1);       % dt in samples to candidate peak
minSamp   = max(0, round(DtMin*Fs));
maxSamp   = round(DtMax*Fs);

% pass 1: for each threshold, find the first valid *future* peak within window
j = 1; % pointer into pkSorted
for it = 1:nT
    t = thrSorted(it);
    % advance j so pkSorted(j) is the first peak not earlier than t
    while j <= nP && pkSorted(j) < t
        j = j + 1;
    end
    if j > nP
        break
    end
    % check if this first future peak is within [DtMin, DtMax]
    dt = pkSorted(j) - t;
    if dt >= minSamp && dt <= maxSamp
        thrToPk(it) = j;
        thrToDt(it) = dt;
    else
        % maybe a slightly later peak still qualifies (rare but safe to check)
        jj = j+1;
        while jj <= nP
            dt2 = pkSorted(jj) - t;
            if dt2 > maxSamp, break; end
            if dt2 >= minSamp
                thrToPk(it) = jj;
                thrToDt(it) = dt2;
                break
            end
            jj = jj + 1;
        end
    end
end

% pass 2: one-to-one resolve — keep only the threshold with smallest dt per peak
pkBestThr = zeros(nP,1);      % store index (into thrSorted) of winning threshold for each peak
pkBestDt  = inf(nP,1);
for it = 1:nT
    jp = thrToPk(it);
    if jp == 0, continue; end
    if thrToDt(it) < pkBestDt(jp)
        pkBestDt(jp)  = thrToDt(it);
        pkBestThr(jp) = it;
    end
end

% winners: thresholds that are pkBestThr for some peak
isWinner = false(nT,1);
isWinner(pkBestThr(pkBestThr>0)) = true;

% map winners/noise back to original threshold indices
keep_dedup_idx  = iThr(isWinner);               % indices into thr (maybe deduped)
noise_dedup_idx = setdiff((1:nT).', keep_dedup_idx);

keepIdx  = thrIdxMap(keep_dedup_idx);           % indices into original thresholds
noiseIdx = thrIdxMap(noise_dedup_idx);

% build output pairs [threshold_index_in_thresholds, peak_index_in_peakLocs]
% for each peak that has a winner
pairs = zeros(nnz(isWinner), 2);
cnt = 0;
for jp = 1:nP
    it = pkBestThr(jp);
    if it == 0, continue; end
    cnt = cnt + 1;
    thr_orig_idx = thrIdxMap(iThr(it));
    pk_orig_idx  = iPk(jp);
    pairs(cnt,:) = [thr_orig_idx, pk_orig_idx];
end
end
