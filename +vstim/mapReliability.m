function reliability = mapReliability(trials, conditionNames, responseName)
%MAPRELIABILITY Correlation between condition means from alternating trials.

[groups, conditions] = findgroups(trials(:,conditionNames));
a = nan(height(conditions),1);
b = nan(height(conditions),1);
for g = 1:height(conditions)
    rows = find(groups == g);
    a(g) = mean(trials.(responseName)(rows(1:2:end)), 'omitnan');
    if numel(rows) >= 2
        b(g) = mean(trials.(responseName)(rows(2:2:end)), 'omitnan');
    end
end
valid = isfinite(a) & isfinite(b);
if sum(valid) < 3 || std(a(valid)) == 0 || std(b(valid)) == 0
    reliability = NaN;
else
    c = corrcoef(a(valid),b(valid));
    reliability = c(1,2);
end
end
