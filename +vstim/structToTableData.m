function data = structToTableData(s)
%STRUCTTOTABLEDATA Convert a scalar struct to editable GUI rows.
names = fieldnames(s);
data = cell(numel(names), 2);
for i = 1:numel(names)
    data{i,1} = names{i};
    data{i,2} = vstim.valueToText(s.(names{i}));
end
end
