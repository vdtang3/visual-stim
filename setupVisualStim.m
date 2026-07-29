function installation = setupVisualStim
%SETUPVISUALSTIM Restore saved package and Psychtoolbox paths.
% Use this at the start of a MATLAB session only if installVisualStim could
% not persist the MATLAB search path.

projectRoot = fileparts(mfilename('fullpath'));
addpath(projectRoot);
installation = vstim.loadInstallationConfig(projectRoot);
if isempty(fieldnames(installation))
    error('vstim:NotInstalled', ...
        'No installation configuration found. Run installVisualStim first.')
end
addpath(genpath(char(installation.psychtoolboxPath)));
vendorRoot = fullfile(projectRoot,'vendor','in_vivo_patch');
addpath(genpath(vendorRoot));
addpath(projectRoot,'-begin');
end
