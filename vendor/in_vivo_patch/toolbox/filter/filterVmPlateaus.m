function data = filterVmPlateaus(data)
    % Filter voltage to find plateaus
    FS = data.meta.fs;
    MS = 1e-3;

    if ~isfield(data.proc, 'volt_nospikes')
        error(['Dataset has not been adjusted for drift. Please run `adjustVoltage` before removing ' ...
            'spikes'])
    else
        volt_nospikes = data.proc.volt_nospikes;
    end

    % Bittner 2015 method
    wlen = 20 * MS * FS + 1;
    data.proc.plat_filt = smoothdata(volt_nospikes, 'movmean', wlen);

end
