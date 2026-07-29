function data = filterVmPSPs(data)
    % Apply filter to get EPSPs
    FS = 20e3;
    MS = 1e-3;

    wlen = 10 * MS * FS + 1;
    data.proc.psp_filt = smoothdata(data.proc.volt_nospikes, 'movmean', wlen);
end
