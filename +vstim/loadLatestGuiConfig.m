function [cfg, filename, protocolConfigs] = loadLatestGuiConfig
%LOADLATESTGUICONFIG Load the most recently modified saved configuration.

files = dir(fullfile(vstim.configDirectory, '*.mat'));
if isempty(files)
    cfg = [];
    filename = "";
    protocolConfigs = struct;
    return
end
[~, order] = sort([files.datenum],'descend');
cfg = [];
filename = "";
protocolConfigs = struct;
for index = order
    candidate = string(fullfile(files(index).folder,files(index).name));
    try
        [cfg, protocolConfigs] = vstim.loadGuiConfig(candidate);
        filename = candidate;
        return
    catch ME
        if ~strcmp(ME.identifier,'vstim:ConfigPlatformMismatch')
            rethrow(ME)
        end
    end
end
end
