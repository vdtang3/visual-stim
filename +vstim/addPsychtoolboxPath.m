function mexDirectories = addPsychtoolboxPath(psychtoolboxPath)
%ADDPSYCHTOOLBOXPATH Add Psychtoolbox with platform MEX folders first.
% Older Windows Psychtoolbox releases keep Screen.mexw64, GetSecs.mexw64,
% WaitSecs.mexw64, and PsychHID.mexw64 in MatlabWindowsFilesR2007a while
% their documentation placeholders live in PsychBasic. A plain genpath
% can put the placeholders first and make an otherwise valid MEX appear
% missing. This helper restores the required precedence.

psychtoolboxPath = char(string(psychtoolboxPath));
if ~isfolder(psychtoolboxPath)
    error('vstim:PsychtoolboxFolderMissing', ...
        'Psychtoolbox folder does not exist: %s', psychtoolboxPath)
end

persistent cachedRoot cachedExtension cachedGeneratedPath ...
    cachedMexDirectories
currentExtension = "." + string(mexext);
if ~isempty(cachedRoot) && ...
        strcmp(cachedRoot, psychtoolboxPath) && ...
        cachedExtension == currentExtension && ...
        requiredMexFilesAlreadySelected(psychtoolboxPath, currentExtension)
    % defaultConfig calls loadInstallationConfig frequently while the GUI is
    % edited. Avoid rebuilding MATLAB's full toolbox path and rehashing the
    % toolbox cache once the correct platform MEX files are already active.
    mexDirectories = cachedMexDirectories;
    return
end
if isempty(cachedRoot) || ...
        ~strcmp(cachedRoot, psychtoolboxPath) || ...
        cachedExtension ~= currentExtension
    cachedRoot = psychtoolboxPath;
    cachedExtension = currentExtension;
    cachedGeneratedPath = genpath(psychtoolboxPath);
    requiredMexNames = ["Screen", "GetSecs", "WaitSecs", "PsychHID"];
    cachedMexDirectories = strings(0,1);
    for name = requiredMexNames
        matches = dir(fullfile(psychtoolboxPath, '**', ...
            char(name + currentExtension)));
        if isempty(matches)
            continue
        end
        folders = string({matches.folder})';
        % Do not select Octave binaries when configuring MATLAB.
        folders = folders(~contains(lower(folders), "octave"));
        cachedMexDirectories = [cachedMexDirectories; folders]; %#ok<AGROW>
    end
    cachedMexDirectories = unique(cachedMexDirectories, 'stable');
end
mexDirectories = cachedMexDirectories;

addpath(cachedGeneratedPath, '-begin');

% addpath(...,'-begin') promotes each directory, so iterate backwards to
% preserve the discovery order when more than one MEX directory is needed.
for i = numel(mexDirectories):-1:1
    addpath(char(mexDirectories(i)), '-begin');
end
rehash toolboxcache
end

function selected = requiredMexFilesAlreadySelected(root, extension)
requiredNames = ["Screen", "GetSecs", "WaitSecs"];
selected = true;
rootPrefix = string(root) + filesep;
for name = requiredNames
    activeFile = string(which(char(name)));
    if strlength(activeFile) == 0 || ...
            ~endsWith(activeFile, extension, 'IgnoreCase', true) || ...
            ~startsWith(activeFile, rootPrefix, 'IgnoreCase', ispc)
        selected = false;
        return
    end
end
end
