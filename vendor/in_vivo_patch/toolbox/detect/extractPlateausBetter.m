function data = extractPlateausBetter(data, event_thresh)
    % EXTRACTPLATEAUS Get plateaus from provided dataset.
    % Data must have been preprocessed before being passed to
    % EXTRACTPLATEAUS.
    % Returns a struct

    % 1. Find instances where the filtered voltage exceeds the given threshold
    % 2. If any events are found:
    % 2.1. Remove unmatched events (perhaps due to the trace starting/ending with a plateau)
    % 2.2. If two threshold crossings are too close together (given by MIN_EVENT_SEP), merge them
    % 2.3. Remove events with starts and ends too close to edges
    % 2.4. Remove events shorter than 10ms 
    % 3. Store events in struct

    FS = data.meta.fs; MS = 1e-3;

    % set windows for spike detection past edges
    PRE_EVENT_WIN = round(0.025 * FS);
    POST_EVENT_WIN = round(0.025 * FS);
    MIN_EVENT_SEP = round(0.01 * FS);  % minimum plateau separation
    
    % get suprathreshold events
    mask = data.proc.plat_filt >= event_thresh;  % anything that exceeds the threshold
    n_plateaus = numel(find(diff(mask) == 1));   % see if there's any threshold crossings

    % initialize struct
    event = struct('center', [], ...
        'rightEdge', [], ...
        'leftEdge', [], ...
        'width', [], ...
        'amp', [], ...
        'auc', [], ...
        'numSpks', [], ...
        'maxSpkRate', [], ...
        'spkAmps', [], ...
        'spkAdapt', [], ...
        'spkAdaptAmps', [] ...
        );

    if n_plateaus > 0
        % if first or last index is above threshold, then remove
        % that/those plateau(s)
        event_edges = find(diff(mask));
        % if avg of filt during first 5ms is over threshold
        if mean(data.proc.plat_filt(1:5*MS*FS)) > event_thresh
            event_edges(1) = NaN;
        end
        % if avg of filt during last 5ms is over threshold
        if mean(data.proc.plat_filt(end-(5*MS*FS):end)) > event_thresh
            event_edges(end) = NaN;
        end

        % if two plateaus are too close together, merge them
        edges_diff = diff(event_edges);
        for ii = 2:2:length(edges_diff)  % iterate over right edges
            if edges_diff(ii) <= MIN_EVENT_SEP
                mask(event_edges(ii):event_edges(ii+1)) = 1;
                event_edges(ii:ii+1) = NaN;
            end
        end

        % if any plateaus are on the edges, we may not have observed the
        % whole event, so we should remove it
        if event_edges(1) - PRE_EVENT_WIN < 1
            event_edges(1:2) = NaN;
        end

        if event_edges(end) + POST_EVENT_WIN > data.meta.samples
            event_edges(end-1:end) = NaN;
        end

        % remove flagged events and recalculate edges
        event_edges = event_edges(~isnan(event_edges));

        % event_edges = event_edges(~isnan(event_edges));
        n_plateaus = length(event_edges) ./ 2;
        data.plats = repmat(event, n_plateaus, 1);
    
        n = 0;
        for ii = 1:2:length(event_edges)
            left = event_edges(ii);
            right = event_edges(ii+1);
            width = right - left;
            % remove crossings that are shorter than 10ms
            if width < 0.01*FS
                continue
            end
            curr_volt = data.proc.volt(left - PRE_EVENT_WIN:right + POST_EVENT_WIN);
            [spike_amps, event_spikes, w, p] = findpeaks(curr_volt, 'MinPeakHeight', -20, 'MinPeakDistance', 2.5*MS*FS, 'MinPeakProminence', 5, 'WidthReference', 'halfprom', 'Annotate', 'extents');

            if numel(event_spikes) < 2
                continue
            end

            % integrate area under the curve, disregarding Vm baseline
            auc = trapz(data.meta.time(left - PRE_EVENT_WIN:right+POST_EVENT_WIN), ...
                data.proc.plat_filt(left - PRE_EVENT_WIN:right+POST_EVENT_WIN) - ...
                data.stats.vm_mode);  
            if auc < 0
                auc = NaN;
            end

            n = n + 1;
            % store event properties
            data.plats(n).width = width;
            data.plats(n).center = left + floor(width ./ 2);
            data.plats(n).leftEdge = left;
            data.plats(n).rightEdge = right;
            data.plats(n).amp = max(data.proc.plat_filt(left:right)) - data.stats.vm_mode;

            data.plats(n).auc = auc;

            % store event spike properties
            spike_rates = 1 ./ (diff(event_spikes) / FS);  % inst. spike rates
            data.plats(n).numSpks = numel(event_spikes);
            data.plats(n).maxSpkRate = max(spike_rates);
            % data.plats(n).winSpkRate = numel(event_spikes) / (event_spikes(end) - event_spikes(1)) * 20e3;
            data.plats(n).spkAmps = spike_amps - data.stats.vm_mode;
            data.plats(n).spkAdapt = min(p)/max(p);
            data.plats(n).spkAdaptAmps = min(data.plats(n).spkAmps / data.plats(n).spkAmps(1));
            data.plats(n).spikeHalfWidths = {w};
        end
        % Report
        data.plats = data.plats(1:n);
        fprintf('\t[functions:extractPlateausBetter] %d plateau(s) found.\n', n);
    else
        data.plats = repmat(event, 1, 1);
        fprintf('\t[functions:extractPlateausBetter] 0 plateau(s) found.\n');
    end % n_plateaus > 0
end
