function vm_mode = getVmMode(data)
    % Returns Vm mode
    binwidth = 0.1;  % mV
    edges = -80:binwidth:0;
    [counts, ~] = histcounts(data, edges, 'Normalization', 'percentage');
    [~, idx] = max(counts);
    vm_mode = mean(edges(idx:idx+1));
end

