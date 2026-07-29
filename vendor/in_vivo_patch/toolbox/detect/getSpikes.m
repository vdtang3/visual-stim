function [pks, spikes, half_widths, proms] = getSpikes(volt, FS)
    MS = 1e-3;
    
    [pks, spikes, half_widths, proms] = findpeaks(volt, 'MinPeakHeight', -20, ...
        'MinPeakProminence', 20, 'MinPeakDistance', 10, 'MinPeakWidth', 0.5*MS*FS);
end
