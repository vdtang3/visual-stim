function message = platformTimingWarning
%PLATFORMTIMINGWARNING Report operating systems with known PTB timing risk.

message = "";
if ~ismac
    return
end

[status, versionText] = system('sw_vers -productVersion');
if status ~= 0
    return
end
parts = split(strtrim(string(versionText)),'.');
majorVersion = str2double(parts(1));
if isfinite(majorVersion) && majorVersion >= 26
    message = sprintf([ ...
        'This computer is running macOS %s. Current Psychtoolbox releases ' ...
        'identify macOS 26 as unsuitable for reliable visual-presentation ' ...
        'timing because of operating-system display stalls. Flip timing ' ...
        'will be recorded, but a Windows or Linux stimulus computer is ' ...
        'recommended for data collection.'],strtrim(versionText));
end
end
