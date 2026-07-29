function data = removeSpikes(data, force)
    % Remove spikes from voltage trace
    MS = 1e-3; FS = data.meta.fs;

    if nargin == 1
        force = 0;
    end

    if force == 0
        if ~isfield(data.proc, 'volt')
            error(['Dataset has not been adjusted for drift. Please run `adjustVm` before removing ' ...
                'spikes'])
        else
            volt = data.proc.volt;
        end
    else
        volt = data.ai.volt;
    end

    [pks, spikes, half_widths, proms] = getSpikes(volt, data.meta.fs);
    
    if ~isempty(spikes)
        thresholds = getThresholds(volt);

        if numel(thresholds) ~= numel(half_widths)
            fprintf('\t[removeSpikes] Spikes & thresholds do not match.')
            fprintf(' Running helper function [matchThresholdsToPeaks].\n')
            [keepIdx, ~, ~] = matchThresholdsToPeaks(thresholds, spikes, FS, ...
                'DtMin', 0, 'DtMax', 0.002, 'ThrRefrac', 0);
            thresholds = thresholds(keepIdx);
        end

        data.spikes.th = thresholds;
        % iterate over thresholds
        for ii = 1:length(thresholds)
            % spike_start = thresholds(ii) - round(1*half_widths(ii));  % (Nestvogel & McCormick)
            spike_start = thresholds(ii) - round(0.25*MS*FS);          % from 0.25ms before threshold
            spike_end = thresholds(ii) + round(3.4*half_widths(ii));     % to 3.4X half-width after
            % spike_end = thresholds(ii) + round(3.4*MS*FS);  % to 3.4ms after (Bittner 2015)
    
            % if trace started with a spike, make first index is spike start
            if spike_start < 1, spike_start = 1; end
    
            % if trace ends with unfinished spike, make last index spike end
            if spike_end > length(volt), spike_end = length(volt); end
    
            volt(spike_start:spike_end) = NaN;
        end

        data.proc.volt_nospikes = fillmissing(volt, 'linear', 'EndValues', 'nearest');

    else
        % if there's no spikes, then volt_nospikes is just the normal trace
        data.proc.volt_nospikes = volt;
    end

    if force == 0
        data.spikes.spks = spikes;
        data.spikes.half_widths = half_widths;
        data.spikes.peaks = pks;
        data.spikes.proms = proms;
        data.spikes.info = mfilename;
    end
end
