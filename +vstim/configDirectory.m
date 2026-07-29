function directory = configDirectory
%CONFIGDIRECTORY Return config/gui for experiment GUI configurations.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
directory = fullfile(projectRoot, 'config', 'gui');
if ~exist(directory, 'dir')
    mkdir(directory);
end
end
