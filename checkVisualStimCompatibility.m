function report = checkVisualStimCompatibility
%CHECKVISUALSTIMCOMPATIBILITY Check requirements for both MATLAB GUIs.
% This is read-only and safe to run before connecting the Arduino or monitor.

component = strings(0,1);
status = strings(0,1);
detail = strings(0,1);
release = string(version('-release'));
[year,half] = parseRelease(release);
releaseOK = year>2023 || (year==2023 && half=="b");
addCheck("MATLAB release",releaseOK,"FAIL", ...
    "Running "+release+"; MATLAB R2023b or newer is supported.");

required = ["uifigure","uigridlayout","serialport","jsonencode", ...
    "h5read","h5create"];
for name = required
    addCheck("MATLAB function: "+name,~isempty(which(name)),"FAIL", ...
        "Required by the GUIs or installer.");
end

projectRoot = fileparts(mfilename('fullpath'));
installation = vstim.loadInstallationConfig(projectRoot);
addCheck("Installation configuration",~isempty(fieldnames(installation)), ...
    "WARN","Run installVisualStim if this is missing.");
addCheck("PsychDefaultSetup",~isempty(which('PsychDefaultSetup')),"FAIL", ...
    "Psychtoolbox must be selected with installVisualStim.");
addCheck("Psychtoolbox Screen",~isempty(which('Screen')),"FAIL", ...
    "A platform-compatible Psychtoolbox Screen MEX is required.");
addCheck("Psychtoolbox keyboard",~isempty(which('KbCheck')),"FAIL", ...
    "KbCheck supplies the Escape safety control.");
vendorRoot = fullfile(projectRoot,'vendor','in_vivo_patch');
addpath(genpath(vendorRoot));
addCheck("Bundled WaveSurfer loadws",~isempty(which('loadws')),"FAIL", ...
    "Copied into vendor/in_vivo_patch.");
addCheck("Bundled WaveSurfer raw loader", ...
    ~isempty(which('loadDataFile')),"FAIL", ...
    "Copied into vendor/in_vivo_patch.");
addCheck("Bundled standard preprocessing", ...
    ~isempty(which('preprocess')),"FAIL", ...
    "Copied into vendor/in_vivo_patch.");

if ispc
    platformDetail = "Windows "+string(computer('arch'));
    windowsMex = ~isempty(which('scaledDoubleAnalogDataFromRawMex'));
    if windowsMex
        mexDetail = "Windows WaveSurfer scaling MEX found.";
    else
        mexDetail = ...
            "Windows scaling MEX not found; portable MATLAB fallback will be used.";
    end
    addCheck("Windows platform",true,"FAIL",platformDetail);
    addCheck("WaveSurfer analog scaling",true,"WARN",mexDetail);
else
    addCheck("Host platform",true,"FAIL", ...
        string(computer)+" (Windows should run this check separately).");
end

if ~isempty(fieldnames(installation)) && ...
        isfield(installation,'sync') && installation.sync.enabled
    availablePorts = string(serialportlist("all"));
    configuredPort = string(installation.sync.port);
    portFound = any(strcmpi(availablePorts,configuredPort));
    addCheck("Configured Arduino port",portFound,"WARN", ...
        "Configured: "+configuredPort+"; available: "+ ...
        strjoin(availablePorts,", "));
else
    addCheck("Arduino TTL","", "WARN", ...
        "TTL is disabled or not configured; dry runs remain available.");
end

report = table(component,status,detail);
disp(report);
if any(status=="FAIL")
    warning('vstim:CompatibilityCheckFailed', ...
        'One or more required compatibility checks failed.')
end

    function addCheck(name,passed,failureStatus,message)
        component(end+1,1) = name;
        if islogical(passed) && isscalar(passed) && passed
            status(end+1,1) = "PASS";
        else
            status(end+1,1) = failureStatus;
        end
        detail(end+1,1) = message;
    end
end

function [year,half] = parseRelease(release)
tokens = regexp(char(release),'(20\d{2})([ab])','tokens','once');
if isempty(tokens)
    year = 0;
    half = "";
else
    year = str2double(tokens{1});
    half = string(tokens{2});
end
end
