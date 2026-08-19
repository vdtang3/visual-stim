function isBurst = detectBurstSpikes(spikeTimesSec, minSpikesInBurst, maxIntervalSec)
%DETECTBURSTSPIKES Mark spikes belonging to a run of closely spaced spikes.
%   ISBURST = DETECTBURSTSPIKES(SPIKETIMESSEC, MINSPIKESINBURST,
%   MAXINTERVALSEC) marks every spike that belongs to a run of at least
%   MINSPIKESINBURST consecutive spikes, each no more than MAXINTERVALSEC
%   after the previous one. SPIKETIMESSEC must already be sorted ascending
%   (true of any spike detector's output). A spike joins the same run as
%   its predecessor whenever their gap is within the interval threshold;
%   every spike in a long-enough run is marked, not only the run's later
%   members.
%
%   This is a secondary annotation for visual inspection (e.g. coloring a
%   raster or Vm trace), not an input to receptive-field estimation.

spikeTimesSec = spikeTimesSec(:);
isBurst = false(size(spikeTimesSec));
if numel(spikeTimesSec) < minSpikesInBurst
    return
end
startsNewRun = [true; diff(spikeTimesSec) > maxIntervalSec];
runId = cumsum(startsNewRun);
runLength = accumarray(runId, 1);
isBurst = runLength(runId) >= minSpikesInBurst;
end
