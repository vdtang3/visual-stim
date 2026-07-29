function thresholds = getThresholds(volt)
    % Uses dvdt to detect thresholds
    % Returns threshold indices
    FS = 20e3;
    mV = 1e-3;

    dv = [0 diff(volt)] * mV;  % V
    dt = (1/FS);  % s
    dvdt = dv/dt;  % V/s

    % filter dvdt to remove noise
    cutoff_freq = 1e3;
    [b, a] = butter(2, cutoff_freq / (FS/2), 'low');
    dvdt = filtfilt(b, a, dvdt);
    
    % Threshold: dV/dt exceeds 50 V/s (Bittner 2015)
    thresholds = find(dvdt >= 50);
    if ~isempty(thresholds)
        samples_between_thresholds = diff(thresholds);
        samples_between_thresholds = [1 samples_between_thresholds];

        % only count thresholds separated by more than .75 ms
        % to avoid double counting
        mask = samples_between_thresholds > 15;
        mask(1) = 1;
        thresholds = thresholds(mask);
    end

    % do one final pass to confirm our "threshold" belongs to a spike
    thresholds = thresholds(volt(thresholds) > -50);
end
