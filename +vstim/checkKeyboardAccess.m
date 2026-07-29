function [available, diagnostic] = checkKeyboardAccess
%CHECKKEYBOARDACCESS Test whether Psychtoolbox can read the Escape key.
% On macOS, MATLAB requires Privacy & Security > Input Monitoring access.
% A failed Windows preflight is treated as inconclusive because keyboard
% queues may still work after the stimulus window opens.
% Clear KbCheck first because a failed PsychHID initialization can leave its
% persistent variables in an invalid partial state.

available = false;
diagnostic = "";
clear KbCheck
try
    KbCheck;
    available = true;
catch ME
    diagnostic = string(ME.message);
    if IsOSX
        error('vstim:KeyboardPermissionDenied', ...
            ['Psychtoolbox cannot access the keyboard.\n\n' ...
             'Open macOS System Settings > Privacy & Security > Input ' ...
             'Monitoring, enable MATLAB, then quit and restart MATLAB.\n\n' ...
             'If MATLAB is already enabled, turn it off and on again, then ' ...
             'restart MATLAB.\n\nPsychtoolbox reported:\n%s'], ME.message)
    end
    if ~ispc
        error('vstim:KeyboardUnavailable', ...
            'Psychtoolbox cannot access the keyboard:\n\n%s', ME.message)
    end
    % Continue on Windows and let runProtocol retry the asynchronous queue
    % and then KbCheck after the Psychtoolbox window has initialized.
    available = true;
end
clear KbCheck
end
