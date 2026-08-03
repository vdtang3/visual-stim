function runData = runProtocol(cfg, guiMouseCancelOptions, progressFcn)
%RUNPROTOCOL Generate and present one complete Psychtoolbox experiment.
% WaveSurfer should already be acquiring. The function always attempts to
% leave the Arduino TTL low and saves partial data after an abort or error.
% guiMouseCancelOptions uses raw mouse-button polling through Screen so the
% GUI cancel control does not require MATLAB callbacks during presentation.
% progressFcn is an optional lightweight GUI repaint hook called at 1 Hz.

if nargin < 2
    guiMouseCancelOptions = false;
end
if nargin < 3
    progressFcn = [];
end
if ~isempty(progressFcn) && ~isa(progressFcn,'function_handle')
    error('vstim:InvalidProgressFunction', ...
        'The presentation progress function must be a function handle.')
end
guiCancelTargetBoundsPx = [];
if isstruct(guiMouseCancelOptions)
    guiMouseCancelEnabled = isfield(guiMouseCancelOptions,'enabled') && ...
        isscalar(guiMouseCancelOptions.enabled) && ...
        logical(guiMouseCancelOptions.enabled);
    if isfield(guiMouseCancelOptions,'targetBoundsPx')
        guiCancelTargetBoundsPx = ...
            double(guiMouseCancelOptions.targetBoundsPx(:)');
        if numel(guiCancelTargetBoundsPx) ~= 4 || ...
                any(~isfinite(guiCancelTargetBoundsPx))
            error('vstim:InvalidCancelTarget', ...
                'GUI cancel target bounds must contain four finite values.')
        end
    end
else
    guiMouseCancelEnabled = logical(guiMouseCancelOptions);
end

cfg = vstim.normalizeDisplayGeometry(cfg);
vstim.validateConfig(cfg);
if isempty(which('PsychDefaultSetup')) || isempty(which('Screen'))
    error('vstim:PsychtoolboxNotConfigured', ...
        ['Psychtoolbox is not available on the MATLAB path. Run ' ...
         'installVisualStim once, then reopen the GUI.'])
end
% GUI runs use the raw mouse cancellation path and deliberately make no
% PsychHID, KbCheck, or keyboard-queue calls. On affected Windows machines a
% keyboard probe can block indefinitely instead of returning an error.
if guiMouseCancelEnabled
    keyboardAvailable = false;
    keyboardPreflightDiagnostic = ...
        "Skipped because GUI mouse cancellation is enabled.";
    fprintf('[vstim] GUI mouse-cancel mode: all keyboard calls skipped.\n');
else
    [keyboardAvailable, keyboardPreflightDiagnostic] = ...
        vstim.checkKeyboardAccess;
end
if ~exist(cfg.session.outputDirectory, 'dir')
    mkdir(cfg.session.outputDirectory);
end

runData = struct();
runData.params = cfg;
runData.status.startedAt = datetime('now');
runData.status.completed = false;
runData.status.aborted = false;
runData.status.message = "";
runData.display.platformTimingWarning = vstim.platformTimingWarning;
if strlength(runData.display.platformTimingWarning) > 0
    warning('vstim:PlatformTimingRisk','%s', ...
        runData.display.platformTimingWarning)
end

fprintf('[vstim] Initializing Psychtoolbox display settings...\n');
if guiMouseCancelEnabled
    % PsychDefaultSetup level 1 and above calls KbName. Reproduce only the
    % normalized 0-1 color-range setting needed by this package.
    PsychDefaultSetup(0);
    global psych_default_colormode
    psych_default_colormode = 1;
else
    PsychDefaultSetup(2);
end
Screen('Preference', 'SkipSyncTests', double(cfg.display.skipSyncTests));
Screen('Preference', 'VisualDebugLevel', 1);
Screen('Preference', 'Verbosity', 1);

win = [];
ttl = [];
keyboardQueueCreated = false;
keyboardFallbackPolling = false;
escapeKey = [];
try
    screens = Screen('Screens');
    if isempty(cfg.display.screenNumber)
        screenNumber = max(screens);
    else
        screenNumber = cfg.display.screenNumber;
    end

    screenRect = Screen('Rect', screenNumber);
    cfg.display.resolutionPx = [RectWidth(screenRect), RectHeight(screenRect)];

    % Sparse-noise constraint solving is independent of measured refresh
    % rate. Generate it before opening fullscreen, but after querying the
    % real pixel resolution needed for square-pixel grid geometry.
    prebuiltSequence = [];
    if cfg.protocol == "Sparse noise"
        prebuiltSequence = vstim.generateSequence(cfg, 60);
        runData.params = cfg;
    end

    PsychImaging('PrepareConfiguration');
    if cfg.display.geometryCorrectionEnabled
        calibrationFile = char(cfg.display.geometryCalibrationFile);
        if ~isfile(calibrationFile)
            error('vstim:MissingGeometryCalibration', ...
                'Psychtoolbox geometry calibration file not found: %s', ...
                calibrationFile)
        end
        PsychImaging('AddTask', 'AllViews', 'GeometryCorrection', ...
            calibrationFile);
    end
    fprintf('[vstim] Opening stimulus window on Screen %d...\n', ...
        screenNumber);
    [win, winRect] = PsychImaging('OpenWindow', screenNumber, ...
        cfg.display.backgroundGray);
    fprintf('[vstim] Stimulus window opened; preparing sequence...\n');
    if guiMouseCancelEnabled
        % Keep the pointer visible on the separate GUI display so the red
        % Cancel run control remains easy to target.
        ShowCursor;
    else
        HideCursor;
    end
    Priority(MaxPriority(win));
    % One alpha-compositing mode is used for the whole run. Gabor contrast
    % and inverse masking therefore use the same aperture alpha profile,
    % without changing OpenGL blend state on individual frames.
    Screen('BlendFunction', win, 'GL_SRC_ALPHA', ...
        'GL_ONE_MINUS_SRC_ALPHA');
    ifi = Screen('GetFlipInterval', win);
    frameRate = 1/ifi;
    geometry = vstim.visualGeometry(winRect, cfg);
    if cfg.protocol == "Sparse noise"
        sequence = prebuiltSequence;
        sequence.nominalFrameRate = frameRate;
        sequence.trials.durationSec(:) = ...
            round(cfg.stimulus.patternDurationSec*frameRate)/frameRate;
        sequence.estimatedDurationSec = sum(sequence.trials.durationSec + ...
            sequence.trials.interStimulusSec);
    else
        sequence = vstim.generateSequence(cfg, frameRate);
    end
    runData.sequence = sequence;
    runData.sequence.estimatedStimulusDurationSec = ...
        sequence.estimatedDurationSec;
    runData.sequence.estimatedTotalDurationSec = ...
        sequence.estimatedDurationSec + cfg.display.preRunBlankSec + ...
        cfg.display.postRunBlankSec;
    runData.display.ifiSec = ifi;
    runData.display.measuredFrameRate = frameRate;
    runData.display.windowRect = winRect;
    runData.display.geometryCorrectionEnabled = ...
        cfg.display.geometryCorrectionEnabled;
    runData.display.geometryCalibrationFile = ...
        cfg.display.geometryCalibrationFile;
    runData.display.geometry = rmfield(geometry, ...
        {'degToPxX', 'degToPxY', 'sizeDegToPx'});
    runData.display.keyboardAccessAvailable = keyboardAvailable;
    runData.display.keyboardInputMode = "disabled_by_gui_mouse_mode";
    runData.display.keyboardPreflightDiagnostic = ...
        keyboardPreflightDiagnostic;
    runData.display.keyboardDiagnostic = "";
    runData.display.guiCancelEnabled = guiMouseCancelEnabled;
    runData.display.guiCancelPollingHz = 20;
    runData.display.guiCancelInputMode = "disabled";
    runData.display.guiCancelDiagnostic = "";
    runData.display.guiCancelTargetBoundsPx = ...
        guiCancelTargetBoundsPx;
    runData.display.guiProgressUpdateHz = double(~isempty(progressFcn));
    runData.display.guiProgressUpdateCount = 0;
    runData.display.guiProgressMaximumUpdateSec = 0;
    runData.display.guiProgressDiagnostic = "";
    guiCancelPollStride = max(1, ...
        round(frameRate/runData.display.guiCancelPollingHz));
    if any(cfg.protocol == ["Fast Gabor tiling", "Targeted Gabor grid", ...
            "Gabor + inverse stimuli"])
        pxPerDeg = geometry.pixelsPerDegAtCenter;
        geometry.aperture = vstim.circularApertureGeometry( ...
            cfg.stimulus.diameterDeg, cfg.stimulus.edgeBlurDeg, pxPerDeg);
        % The transition spans edgeBlurDeg and is centered on the nominal
        % radius diameterDeg/2, so diameterDeg is the 50% contour.
        % A 0.5 premultiplier makes the requested value correspond to
        % conventional Michelson contrast.
        geometry.gaborTexture = ...
            CreateProceduralSmoothedApertureSineGrating(win, ...
            geometry.aperture.supportDiameterPx, ...
            geometry.aperture.supportDiameterPx, ...
            [cfg.display.backgroundGray ...
            cfg.display.backgroundGray cfg.display.backgroundGray 1], ...
            geometry.aperture.outerRadiusPx, 0.5, ...
            geometry.aperture.edgeBlurPx, 1, 1);
        runData.display.gaborAperture = geometry.aperture;
        if cfg.protocol == "Gabor + inverse stimuli"
            geometry.inverseAperture = vstim.circularCoreApertureGeometry( ...
                cfg.stimulus.inverseDiameterDeg, ...
                cfg.stimulus.edgeBlurDeg, pxPerDeg);
            geometry.inverseTexture = ...
                CreateProceduralSmoothedApertureSineGrating(win, ...
                geometry.inverseAperture.supportDiameterPx, ...
                geometry.inverseAperture.supportDiameterPx, ...
                [cfg.display.backgroundGray cfg.display.backgroundGray ...
                cfg.display.backgroundGray 1], ...
                geometry.inverseAperture.outerRadiusPx, 0.5, ...
                geometry.inverseAperture.edgeBlurPx, 1, 1);
            runData.display.inverseAperture = geometry.inverseAperture;
            runData.display.inverseDiameterDefinition = ...
                "fully gray core; edge blur extends outward";
            geometry.fullFieldGratingTexture = CreateProceduralSineGrating( ...
                win, RectWidth(winRect), RectHeight(winRect), ...
                [cfg.display.backgroundGray cfg.display.backgroundGray ...
                cfg.display.backgroundGray 1], inf, 0.5);
            geometry.fullFieldGratingRect = winRect;
            geometry.fullFieldRotationMode = ...
                kPsychUseTextureMatrixForRotation;
        end
    end

    nTrials = height(sequence.trials);
    presentation = table((1:nTrials)', nan(nTrials,1), nan(nTrials,1), ...
        nan(nTrials,1), nan(nTrials,1), zeros(nTrials,1), false(nTrials,1), ...
        strings(nTrials,1), 'VariableNames', {'trialIndex', 'flipOnsetSec', ...
        'flipOffsetSec', 'ttlHighSec', 'ttlLowSec', 'framesPresented', ...
        'completed', 'message'});
    presentation.frameFlipTimesSec = cell(nTrials, 1);
    presentation.frameValues = cell(nTrials, 1);
    presentation.missedFlipCount = zeros(nTrials, 1);
    presentation.maximumMissSec = zeros(nTrials, 1);
    presentation.longFrameIntervalCount = zeros(nTrials, 1);
    presentation.estimatedDroppedRefreshCount = zeros(nTrials, 1);
    presentation.maximumFrameIntervalSec = zeros(nTrials, 1);
    presentation.actualInterStimulusSec = nan(nTrials, 1);
    runData.presentation = presentation;
    runData.blank.pre.requestedSec = cfg.display.preRunBlankSec;
    runData.blank.pre.startedSec = NaN;
    runData.blank.pre.endedSec = NaN;
    runData.blank.pre.actualSec = NaN;
    runData.blank.pre.flipTimesSec = [];
    runData.blank.pre.missedDeadlineCount = 0;
    runData.blank.post.requestedSec = cfg.display.postRunBlankSec;
    runData.blank.post.startedSec = NaN;
    runData.blank.post.endedSec = NaN;
    runData.blank.post.actualSec = NaN;
    runData.blank.post.flipTimesSec = [];
    runData.blank.post.missedDeadlineCount = 0;
    runData.display.hiddenWarmupTrialIndices = [];
    runData.display.hiddenWarmupFlipTimesSec = [];
    runData.display.hiddenWarmupMissedDeadlineCount = 0;
    runData.sync.enabled = logical(cfg.sync.enabled);
    runData.sync.mode = sequence.ttlMode;
    runData.sync.modeReason = sequence.ttlModeReason;
    runData.sync.onsetPulseFrames = 1;
    runData.sync.expectedOnsetPulseSec = ifi;
    runData.sync.timestampsRepresentPhysicalCommands = ...
        logical(cfg.sync.enabled);
    runData.sync.port = cfg.sync.port;
    runData.sync.baudRate = cfg.sync.baudRate;
    runData.sync.startedLow = true;
    runData.sync.endedLow = false;

    fprintf('[vstim] Sequence ready; initializing TTL and cancel control...\n');
    expectedFramesPerTrial = max(1, ...
        round(double(sequence.trials.durationSec)/ifi));
    if any(expectedFramesPerTrial < 2)
        error('vstim:StimulusTooShortForFrameTTL', ...
            ['Every stimulus must last at least two display frames when ' ...
             'using one-frame TTL pulses. Increase its duration to at ' ...
             'least %.4f seconds for this display.'], 2*ifi)
    end
    ttl = vstim.TTLController(cfg.sync);
    if keyboardAvailable
        escapeKey = KbName('ESCAPE');
        escapeKeys = zeros(1,256);
        escapeKeys(escapeKey) = 1;
        % KbCheck can synchronously reinitialize PsychHID and has produced
        % 0.2-0.8 second stalls inside otherwise on-time stimulus runs. A
        % background keyboard queue moves that work before presentation and
        % makes per-frame Escape checks nonblocking.
        try
            KbQueueCreate([],escapeKeys);
            KbQueueStart;
            KbQueueFlush;
            KbQueueCheck; % Prime before the first stimulus flip.
            keyboardQueueCreated = true;
            runData.display.keyboardAccessAvailable = true;
            runData.display.keyboardInputMode = "asynchronous_queue";
        catch keyboardQueueError
            keyboardQueueCreated = false;
            % Some older/platform-specific Psychtoolbox installations cannot
            % create a queue. Prime KbCheck before presentation so any HID
            % initialization stall occurs while the screen is still gray,
            % then poll only at 10 Hz. If that also fails on Windows,
            % presentation continues without keyboard input.
            try
                KbQueueRelease;
            catch
            end
            try
                clear KbCheck
                KbCheck;
                keyboardFallbackPolling = true;
                keyboardPollStride = max(1,round(frameRate/10));
                runData.display.keyboardAccessAvailable = true;
                runData.display.keyboardInputMode = ...
                    "primed_10_Hz_polling";
                runData.display.keyboardQueueWarning = ...
                    string(keyboardQueueError.message);
            catch keyboardPollingError
                if ~ispc
                    rethrow(keyboardPollingError)
                end
                keyboardAvailable = false;
                runData.display.keyboardAccessAvailable = false;
                runData.display.keyboardInputMode = ...
                    "disabled_unavailable";
                runData.display.keyboardDiagnostic = ...
                    string(keyboardPollingError.message);
                runData.display.keyboardQueueWarning = ...
                    string(keyboardQueueError.message);
            end
        end
    elseif runData.display.keyboardInputMode ~= ...
            "disabled_by_gui_mouse_mode"
        runData.display.keyboardInputMode = "disabled_unavailable";
    end

    mouseCancelAvailable = false;
    mouseButtonWasDown = false;
    if guiMouseCancelEnabled
        try
            [~,~,mouseButtons] = GetMouse;
            mouseButtonWasDown = any(mouseButtons);
            mouseCancelAvailable = true;
            runData.display.guiCancelInputMode = ...
                "screen_mex_global_mouse_press";
        catch mouseCancelError
            runData.display.guiCancelDiagnostic = ...
                string(mouseCancelError.message);
        end
    end
    fprintf('[vstim] Starting visual presentation (%d trials/patterns).\n', ...
        nTrials);
    vbl = Screen('Flip', win);
    flipImmediatelyAfterISI = false;
    nextProgressUpdateSec = GetSecs+1;

    % Exercise each rendering path in the back buffer before recorded
    % stimulation begins. The buffer is overwritten with gray before every
    % flip, so none of these representative stimuli becomes visible.
    warmupTrialIndices = 1;
    if ismember('stimulusType',sequence.trials.Properties.VariableNames)
        stimulusTypes = unique(sequence.trials.stimulusType,'stable');
        warmupTrialIndices = zeros(numel(stimulusTypes),1);
        for warmupTypeIndex = 1:numel(stimulusTypes)
            warmupTrialIndices(warmupTypeIndex) = find( ...
                sequence.trials.stimulusType == ...
                stimulusTypes(warmupTypeIndex),1,'first');
        end
    end
    warmupFlipTimes = nan(numel(warmupTrialIndices),1);
    warmupMisses = zeros(numel(warmupTrialIndices),1);
    for warmupIndex = 1:numel(warmupTrialIndices)
        trialIndex = warmupTrialIndices(warmupIndex);
        Screen('FillRect',win,cfg.display.backgroundGray);
        vstim.drawStimulus(win,geometry,cfg,sequence,trialIndex,1,0);
        Screen('FillRect',win,cfg.display.backgroundGray);
        [vbl,warmupFlipTimes(warmupIndex),~,warmupMisses(warmupIndex)] = ...
            Screen('Flip',win,vbl+0.5*ifi);
    end
    runData.display.hiddenWarmupTrialIndices = warmupTrialIndices;
    runData.display.hiddenWarmupFlipTimesSec = warmupFlipTimes;
    runData.display.hiddenWarmupMissedDeadlineCount = ...
        sum(warmupMisses > 0);

    % Hold a visible gray baseline for the requested number of display
    % intervals. TTL remains low throughout warm-up and pre-roll.
    runData.blank.pre.startedSec = vbl;
    nPreRunBlankIntervals = max(0, ...
        round(cfg.display.preRunBlankSec/ifi));
    preRunFlipTimes = nan(max(0,nPreRunBlankIntervals-1),1);
    preRunMisses = zeros(size(preRunFlipTimes));
    for blankFrame = 1:numel(preRunFlipTimes)
        Screen('FillRect',win,cfg.display.backgroundGray);
        [vbl,preRunFlipTimes(blankFrame),~,preRunMisses(blankFrame)] = ...
            Screen('Flip',win,vbl+0.5*ifi);
        if ~isempty(progressFcn) && GetSecs >= nextProgressUpdateSec
            try
                progressUpdateStartedSec = GetSecs;
                progressFcn([],[]);
                progressUpdateDurationSec = GetSecs-progressUpdateStartedSec;
                runData.display.guiProgressUpdateCount = ...
                    runData.display.guiProgressUpdateCount+1;
                runData.display.guiProgressMaximumUpdateSec = max( ...
                    runData.display.guiProgressMaximumUpdateSec, ...
                    progressUpdateDurationSec);
            catch progressError
                runData.display.guiProgressDiagnostic = ...
                    string(progressError.message);
                progressFcn = [];
            end
            nextProgressUpdateSec = GetSecs+1;
        end
    end
    runData.blank.pre.flipTimesSec = preRunFlipTimes;
    runData.blank.pre.missedDeadlineCount = sum(preRunMisses > 0);

    for t = 1:nTrials
        tr = sequence.trials(t,:);
        nFrames = max(1, round(tr.durationSec/ifi));
        flipTimes = nan(nFrames, 1);
        frameValues = nan(nFrames, 1);
        missedDeadlines = zeros(nFrames, 1);
        trialDisplayOnset = NaN;

        for frame = 1:nFrames
            if frame == 1 || isnan(trialDisplayOnset)
                elapsed = 0;
            else
                % Predict the next displayed frame from the most recent
                % actual VBL timestamp. If a deadline was missed, phase
                % catches up on the following frame instead of permanently
                % slowing the drifting grating.
                elapsed = max(0, vbl + ifi - trialDisplayOnset);
            end
            Screen('FillRect', win, cfg.display.backgroundGray);
            info = vstim.drawStimulus(win, geometry, cfg, sequence, t, frame, elapsed);
            if frame == 1 && flipImmediatelyAfterISI
                % The explicit ISI wait has already elapsed. Do not reuse
                % the gray flip's old vbl timestamp.
                requestedFlip = 0;
                flipImmediatelyAfterISI = false;
            else
                requestedFlip = vbl + 0.5*ifi;
            end
            [vbl, stimulusOnset, ~, missed] = ...
                Screen('Flip', win, requestedFlip);
            if frame == 1
                trialDisplayOnset = stimulusOnset;
                runData.presentation.flipOnsetSec(t) = stimulusOnset;
                if t == 1
                    runData.blank.pre.endedSec = stimulusOnset;
                    runData.blank.pre.actualSec = stimulusOnset - ...
                        runData.blank.pre.startedSec;
                end
                if t > 1 && ...
                        ~isnan(runData.presentation.flipOffsetSec(t-1))
                    runData.presentation.actualInterStimulusSec(t-1) = ...
                        stimulusOnset - ...
                        runData.presentation.flipOffsetSec(t-1);
                end
                % For a zero-ISI sequence, the next pattern's first flip is
                % the preceding pattern's actual display offset.
                if t > 1 && sequence.trials.interStimulusSec(t-1) == 0
                    runData.presentation.flipOffsetSec(t-1) = stimulusOnset;
                end
                ttl.high();
                runData.presentation.ttlHighSec(t) = GetSecs;
            elseif frame == 2
                % Lower the line only after the second frame has appeared.
                % The pulse therefore spans the first displayed frame and
                % introduces no blocking wait into stimulus preparation.
                ttl.low();
                runData.presentation.ttlLowSec(t) = GetSecs;
            end
            flipTimes(frame) = stimulusOnset;
            missedDeadlines(frame) = max(0, missed);
            if isfield(info, 'centerDeg')
                frameValues(frame) = info.centerDeg;
            end
            runData.presentation.framesPresented(t) = frame;

            if ~isempty(progressFcn) && GetSecs >= nextProgressUpdateSec
                try
                    progressUpdateStartedSec = GetSecs;
                    progressFcn([],[]);
                    progressUpdateDurationSec = ...
                        GetSecs-progressUpdateStartedSec;
                    runData.display.guiProgressUpdateCount = ...
                        runData.display.guiProgressUpdateCount+1;
                    runData.display.guiProgressMaximumUpdateSec = max( ...
                        runData.display.guiProgressMaximumUpdateSec, ...
                        progressUpdateDurationSec);
                catch progressError
                    runData.display.guiProgressDiagnostic = ...
                        string(progressError.message);
                    progressFcn = [];
                end
                nextProgressUpdateSec = GetSecs+1;
            end

            if mouseCancelAvailable && ...
                    mod(frame-1,guiCancelPollStride) == 0
                % GetMouse reads button state through Screen's
                % GetMouseHelper and does not require PsychHID or MATLAB's
                % GUI callback queue. Poll at 20 Hz for responsive clicks
                % without adding a mouse query to every display refresh.
                try
                    [~,~,mouseButtons] = GetMouse;
                    mouseButtonIsDown = any(mouseButtons);
                    if mouseButtonIsDown && ~mouseButtonWasDown
                        cancelTargetPressed = true;
                        if ~isempty(guiCancelTargetBoundsPx)
                            pointerPosition = ...
                                double(get(groot,'PointerLocation'));
                            cancelTargetPressed = ...
                                pointerPosition(1) >= ...
                                    guiCancelTargetBoundsPx(1) && ...
                                pointerPosition(1) <= ...
                                    guiCancelTargetBoundsPx(3) && ...
                                pointerPosition(2) >= ...
                                    guiCancelTargetBoundsPx(2) && ...
                                pointerPosition(2) <= ...
                                    guiCancelTargetBoundsPx(4);
                        end
                        if cancelTargetPressed
                            error('vstim:UserAbort', ...
                                ['User canceled with the VisualStimGUI ' ...
                                 'Cancel run control.'])
                        end
                    end
                    mouseButtonWasDown = mouseButtonIsDown;
                catch mouseCancelError
                    if strcmp(mouseCancelError.identifier, ...
                            'vstim:UserAbort')
                        rethrow(mouseCancelError)
                    end
                    mouseCancelAvailable = false;
                    runData.display.guiCancelInputMode = ...
                        "disabled_after_mouse_error";
                    runData.display.guiCancelDiagnostic = ...
                        string(mouseCancelError.message);
                end
            end

            if keyboardQueueCreated
                try
                    [keyPressed, firstPress] = KbQueueCheck;
                    if keyPressed && firstPress(escapeKey) > 0
                        error('vstim:UserAbort', ...
                            'User aborted with Escape.')
                    end
                catch keyboardRuntimeError
                    if strcmp(keyboardRuntimeError.identifier, ...
                            'vstim:UserAbort')
                        rethrow(keyboardRuntimeError)
                    elseif ~ispc
                        rethrow(keyboardRuntimeError)
                    end
                    % A Windows PsychHID queue can pass initialization and
                    % still fail later. Fall back to polling without
                    % stopping the visual stimulus.
                    keyboardQueueCreated = false;
                    try
                        KbQueueStop;
                        KbQueueRelease;
                    catch
                    end
                    try
                        clear KbCheck
                        KbCheck;
                        keyboardFallbackPolling = true;
                        keyboardPollStride = ...
                            max(1,round(frameRate/10));
                        runData.display.keyboardInputMode = ...
                            "runtime_10_Hz_polling";
                        runData.display.keyboardQueueRuntimeWarning = ...
                            string(keyboardRuntimeError.message);
                    catch keyboardPollingError
                        keyboardFallbackPolling = false;
                        keyboardAvailable = false;
                        runData.display.keyboardAccessAvailable = false;
                        runData.display.keyboardInputMode = ...
                            "disabled_unavailable";
                        runData.display.keyboardDiagnostic = ...
                            string(keyboardPollingError.message);
                        runData.display.keyboardQueueRuntimeWarning = ...
                            string(keyboardRuntimeError.message);
                    end
                end
            elseif keyboardFallbackPolling && ...
                    mod(frame-1,keyboardPollStride) == 0
                try
                    [keyPressed,~,keyCode] = KbCheck;
                    if keyPressed && keyCode(escapeKey)
                        error('vstim:UserAbort', ...
                            'User aborted with Escape.')
                    end
                catch keyboardRuntimeError
                    if strcmp(keyboardRuntimeError.identifier, ...
                            'vstim:UserAbort')
                        rethrow(keyboardRuntimeError)
                    elseif ~ispc
                        rethrow(keyboardRuntimeError)
                    end
                    keyboardFallbackPolling = false;
                    keyboardAvailable = false;
                    runData.display.keyboardAccessAvailable = false;
                    runData.display.keyboardInputMode = ...
                        "disabled_unavailable";
                    runData.display.keyboardDiagnostic = ...
                        string(keyboardRuntimeError.message);
                end
            end
        end

        if tr.interStimulusSec > 0 || t == nTrials
            Screen('FillRect', win, cfg.display.backgroundGray);
            [vbl, offsetTime] = Screen('Flip', win, vbl + 0.5*ifi);
            runData.presentation.flipOffsetSec(t) = offsetTime;
        end
        runData.presentation.frameFlipTimesSec{t} = flipTimes;
        runData.presentation.frameValues{t} = frameValues;
        runData.presentation.missedFlipCount(t) = ...
            sum(missedDeadlines > 0);
        runData.presentation.maximumMissSec(t) = max(missedDeadlines);
        frameIntervals = diff(flipTimes);
        if ~isempty(frameIntervals)
            runData.presentation.longFrameIntervalCount(t) = ...
                sum(frameIntervals > 1.5*ifi);
            runData.presentation.estimatedDroppedRefreshCount(t) = ...
                sum(max(0,round(frameIntervals/ifi)-1));
            runData.presentation.maximumFrameIntervalSec(t) = ...
                max(frameIntervals);
        end
        runData.presentation.completed(t) = true;

        if tr.interStimulusSec > 0 && t < nTrials
            % Keep the already-flipped gray frame visible for at least the
            % requested interval. The next trial flips immediately after
            % this wait and does not schedule against the now-stale vbl.
            WaitSecs('UntilTime', ...
                runData.presentation.flipOffsetSec(t) + ...
                tr.interStimulusSec);
            flipImmediatelyAfterISI = true;
        end
    end

    % The final trial has already flipped the display back to gray. Keep
    % that gray frame visible after normal completion while TTL stays low.
    runData.blank.post.startedSec = ...
        runData.presentation.flipOffsetSec(nTrials);
    nPostRunBlankIntervals = max(0, ...
        round(cfg.display.postRunBlankSec/ifi));
    postRunFlipTimes = nan(nPostRunBlankIntervals,1);
    postRunMisses = zeros(nPostRunBlankIntervals,1);
    for blankFrame = 1:nPostRunBlankIntervals
        Screen('FillRect',win,cfg.display.backgroundGray);
        [vbl,postRunFlipTimes(blankFrame),~,postRunMisses(blankFrame)] = ...
            Screen('Flip',win,vbl+0.5*ifi);
        if ~isempty(progressFcn) && GetSecs >= nextProgressUpdateSec
            try
                progressUpdateStartedSec = GetSecs;
                progressFcn([],[]);
                progressUpdateDurationSec = GetSecs-progressUpdateStartedSec;
                runData.display.guiProgressUpdateCount = ...
                    runData.display.guiProgressUpdateCount+1;
                runData.display.guiProgressMaximumUpdateSec = max( ...
                    runData.display.guiProgressMaximumUpdateSec, ...
                    progressUpdateDurationSec);
            catch progressError
                runData.display.guiProgressDiagnostic = ...
                    string(progressError.message);
                progressFcn = [];
            end
            nextProgressUpdateSec = GetSecs+1;
        end
    end
    runData.blank.post.flipTimesSec = postRunFlipTimes;
    runData.blank.post.missedDeadlineCount = sum(postRunMisses > 0);
    if isempty(postRunFlipTimes)
        runData.blank.post.endedSec = ...
            runData.blank.post.startedSec;
    else
        runData.blank.post.endedSec = postRunFlipTimes(end);
    end
    runData.blank.post.actualSec = runData.blank.post.endedSec - ...
        runData.blank.post.startedSec;

    runData.display.screenReportedMissedFlipCount = ...
        sum(runData.presentation.missedFlipCount);
    runData.display.longFrameIntervalCount = ...
        sum(runData.presentation.longFrameIntervalCount);
    runData.display.estimatedDroppedRefreshCount = ...
        sum(runData.presentation.estimatedDroppedRefreshCount);
    totalPresentedFrames = sum(runData.presentation.framesPresented);
    runData.display.longFrameIntervalFraction = ...
        runData.display.longFrameIntervalCount / ...
        max(1,totalPresentedFrames);
    runData.display.maximumMissSec = ...
        max(runData.presentation.maximumMissSec);
    runData.display.maximumFrameIntervalSec = ...
        max(runData.presentation.maximumFrameIntervalSec);
    runData.status.completed = true;
    if runData.display.longFrameIntervalCount == 0
        runData.status.message = ...
            "Completed normally; no long frame intervals";
    else
        runData.status.message = sprintf( ...
            ['Completed with %d long frame interval(s), approximately %d ' ...
            'dropped refresh(es) (%.3f%% of frames).'], ...
            runData.display.longFrameIntervalCount, ...
            runData.display.estimatedDroppedRefreshCount, ...
            100*runData.display.longFrameIntervalFraction);
    end
catch ME
    if strcmp(ME.identifier, 'vstim:UserAbort')
        runData.status.aborted = true;
        runData.status.message = string(ME.message);
    else
        runData.status.message = string(getReport(ME, 'extended', ...
            'hyperlinks', 'off'));
    end
end

if ~isempty(ttl)
    ttl.low();
    runData.sync.endedLow = true;
    delete(ttl);
end
if keyboardQueueCreated
    try
        KbQueueStop;
        KbQueueRelease;
    catch
    end
end
Priority(0);
ShowCursor;
if ~isempty(win)
    Screen('CloseAll');
end

try
    runData.display.presentationQuality = ...
        vstim.assessPresentationQuality(runData);
    if runData.status.completed
        runData.status.message = ...
            runData.display.presentationQuality.summary;
    end
catch qualityError
    runData.display.presentationQuality = struct( ...
        'verdict',"UNAVAILABLE", ...
        'summary',"Presentation QC could not be calculated.", ...
        'diagnostic',string(qualityError.message));
end

runData.status.endedAt = datetime('now');
stamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
filename = vstim.stimulusRunFilename(cfg,stamp);
runData.status.savedFile = fullfile(cfg.session.outputDirectory, filename);
save(runData.status.savedFile, 'runData', '-v7.3');

if ~runData.status.completed && ~runData.status.aborted
    error('vstim:PresentationFailed', '%s', runData.status.message)
end
end
