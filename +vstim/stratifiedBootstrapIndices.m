function indices = stratifiedBootstrapIndices(trials, variableNames)
%STRATIFIEDBOOTSTRAPINDICES Resample rows within experimental conditions.

if isempty(variableNames)
    indices = randi(height(trials), height(trials), 1);
    return
end
[groups, groupIds] = findgroups(trials(:, variableNames));
indices = zeros(height(trials),1);
cursor = 1;
for g = 1:height(groupIds)
    members = find(groups == g);
    n = numel(members);
    indices(cursor:cursor+n-1) = members(randi(n,n,1));
    cursor = cursor+n;
end
end
