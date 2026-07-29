function data = adjustVoltage(data, expected_spike_threshold)
% Adjust provided voltage trace by shifting the empirical threshold (and
% surrounding voltage) to match theoretical/expected th.

    volt = data.ai.volt;
    FS = data.meta.fs;
    % perc = expected_spike_threshold;

    % get dvdt and calculate threshold locations
    th = getThresholds(volt);
    if ~isempty(th) && th(1) <= 0
        th(1) = [];
    end

    all_samples = 1:data.meta.samples;  % column vector

    % Calculate the window indices
    window_length = 10 * FS;  % adjust voltage in 10 s windows
    windows = 1:window_length:length(volt);
    num_windows = length(windows);

    % Compute deviations for each window
    midpoints = zeros(1, num_windows);
    deviations = zeros(1, num_windows);
    
    % Adjust voltage in each window
    for ii = 1:num_windows
        wn_start = windows(ii);
        
        if ii == num_windows
            wn_end = length(volt);
        else
            % Ensure wn_end does not exceed the length of volt
            wn_end = min(windows(ii) + window_length - 1, length(volt));
        end

        midpoints(ii) = (wn_start + wn_end) / 2;
        
        % Find the thresholds within this window
        wn_th = th(th >= wn_start & th <= wn_end);
        
        % Calculate deviation if there are spikes in the current window
        % Otherwise, assume deviation did not change and apply it to the
        % current window
        if ~isempty(wn_th) && length(wn_th) > 3
            perc = prctile(volt(wn_th), 5);
        else
            perc = NaN;
        end

        % only correct systematic depolarization, ignore hyperpolarization
        if ~isnan(perc) && perc > expected_spike_threshold
            % deviation = expected_spike_threshold - perc;
            deviations(ii) = expected_spike_threshold - perc;
        elseif ii > 1
            % deviation = 0;
            deviations(ii) = deviations(ii-1);
        else
            % deviation = 0;
            deviations(ii) = 0;
        end
        
        % Apply the adjustment to the current window
        % volt(wn_start:wn_end) = volt(wn_start:wn_end) + deviation;
    end

    if length(deviations) > 1
        drift = interp1(midpoints, deviations, all_samples, 'linear', 'extrap');
    else
        drift = 0;
    end
    volt = volt + drift;

    if ~isempty(th)
        data.stats.th_mean = mean(volt(th));
        data.stats.th_sd = std(volt(th));
    else
        data.stats.th_mean = [];
        data.stats.th_sd = [];
    end
    
    data.proc.volt = volt;
    % Report
    fprintf('\t[adjustVoltage] Max drift detected: %.2f mV.\n', max(abs(drift)));
end
