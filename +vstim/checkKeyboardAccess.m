function checkKeyboardAccess
%CHECKKEYBOARDACCESS Verify that Psychtoolbox can read the Escape key.
% On macOS, MATLAB requires Privacy & Security > Input Monitoring access.
% Clear KbCheck first because a failed PsychHID initialization can leave its
% persistent variables in an invalid partial state.

clear KbCheck
try
    KbCheck;
catch ME
    if IsOSX
        error('vstim:KeyboardPermissionDenied', ...
            ['Psychtoolbox cannot access the keyboard.\n\n' ...
             'Open macOS System Settings > Privacy & Security > Input ' ...
             'Monitoring, enable MATLAB, then quit and restart MATLAB.\n\n' ...
             'If MATLAB is already enabled, turn it off and on again, then ' ...
             'restart MATLAB.\n\nPsychtoolbox reported:\n%s'], ME.message)
    end
    error('vstim:KeyboardUnavailable', ...
        'Psychtoolbox cannot access the keyboard:\n\n%s', ME.message)
end
clear KbCheck
end
