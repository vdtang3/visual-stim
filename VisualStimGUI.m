function VisualStimGUI
%VISUALSTIMGUI Configure and run receptive-field mapping protocols.
% This is intentionally a regular MATLAB function rather than an App
% Designer binary so that all controls and callbacks remain readable.

protocolNames = ["Moving bars", "Flashed bars", "Sparse noise", ...
    "Fast Gabor tiling", "Targeted Gabor grid", ...
    "Gabor + inverse stimuli"];
cfg = vstim.defaultConfig(protocolNames(1));
[latestConfig, latestConfigFile] = vstim.loadLatestGuiConfig;
if ~isempty(latestConfig)
    cfg = latestConfig;
end

fig = uifigure('Name', 'In vivo patch visual stimulation', ...
    'Position', [80 80 1220 760], 'Color', [0.96 0.96 0.96], ...
    'CloseRequestFcn', @closeGUI);
main = uigridlayout(fig, [3 2]);
main.RowHeight = {54, '1x', 42};
main.ColumnWidth = {470, '1x'};
main.Padding = [12 12 12 12];
main.RowSpacing = 8;
main.ColumnSpacing = 12;

header = uigridlayout(main, [1 6]);
header.Layout.Row = 1;
header.Layout.Column = [1 2];
header.ColumnWidth = {75, 210, 125, 105, 190, '1x'};
uilabel(header, 'Text', 'Protocol', 'FontWeight', 'bold');
protocolDropDown = uidropdown(header, 'Items', cellstr(protocolNames), ...
    'Value', char(cfg.protocol), 'ValueChangedFcn', @protocolChanged);
previewButton = uibutton(header, 'Text', 'Select target region', ...
    'ButtonPushedFcn', @selectRegionPressed);
fullDisplayButton = uibutton(header, 'Text', 'Use full display', ...
    'ButtonPushedFcn', @fullDisplayPressed);
summaryLabel = uilabel(header, 'Text', '', 'HorizontalAlignment', 'right');
durationLabel = uilabel(header, 'Text', '', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right');

tabs = uitabgroup(main);
tabs.Layout.Row = 2;
tabs.Layout.Column = 1;
stimTab = uitab(tabs, 'Title', 'Stimulus');
displayTab = uitab(tabs, 'Title', 'Display');
syncTab = uitab(tabs, 'Title', 'TTL / Arduino');
sessionTab = uitab(tabs, 'Title', 'Session');

stimTable = makeEditor(stimTab);
displayTable = makeEditor(displayTab);
syncTable = makeEditor(syncTab);
sessionTable = makeEditor(sessionTab);

right = uigridlayout(main, [2 1]);
right.Layout.Row = 2;
right.Layout.Column = 2;
right.RowHeight = {'1x', 118};
previewAxes = uiaxes(right);
previewAxes.Layout.Row = 1;
previewAxes.Toolbar.Visible = 'on';

helpBox = uitextarea(right, 'Editable', 'off', ...
    'Value', protocolHelp(cfg.protocol), 'FontName', 'Menlo');
helpBox.Layout.Row = 2;

footer = uigridlayout(main, [1 6]);
footer.Layout.Row = 3;
footer.Layout.Column = [1 2];
footer.ColumnWidth = {120, 140, 140, '1x', 150, 150};
resetButton = uibutton(footer, 'Text', 'Reset defaults', ...
    'ButtonPushedFcn', @resetPressed);
saveButton = uibutton(footer, 'Text', 'Save configuration', ...
    'ButtonPushedFcn', @saveConfigPressed);
loadButton = uibutton(footer, 'Text', 'Load configuration', ...
    'ButtonPushedFcn', @loadConfigPressed);
statusLabel = uilabel(footer, 'Text', 'Ready', 'FontColor', [0.2 0.4 0.2]);
runButton = uibutton(footer, 'Text', 'Run stimulus', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.25 0.55 0.85], ...
    'FontColor', [1 1 1], 'ButtonPushedFcn', @runPressed);
cancelButton = uibutton(footer, 'Text', 'Cancel run', ...
    'Enable', 'off', 'FontWeight', 'bold', ...
    'BackgroundColor', [0.75 0.2 0.2], 'FontColor', [1 1 1]);

regionROI = [];
refreshEditors();
updateTargetButtons();
refreshTargetMap();
if strlength(latestConfigFile) > 0
    statusLabel.Text = "Autoloaded " + string(latestConfigFile);
end

    function tableControl = makeEditor(parent)
        gridLayout = uigridlayout(parent, [2 1]);
        gridLayout.RowHeight = {34, '1x'};
        uilabel(gridLayout, 'Text', ...
            'Edit values directly. Numeric arrays use MATLAB syntax, e.g. [0 45 90].', ...
            'FontAngle', 'italic');
        tableControl = uitable(gridLayout, 'ColumnName', {'Parameter', 'Value'}, ...
            'ColumnEditable', [false true], 'ColumnWidth', {210, 215}, ...
            'RowName', {}, 'CellEditCallback', @parametersEdited);
        tableControl.Layout.Row = 2;
    end

    function protocolChanged(~, ~)
        % Capture session-wide edits before replacing protocol-specific
        % defaults. These settings describe the rig or recording session
        % and should not change merely because the stimulus type changes.
        previous = cfg;
        try
            previous.display = vstim.tableDataToStruct( ...
                displayTable.Data, cfg.display);
            previous.sync = vstim.tableDataToStruct(syncTable.Data, cfg.sync);
            previous.session = vstim.tableDataToStruct( ...
                sessionTable.Data, cfg.session);

        catch ME
            protocolDropDown.Value = char(cfg.protocol);
            uialert(fig, ME.message, ...
                'Correct the current settings before switching protocols');
            return
        end

        next = vstim.defaultConfig(string(protocolDropDown.Value));
        next.display = previous.display;
        next.sync = previous.sync;
        next.session = previous.session;
        next.analysis = previous.analysis;
        cfg = vstim.normalizeDisplayGeometry(next);
        refreshEditors();
        helpBox.Value = protocolHelp(cfg.protocol);
        updateTargetButtons();
        refreshTargetMap();
    end

    function refreshEditors()
        stimTable.Data = vstim.structToTableData(cfg.stimulus);
        displayTable.Data = vstim.structToTableData(cfg.display);
        syncTable.Data = vstim.structToTableData(cfg.sync);
        sessionTable.Data = vstim.structToTableData(cfg.session);
        updateDuration();
    end

    function readEditors()
        template = vstim.defaultConfig(string(protocolDropDown.Value));
        cfg.protocol = string(protocolDropDown.Value);
        cfg.stimulus = vstim.tableDataToStruct(stimTable.Data, template.stimulus);
        cfg.display = vstim.tableDataToStruct(displayTable.Data, template.display);
        cfg.sync = vstim.tableDataToStruct(syncTable.Data, template.sync);
        cfg.session = vstim.tableDataToStruct(sessionTable.Data, template.session);
        cfg = vstim.normalizeDisplayGeometry(cfg);
        cfg = vstim.clampMappingRegion(cfg);
        stimTable.Data = vstim.structToTableData(cfg.stimulus);
        displayTable.Data = vstim.structToTableData(cfg.display);

        vstim.validateConfig(cfg);
    end

    function refreshTargetMap()
        try
            readEditors();
            previewCfg = cfg;
            if cfg.protocol == "Sparse noise"
                previewCfg.stimulus.totalDurationSec = ...
                    cfg.stimulus.patternDurationSec + ...
                    cfg.stimulus.interPatternSec;
            end
            seq = vstim.generateSequence(previewCfg, 60);
            vstim.previewSequence(previewAxes, cfg, seq);
            addRegionROI();
            estimate = vstim.estimateDuration(cfg, 60);
            summaryLabel.Text = sprintf('%d trials/patterns, %.1f min at 60 Hz', ...
                estimate.trialCount, estimate.durationSec/60);
            updateDuration();
            statusLabel.Text = 'Sequence validated';
            statusLabel.FontColor = [0.2 0.4 0.2];
        catch ME
            statusLabel.Text = 'Configuration error';
            statusLabel.FontColor = [0.8 0.1 0.1];
            uialert(fig, ME.message, 'Cannot generate sequence');
        end
    end

    function parametersEdited(~, ~)
        try
            readEditors();
            refreshTargetMap();
            statusLabel.Text = 'Parameters and target map updated';
            statusLabel.FontColor = [0.65 0.4 0];
        catch ME
            durationLabel.Text = 'Estimated duration: invalid settings';
            statusLabel.Text = string(ME.message);
            statusLabel.FontColor = [0.8 0.1 0.1];
        end
    end

    function updateDuration()
        estimate = vstim.estimateDuration(cfg, 60);
        durationLabel.Text = sprintf('Estimated duration: %s  (%d trials)', ...
            estimate.formatted, estimate.trialCount);
    end

    function resetPressed(~, ~)
        cfg = vstim.defaultConfig(string(protocolDropDown.Value));
        refreshEditors();
        refreshTargetMap();
    end

    function saveConfigPressed(~, ~)
        try
            readEditors();
            filename = vstim.saveGuiConfig(cfg);
            statusLabel.Text = "Saved configuration: " + string(filename);
        catch ME
            uialert(fig, ME.message, 'Could not save configuration');
        end
    end

    function loadConfigPressed(~, ~)
        [file, path] = uigetfile({'*.mat;*.json', ...
            'Visual-stimulus configurations (*.mat, *.json)'}, ...
            'Load visual-stimulus configuration', vstim.configDirectory);
        if isequal(file, 0)
            return
        end
        try
            loaded = vstim.loadGuiConfig(fullfile(path, file));
            if ~any(string(loaded.protocol) == protocolNames)
                error('vstim:UnknownProtocol', ...
                    'Configuration uses unknown protocol "%s".', loaded.protocol)
            end
            cfg = loaded;
            protocolDropDown.Value = char(cfg.protocol);
            refreshEditors();
            helpBox.Value = protocolHelp(cfg.protocol);
            updateTargetButtons();
            refreshTargetMap();
            statusLabel.Text = "Loaded configuration: " + string(file);
        catch ME
            uialert(fig, ME.message, 'Could not load configuration');
        end
    end

    function runPressed(~, ~)
        try
            readEditors();
            detection = vstim.detectLatestWaveSurferFile(cfg.session);
            cfg.session.wavesurferDetectionEnabled = detection.enabled;
            cfg.session.wavesurferDetected = detection.found;
            cfg.session.wavesurferFile = detection.file;
            cfg.session.wavesurferFilename = detection.filename;
            cfg.session.wavesurferFolder = detection.folder;
            cfg.session.wavesurferFileModifiedAt = ...
                string(detection.modifiedAt);
            cfg.session.wavesurferFileAgeMinutes = detection.ageMinutes;
            cfg.session.wavesurferDetectionMessage = ...
                string(detection.message);
            if detection.found && ...
                    strlength(string(cfg.session.wavesurferSweep)) == 0
                [~, detectedSweep] = fileparts(char(detection.filename));
                cfg.session.wavesurferSweep = string(detectedSweep);
            end
            fprintf('%s\n', detection.message);
            setPresentationControls(true);
            statusLabel.Text = string(detection.message) + ...
                " — Presenting; use Cancel run or Escape";
            statusLabel.FontColor = [0.75 0.35 0];
            drawnow;
            runData = vstim.runProtocol(cfg, true);
            clearDetectionMetadata();
            if runData.status.completed
                statusLabel.Text = "Completed and saved: " + ...
                    string(runData.status.savedFile) + ". " + ...
                    string(runData.status.message) + " " + ...
                    string(detection.message);
                statusLabel.FontColor = [0.2 0.4 0.2];
            else
                statusLabel.Text = "Aborted and saved: " + ...
                    string(runData.status.savedFile);
                statusLabel.FontColor = [0.75 0.35 0];
            end
        catch ME
            clearDetectionMetadata();
            statusLabel.Text = 'Presentation failed; TTL cleanup attempted';
            statusLabel.FontColor = [0.8 0.1 0.1];
            uialert(fig, ME.message, 'Stimulus error');
        end
        setPresentationControls(false);
    end

    function setPresentationControls(isRunning)
        if isRunning
            runButton.Enable = 'off';
            cancelButton.Enable = 'on';
            protocolDropDown.Enable = 'off';
            previewButton.Enable = 'off';
            fullDisplayButton.Enable = 'off';
            resetButton.Enable = 'off';
            saveButton.Enable = 'off';
            loadButton.Enable = 'off';
            stimTable.Enable = 'off';
            displayTable.Enable = 'off';
            syncTable.Enable = 'off';
            sessionTable.Enable = 'off';
        else
            runButton.Enable = 'on';
            cancelButton.Enable = 'off';
            protocolDropDown.Enable = 'on';
            resetButton.Enable = 'on';
            saveButton.Enable = 'on';
            loadButton.Enable = 'on';
            stimTable.Enable = 'on';
            displayTable.Enable = 'on';
            syncTable.Enable = 'on';
            sessionTable.Enable = 'on';
            updateTargetButtons();
        end
    end

    function clearDetectionMetadata()
        names = {'wavesurferDetectionEnabled', 'wavesurferDetected', ...
            'wavesurferFile', 'wavesurferFilename', 'wavesurferFolder', ...
            'wavesurferFileModifiedAt', 'wavesurferFileAgeMinutes', ...
            'wavesurferDetectionMessage'};
        present = names(isfield(cfg.session, names));
        if ~isempty(present)
            cfg.session = rmfield(cfg.session, present);
        end
    end

    function selectRegionPressed(~, ~)
        try
            readEditors();
            if ~isempty(regionROI) && isvalid(regionROI)
                delete(regionROI);
            end
            az = cfg.display.azimuthLimitsDeg;
            el = cfg.display.elevationLimitsDeg;
            regionROI = drawrectangle(previewAxes, 'Color', [0.85 0.2 0.2], ...
                'LineWidth', 2, 'DrawingArea', ...
                [az(1) el(1) diff(az) diff(el)]);
            if isempty(regionROI) || ~isvalid(regionROI)
                return
            end
            applyRegionPosition(regionROI.Position);
        catch ME
            uialert(fig, ME.message, 'Could not select target region');
            refreshTargetMap();
        end
    end

    function fullDisplayPressed(~, ~)
        try
            readEditors();
            cfg.stimulus.mappingAzimuthLimitsDeg = [];
            cfg.stimulus.mappingElevationLimitsDeg = [];
            stimTable.Data = vstim.structToTableData(cfg.stimulus);
            refreshTargetMap();
            statusLabel.Text = 'Target region reset to the full display';
        catch ME
            uialert(fig, ME.message, 'Could not reset target region');
        end
    end

    function addRegionROI()
        if any(cfg.protocol == ["Targeted Gabor grid", ...
                "Gabor + inverse stimuli"])
            return
        end
        [az, el] = vstim.mappingLimits(cfg);
        pos = [az(1), el(1), diff(az), diff(el)];
        hold(previewAxes, 'on');
        regionROI = drawrectangle(previewAxes, 'Position', pos, ...
            'Color', [0.85 0.2 0.2], 'LineWidth', 2, ...
            'DrawingArea', [cfg.display.azimuthLimitsDeg(1), ...
            cfg.display.elevationLimitsDeg(1), ...
            diff(cfg.display.azimuthLimitsDeg), ...
            diff(cfg.display.elevationLimitsDeg)]);
        hold(previewAxes, 'off');
        addlistener(regionROI, 'ROIMoved', ...
            @(source, event) applyRegionPosition(event.CurrentPosition));
    end

    function applyRegionPosition(position)
        displayAz = cfg.display.azimuthLimitsDeg;
        displayEl = cfg.display.elevationLimitsDeg;
        az = sort(position(1) + [0 position(3)]);
        el = sort(position(2) + [0 position(4)]);
        az = [max(az(1), displayAz(1)), min(az(2), displayAz(2))];
        el = [max(el(1), displayEl(1)), min(el(2), displayEl(2))];
        if diff(az) <= 0 || diff(el) <= 0
            error('vstim:InvalidMappingRegion', ...
                'Draw a non-empty rectangle inside the display.')
        end
        cfg.stimulus.mappingAzimuthLimitsDeg = round(az, 3);
        cfg.stimulus.mappingElevationLimitsDeg = round(el, 3);
        cfg = vstim.clampMappingRegion(cfg);
        stimTable.Data = vstim.structToTableData(cfg.stimulus);
        refreshTargetMap();
        statusLabel.Text = sprintf( ...
            'Target: %.1f° to %.1f° azimuth, %.1f° to %.1f° elevation', ...
            az(1), az(2), el(1), el(2));
    end

    function updateTargetButtons()
        if any(cfg.protocol == ["Targeted Gabor grid", ...
                "Gabor + inverse stimuli"])
            previewButton.Enable = 'off';
            fullDisplayButton.Enable = 'off';
        else
            previewButton.Enable = 'on';
            fullDisplayButton.Enable = 'on';
        end
    end

    function closeGUI(~, ~)
        if strcmp(runButton.Enable, 'off')
            statusLabel.Text = ...
                'A run is active. Click the red Cancel run button first.';
            return
        end
        delete(fig);
    end
end

function text = protocolHelp(protocol)
switch string(protocol)
    case "Moving bars"
        text = {'Bidirectional moving bars'; ...
            'Vertical sweeps estimate azimuth; horizontal sweeps estimate elevation.'; ...
            'Each bar starts fully outside and exits fully outside the mapped field.'};
    case "Flashed bars"
        text = {'Flashed bars'; ...
            'Empty position arrays are generated automatically from display limits.'; ...
            'Black and white conditions remain separate; there are no blank trials.'};
    case "Sparse noise"
        text = {'Locally sparse multi-tile noise'; ...
            'The saved matrix is location × pattern: -1 black, 0 gray, +1 white.'; ...
            'Zero inter-pattern time uses a short onset TTL pulse per pattern.'; ...
            'With autoGridFromDisplay=true, gridSize is ignored.'; ...
            'constant_degrees gives a uniform nominal-degree grid with no position-dependent warp.'; ...
            'Tiles retain fixed pixel dimensions everywhere on the monitor.'; ...
            'lockGridSpacingToTileSize=true tiles and clips through every edge.'};
    case "Fast Gabor tiling"
        text = {'Fast circular-grating tiling'; ...
            'Default 0° means bar orientation, not spatial-frequency-vector direction.'; ...
            'Drifting advances spatial phase at constant contrast.'; ...
            'edgeBlurDeg controls only the circular aperture edge; there is no Gaussian envelope.'};
    case "Targeted Gabor grid"
        text = {'Targeted degree-centered Gabor grid'; ...
            'Set the center using azimuth and elevation in degrees.'; ...
            'gridRadius 0 gives 1x1, 1 gives 3x3, and 2 gives 5x5.'; ...
            'gridSpacingDeg is [azimuth elevation] center-to-center spacing.'};
    case "Gabor + inverse stimuli"
        text = {'Classical, inverse, and full-field drifting gratings'; ...
            'One location sets both the classical patch and inverse-mask center.'; ...
            'diameterDeg controls the Gabor; inverseDiameterDeg is the independently adjustable fully gray core.'; ...
            'The inverse edge blur starts at the core boundary and shades outward.'; ...
            'Classical: blurred circular grating patch on gray.'; ...
            'Inverse: full-field grating with a blurred gray circular hole.'; ...
            'Full field: drifting grating without a patch or mask.'};
end
end
