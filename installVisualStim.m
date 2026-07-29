function installation = installVisualStim
%INSTALLVISUALSTIM First-run setup for the visual-stimulation package.
%
% Run once from MATLAB:
%
%   cd('C:\path\to\harnett_in_vivo_patch')  % Windows example
%   installVisualStim
%
% The installer:
%   1. Adds this package to the MATLAB path.
%   2. Locates and validates Psychtoolbox.
%   3. Collects display geometry and screen selection.
%   4. Collects optional Arduino TTL settings.
%   5. Activates the bundled in-vivo-patch analysis functions.
%   6. Selects a default output directory.
%   7. Saves readable settings to config/installation.json.

projectRoot = fileparts(mfilename('fullpath'));
addpath(projectRoot);

fprintf('\nVisual stimulation package setup\n');
fprintf('================================\n\n');

%% Psychtoolbox
% Reuse the installation already selected by MATLAB when possible. This is
% especially useful on shared acquisition computers where Psychtoolbox is
% centrally managed. Ask for a folder only when it is not currently visible.
existingSetupFile = which('PsychDefaultSetup');
psychtoolboxAutoDetected = ~isempty(existingSetupFile);
if psychtoolboxAutoDetected
    setupDirectory = fileparts(existingSetupFile);
    [setupParent, setupFolderName] = fileparts(setupDirectory);
    if strcmpi(setupFolderName, 'PsychBasic')
        psychtoolboxPath = setupParent;
    else
        psychtoolboxPath = setupDirectory;
    end
    fprintf('Using Psychtoolbox already on the MATLAB path: %s\n\n', ...
        psychtoolboxPath);
else
    uiwait(msgbox({ ...
        'Psychtoolbox was not found on the current MATLAB path.', ...
        'Select the Psychtoolbox installation folder.', ...
        'The selected folder must contain PsychDefaultSetup.m, either', ...
        'directly or in one of its subfolders.'}, ...
        'Select Psychtoolbox', 'modal'));
    psychtoolboxPath = uigetdir(pwd, 'Select the Psychtoolbox folder');
    if isequal(psychtoolboxPath, 0)
        error('vstim:InstallCancelled', ...
            'Installation cancelled before selecting Psychtoolbox.')
    end
end
setupMatches = dir(fullfile(psychtoolboxPath, '**', 'PsychDefaultSetup.m'));
screenMatches = dir(fullfile(psychtoolboxPath, '**', 'Screen.*'));
screenMatches = screenMatches(startsWith(string({screenMatches.name}), "Screen."));
if isempty(setupMatches) || isempty(screenMatches)
    error('vstim:PsychtoolboxNotFound', ...
        ['The selected folder does not provide PsychDefaultSetup and Screen. ' ...
         'Select the top-level Psychtoolbox folder.'])
end
vstim.addPsychtoolboxPath(psychtoolboxPath);

% A source checkout can contain PsychDefaultSetup and Screen while still
% missing platform-specific runtime or licensing components. Confirm that
% the Screen MEX file can actually load before collecting experiment
% settings.
try
    AssertOpenGL;
catch firstOpenGLError
    setupFile = dir(fullfile(psychtoolboxPath, '**', 'SetupPsychtoolbox.m'));
    if isempty(setupFile)
        error('vstim:PsychtoolboxIncomplete', ...
            ['Psychtoolbox files were found, but Screen cannot load:\n\n%s\n\n' ...
             'Install a complete Psychtoolbox release and rerun this installer.'], ...
            firstOpenGLError.message)
    end

    choice = questdlg({ ...
        'Psychtoolbox is present but has not completed its platform setup.', ...
        'Its Screen module cannot currently load.', ...
        ' ', ...
        'Run the official SetupPsychtoolbox routine now?', ...
        'This may open Psychtoolbox license and dependency prompts.'}, ...
        'Complete Psychtoolbox setup', 'Run setup', 'Cancel', 'Run setup');
    if ~strcmp(choice, 'Run setup')
        error('vstim:PsychtoolboxIncomplete', ...
            ['Psychtoolbox Screen cannot load. Run SetupPsychtoolbox from ' ...
             'the selected Psychtoolbox folder, then rerun installVisualStim.'])
    end

    setupDirectory = setupFile(1).folder;
    previousDirectory = pwd;
    directoryCleanup = onCleanup(@() cd(previousDirectory));
    cd(setupDirectory);
    SetupPsychtoolbox;
    clear directoryCleanup
    cd(previousDirectory);
    vstim.addPsychtoolboxPath(psychtoolboxPath);

    try
        AssertOpenGL;
    catch secondOpenGLError
        error('vstim:PsychtoolboxSetupFailed', ...
            ['Psychtoolbox setup completed but Screen still cannot load:\n\n%s\n\n' ...
             'Resolve this Psychtoolbox installation error before running stimuli.'], ...
            secondOpenGLError.message)
    end
end

% Escape is the preferred safety abort key. On macOS, keyboard failure is
% normally a correctable Input Monitoring permission problem and remains
% fatal. A failed Windows preflight is silently treated as inconclusive
% because the keyboard often works once the Psychtoolbox window is open.
try
    [keyboardAvailable, keyboardDiagnostic] = ...
        vstim.checkKeyboardAccess;
catch keyboardError
    uiwait(errordlg(keyboardError.message, ...
        'Keyboard permission required', 'modal'));
    rethrow(keyboardError)
end

%% Display configuration
screenNumber = NaN; % NaN means choose the highest-numbered screen at run time.
resolutionPx = [1920 1080];
try
    availableScreens = Screen('Screens');
    screenLabels = ["Automatic (highest-numbered screen)", ...
        "Screen " + string(availableScreens)];
    [selection, accepted] = listdlg('PromptString', ...
        'Select the default stimulus display:', ...
        'SelectionMode', 'single', 'ListString', cellstr(screenLabels), ...
        'InitialValue', 1, 'Name', 'Stimulus display');
    if ~accepted
        error('vstim:InstallCancelled', 'Installation cancelled.')
    end
    if selection > 1
        screenNumber = availableScreens(selection-1);
    end
    if isnan(screenNumber)
        geometryScreen = max(availableScreens);
    else
        geometryScreen = screenNumber;
    end
    screenRect = Screen('Rect', geometryScreen);
    resolutionPx = [RectWidth(screenRect), RectHeight(screenRect)];
catch ME
    if strcmp(ME.identifier, 'vstim:InstallCancelled')
        rethrow(ME)
    end
    warning('vstim:ScreenEnumerationFailed', ...
        'Could not enumerate screens. Automatic selection will be used.')
end

defaults = {'52.7', '29.6', '9', '0', '0'};
answers = inputdlg({ ...
    'Monitor width (cm):', ...
    'Monitor height (cm):', ...
    'Straight-line distance from eye to monitor center (cm):', ...
    'Monitor-center horizontal offset from head (cm; + animal-right):', ...
    'Monitor-center vertical offset from head (cm; + above head):'}, ...
    'Display geometry', [1 48], defaults);
if isempty(answers)
    error('vstim:InstallCancelled', 'Installation cancelled.')
end

monitorWidthCm = parsePositiveScalar(answers{1}, 'Monitor width');
monitorHeightCm = parsePositiveScalar(answers{2}, 'Monitor height');
viewingDistanceCm = parsePositiveScalar(answers{3}, 'Viewing distance');
monitorCenterXcm = parseFiniteScalar(answers{4}, 'Horizontal offset');
monitorCenterYcm = parseFiniteScalar(answers{5}, 'Vertical offset');

geometryCfg = vstim.defaultConfig("Moving bars");
geometryCfg.display.monitorWidthCm = monitorWidthCm;
geometryCfg.display.monitorHeightCm = monitorHeightCm;
geometryCfg.display.viewingDistanceCm = viewingDistanceCm;
geometryCfg.display.monitorCenterXcm = monitorCenterXcm;
geometryCfg.display.monitorCenterYcm = monitorCenterYcm;
geometryCfg = vstim.normalizeDisplayGeometry(geometryCfg);
azimuthLimitsDeg = geometryCfg.display.azimuthLimitsDeg;
elevationLimitsDeg = geometryCfg.display.elevationLimitsDeg;
monitorCenterAzimuthDeg = geometryCfg.display.monitorCenterAzimuthDeg;
monitorCenterElevationDeg = geometryCfg.display.monitorCenterElevationDeg;

skipAnswer = questdlg( ...
    ['Keep Psychtoolbox synchronization tests enabled? ' ...
     'This is strongly recommended for experiments.'], ...
    'Timing tests', 'Keep enabled', 'Skip for testing', 'Keep enabled');
skipSyncTests = strcmp(skipAnswer, 'Skip for testing');

warpAnswer = questdlg({ ...
    'Apply a Psychtoolbox geometry-correction warp?', ...
    ' ', ...
    'The default is constant-pixel presentation with no warp.', ...
    'Enabling correction requires an existing Psychtoolbox calibration', ...
    'MAT file generated for this monitor and viewing geometry.'}, ...
    'Geometry correction', 'No warp (default)', ...
    'Select calibration file', 'No warp (default)');
geometryCorrectionEnabled = strcmp(warpAnswer, 'Select calibration file');
geometryCalibrationFile = "";
if geometryCorrectionEnabled
    [calibrationName, calibrationPath] = uigetfile('*.mat', ...
        'Select Psychtoolbox geometry-correction calibration');
    if isequal(calibrationName, 0)
        error('vstim:InstallCancelled', ...
            'Installation cancelled before selecting a calibration file.')
    end
    geometryCalibrationFile = string(fullfile(calibrationPath, calibrationName));
end

%% Optional Arduino TTL
ttlAnswer = questdlg('Enable Arduino TTL output by default?', ...
    'Arduino TTL', 'Enable', 'Disable', 'Enable');
ttlEnabled = strcmp(ttlAnswer, 'Enable');
serialPort = "COM9";
baudRate = 128000;

if ttlEnabled
    ports = string(serialportlist("all"));
    portChoices = [ports(:); "Enter another port"];
    if isempty(ports)
        portChoices = "Enter another port";
    end
    [selection, accepted] = listdlg('PromptString', ...
        'Select the Arduino serial port:', 'SelectionMode', 'single', ...
        'ListString', cellstr(portChoices), 'InitialValue', 1, ...
        'Name', 'Arduino serial port');
    if ~accepted
        error('vstim:InstallCancelled', 'Installation cancelled.')
    end
    if selection <= numel(ports)
        serialPort = ports(selection);
    else
        portAnswer = inputdlg({'Serial port:', 'Baud rate:'}, ...
            'Arduino connection', [1 40], {'COM9', '128000'});
        if isempty(portAnswer)
            error('vstim:InstallCancelled', 'Installation cancelled.')
        end
        serialPort = string(strtrim(portAnswer{1}));
        baudRate = parsePositiveScalar(portAnswer{2}, 'Baud rate');
    end
end

%% Bundled in-vivo-patch analysis functions
vendorRoot = fullfile(projectRoot,'vendor','in_vivo_patch');
requiredVendorFiles = {
    fullfile(vendorRoot,'toolbox','io','loadws.m')
    fullfile(vendorRoot,'toolbox','io','ws','loadDataFile.m')
    fullfile(vendorRoot,'toolbox','preprocess','preprocess.m')};
if ~all(cellfun(@isfile,requiredVendorFiles))
    error('vstim:BundledAnalysisMissing', ...
        'The package-local in-vivo-patch analysis files are incomplete.')
end
addpath(genpath(vendorRoot));

%% Output directory
uiwait(msgbox({ ...
    'Select where stimulus-run log files will be saved.', ...
    'Each log contains the exact stimulus sequence, presentation', ...
    'timestamps, display geometry, TTL settings, and run status.', ...
    ' ', ...
    'Usually this should be the same session/date folder that contains', ...
    'the corresponding WaveSurfer recordings. You can change the output', ...
    'folder later in the GUI under the Session tab.'}, ...
    'Stimulus log output folder', 'modal'));
outputDirectory = uigetdir(projectRoot, ...
    'Select the default stimulus-run output folder');
if isequal(outputDirectory, 0)
    error('vstim:InstallCancelled', 'Installation cancelled.')
end

%% Save installation settings
installation.schemaVersion = "1.0.0";
installation.projectRoot = string(projectRoot);
installation.platform = string(computer);
installation.matlabRelease = string(version('-release'));
installation.psychtoolboxPath = string(psychtoolboxPath);
installation.psychtoolboxAutoDetected = psychtoolboxAutoDetected;
installation.display.screenNumber = screenNumber;
installation.display.monitorWidthCm = monitorWidthCm;
installation.display.monitorHeightCm = monitorHeightCm;
installation.display.resolutionPx = resolutionPx;
installation.display.viewingDistanceCm = viewingDistanceCm;
installation.display.monitorCenterXcm = monitorCenterXcm;
installation.display.monitorCenterYcm = monitorCenterYcm;
installation.display.monitorCenterAzimuthDeg = monitorCenterAzimuthDeg;
installation.display.monitorCenterElevationDeg = monitorCenterElevationDeg;
installation.display.monitorHorizontalDistanceCm = ...
    geometryCfg.display.monitorHorizontalDistanceCm;
installation.display.monitorForwardDistanceCm = ...
    geometryCfg.display.monitorForwardDistanceCm;
installation.display.azimuthLimitsDeg = azimuthLimitsDeg;
installation.display.elevationLimitsDeg = elevationLimitsDeg;
installation.display.skipSyncTests = skipSyncTests;
installation.display.geometryCorrectionEnabled = geometryCorrectionEnabled;
installation.display.geometryCalibrationFile = geometryCalibrationFile;
installation.keyboard.preflightSucceeded = ...
    keyboardAvailable && strlength(keyboardDiagnostic) == 0;
installation.keyboard.runtimeRetryEnabled = ispc;
installation.keyboard.diagnostic = keyboardDiagnostic;
installation.sync.enabled = ttlEnabled;
installation.sync.port = serialPort;
installation.sync.baudRate = baudRate;
installation.session.outputDirectory = string(outputDirectory);
installation.installedAt = string(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));

configDirectory = fullfile(projectRoot, 'config');
if ~exist(configDirectory, 'dir')
    mkdir(configDirectory);
end
configFile = fullfile(configDirectory, 'installation.json');
fid = fopen(configFile, 'w');
if fid < 0
    error('vstim:ConfigWriteFailed', ...
        'Could not write installation configuration to %s.', configFile)
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(installation, PrettyPrint=true));
clear cleanup

% Persist package and Psychtoolbox paths when MATLAB permits it. The JSON
% configuration remains valid even if savepath is unavailable.
addpath(projectRoot);
vstim.addPsychtoolboxPath(psychtoolboxPath);
addpath(genpath(vendorRoot));
addpath(projectRoot,'-begin');
pathStatus = savepath;
if pathStatus ~= 0
    warning('vstim:PathNotSaved', ...
        ['MATLAB could not persist its search path. Run setupVisualStim ' ...
         'at the beginning of future MATLAB sessions.'])
end

fprintf('Psychtoolbox: %s\n', psychtoolboxPath);
fprintf('Bundled in-vivo-patch code: %s\n', vendorRoot);
fprintf('Configuration: %s\n', configFile);
fprintf('Output folder: %s\n', outputDirectory);
fprintf('TTL enabled by default: %s\n\n', string(ttlEnabled));
fprintf('Monitor azimuth limits: [%.2f %.2f] deg\n', azimuthLimitsDeg);
fprintf('Monitor elevation limits: [%.2f %.2f] deg\n\n', elevationLimitsDeg);

msgbox({ ...
    'Visual stimulation setup is complete.', ...
    'Start the application with:', ...
    'VisualStimGUI', ...
    ' ', ...
    'Start quick RF analysis with:', ...
    'VisualAnalysisGUI'}, 'Installation complete', 'modal');
end

function value = parsePositiveScalar(text, label)
value = str2double(text);
if ~isfinite(value) || value <= 0
    error('vstim:InvalidInstallationValue', ...
        '%s must be a positive number.', label)
end
end

function value = parseFiniteScalar(text, label)
value = str2double(text);
if ~isfinite(value)
    error('vstim:InvalidInstallationValue', ...
        '%s must be a finite number.', label)
end
end
