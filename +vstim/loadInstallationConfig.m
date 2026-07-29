function installation = loadInstallationConfig(projectRoot)
%LOADINSTALLATIONCONFIG Read config/installation.json when it exists.

if nargin < 1
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end
configFile = fullfile(projectRoot, 'config', 'installation.json');
if ~isfile(configFile)
    installation = struct();
    return
end

installation = jsondecode(fileread(configFile));
if isfield(installation,'platform') && ...
        ~strcmpi(string(installation.platform),string(computer))
    warning('vstim:InstallationPlatformMismatch', ...
        ['The saved installation belongs to %s, but MATLAB is running on ' ...
         '%s. Run installVisualStim on this machine.'], ...
        string(installation.platform),string(computer))
    installation = struct();
    return
elseif ispc && ~isfield(installation,'platform') && ...
        isfield(installation,'psychtoolboxPath') && ...
        startsWith(string(installation.psychtoolboxPath),"/")
    warning('vstim:InstallationPlatformMismatch', ...
        ['The untagged installation contains Unix paths. Run ' ...
         'installVisualStim on this Windows machine.'])
    installation = struct();
    return
end
if isfield(installation, 'psychtoolboxPath') && ...
        isfolder(installation.psychtoolboxPath)
    % Reapply this even when Psychtoolbox is already visible: older Windows
    % installations require MatlabWindowsFilesR2007a to precede PsychBasic.
    vstim.addPsychtoolboxPath(installation.psychtoolboxPath);
end
vendorRoot = fullfile(projectRoot,'vendor','in_vivo_patch');
if isfolder(vendorRoot)
    addpath(genpath(vendorRoot));
end
addpath(projectRoot,'-begin');
end
