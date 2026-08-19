function VisualAnalysisGUI
%VISUALANALYSISGUI Accumulate and compare spike RF maps for one cell.
% Runs are added sequentially. Each run retains its own stimulus and H5
% pairing and is analyzed independently before optional consensus fitting.

cellSession = newSession();
selectedRow = [];
consensusResult = [];
visibleRunIndices = [];
selectedDisplayMode = "Response / RF";
selectedTrialIndex = 1;
selectedConditionFilter = "All";

fig = uifigure('Name','In vivo patch RF quick analysis', ...
    'Position',[70 70 1600 900],'Color',[0.96 0.96 0.96]);
main = uigridlayout(fig,[4 2]);
main.RowHeight = {48,255,'1x',48};
main.ColumnWidth = {380,'1x'};
main.Padding = [12 12 12 12];
main.RowSpacing = 9;
main.ColumnSpacing = 12;

header = uigridlayout(main,[1 9]);
header.Layout.Row = 1;
header.Layout.Column = [1 2];
header.ColumnWidth = {55,140,70,165,95,95,110,105,'1x'};
uilabel(header,'Text','Cell ID','FontWeight','bold');
cellIdField = uieditfield(header,'text','Value','', ...
    'ValueChangedFcn',@cellIdChanged);
uilabel(header,'Text','Protocol','FontWeight','bold');
protocolDropDown = uidropdown(header,'Items',cellstr(protocolPages()), ...
    'Value','All protocols','ValueChangedFcn',@protocolPageChanged);
uibutton(header,'Text','Add run','ButtonPushedFcn',@addRunPressed);
uibutton(header,'Text','Load session','ButtonPushedFcn',@loadSessionPressed);
uibutton(header,'Text','Save session','ButtonPushedFcn',@saveSessionPressed);
replaceH5Button = uibutton(header,'Text','Replace H5', ...
    'Enable','off','ButtonPushedFcn',@replaceH5Pressed);
statusLabel = uilabel(header,'Text','Add the first stimulus run', ...
    'HorizontalAlignment','right','FontColor',[0.2 0.4 0.2]);

runPanel = uipanel(main,'Title','Runs loaded for this cell', ...
    'FontWeight','bold');
runPanel.Layout.Row = 2;
runPanel.Layout.Column = [1 2];
runGrid = uigridlayout(runPanel,[2 1]);
runGrid.RowHeight = {'1x',48};
runGrid.Padding = [10 8 10 10];
runGrid.RowSpacing = 8;
runTable = uitable(runGrid,'Data',emptyRunTable(), ...
    'ColumnName',{'#','Protocol','Stimulus run','WaveSurfer H5', ...
    'Status','RF center','Warnings'}, ...
    'ColumnWidth',{38,145,235,235,110,145,'1x'}, ...
    'RowName',{},'CellSelectionCallback',@runSelected);
actions = uigridlayout(runGrid,[1 4]);
actions.ColumnWidth = {145,145,170,'1x'};
actions.Padding = [0 3 0 3];
actions.ColumnSpacing = 10;
analyzeButton = uibutton(actions,'Text','Analyze selected run', ...
    'Enable','off','FontWeight','bold','FontSize',12, ...
    'BackgroundColor',[0.25 0.55 0.85],'FontColor',[1 1 1], ...
    'ButtonPushedFcn',@analyzeSelectedPressed);
viewButton = uibutton(actions,'Text','View selected result', ...
    'Enable','off','FontSize',12, ...
    'ButtonPushedFcn',@viewSelectedPressed);
consensusButton = uibutton(actions,'Text','Generate consensus RF', ...
    'Enable','off','FontWeight','bold','FontSize',12, ...
    'ButtonPushedFcn',@consensusPressed);
uilabel(actions,'Text', ...
    'Select a row, then edit that run''s parameters below.', ...
    'HorizontalAlignment','right','FontAngle','italic');

analysisTabs = uitabgroup(main);
analysisTabs.Layout.Row = 3;
analysisTabs.Layout.Column = 1;
parametersTab = uitab(analysisTabs,'Title','Analysis parameters');
metricsTab = uitab(analysisTabs,'Title','Data metrics');
resultsTab = uitab(analysisTabs,'Title','Results');
helpTab = uitab(analysisTabs,'Title','Help');
parametersGrid = uigridlayout(parametersTab,[2 1]);
parametersGrid.RowHeight = {42,'1x'};
parametersGrid.Padding = [10 10 10 10];
parametersGrid.RowSpacing = 8;
parameterTimingLabel = uilabel(parametersGrid,'Text', ...
    'Select a run to view its saved protocol settings.', ...
    'WordWrap','on','FontAngle','italic');
analysisTable = uitable(parametersGrid,'Data',cell(0,2), ...
    'ColumnName',{'Parameter','Value'},'ColumnEditable',[false true], ...
    'ColumnWidth',{160,'auto'},'RowName',{}, ...
    'CellEditCallback',@analysisParametersEdited);

metricsGrid = uigridlayout(metricsTab,[1 1]);
metricsGrid.Padding = [10 10 10 10];
metricsTable = uitable(metricsGrid,'Data',cell(0,2), ...
    'ColumnName',{'Metric','Value'},'ColumnEditable',[false false], ...
    'ColumnWidth',{170,'auto'},'RowName',{});

resultsGrid = uigridlayout(resultsTab,[1 1]);
resultsGrid.Padding = [10 10 10 10];
summaryArea = uitextarea(resultsGrid,'Editable','off','FontName','Menlo', ...
    'Value',{'Select a run in the table.'});

helpGrid = uigridlayout(helpTab,[1 1]);
helpGrid.Padding = [10 10 10 10];
uitextarea(helpGrid,'Editable','off','FontName','Menlo', ...
    'Value',analysisExplanation());

plots = uigridlayout(main,[1 2]);
plots.Layout.Row = 3;
plots.Layout.Column = 2;

runDisplayPanel = uipanel(plots,'BorderType','none');
runDisplayGrid = uigridlayout(runDisplayPanel,[2 1]);
runDisplayGrid.RowHeight = {32,'1x'};
runDisplayGrid.Padding = [0 0 0 0];
runDisplayGrid.RowSpacing = 4;
modeBar = uigridlayout(runDisplayGrid,[1 3]);
modeBar.ColumnWidth = {130,130,'1x'};
modeBar.Padding = [0 0 0 0];
responseModeButton = uibutton(modeBar,'Text','Response / RF', ...
    'ButtonPushedFcn',@(~,~) setDisplayMode("Response / RF"));
vmModeButton = uibutton(modeBar,'Text','Vm / Trials', ...
    'ButtonPushedFcn',@(~,~) setDisplayMode("Vm / Trials"));
uilabel(modeBar,'Text','');
runDisplayContent = uipanel(runDisplayGrid,'BorderType','none');

consensusAxes = uiaxes(plots);
title(consensusAxes,'Cell consensus');
updateModeButtonStyles();
placeholderLabel(runDisplayContent,'Selected run');

footer = uigridlayout(main,[1 2]);
footer.Layout.Row = 4;
footer.Layout.Column = [1 2];
footer.ColumnWidth = {'1x',360};
uilabel(footer,'Text', ...
    ['Each recording is analyzed independently. Consensus first combines ' ...
     'repeats within protocol family.']);
consensusLabel = uilabel(footer,'Text','No consensus generated', ...
    'HorizontalAlignment','right','FontWeight','bold');

    function addRunPressed(~,~)
        [file,path] = uigetfile('*.mat','Select saved stimulus run', ...
            'MultiSelect','off');
        if isequal(file,0)
            return
        end
        try
            filename = string(fullfile(path,file));
            runData = vstim.loadRun(filename);
            protocol = string(runData.params.protocol);
            if protocol == "Gabor + inverse stimuli"
                uialert(fig,['Classical, inverse, and full-field stimuli ' ...
                    'are intentionally left for offline analysis.'], ...
                    'Protocol not loaded');
                return
            end
            if any(string({cellSession.runs.runDataFile}) == filename)
                uialert(fig,'That stimulus run is already loaded.', ...
                    'Duplicate run');
                return
            end
            [h5File,pairing] = chooseH5ForRun(runData,filename);
            if strlength(h5File)==0
                return
            end
            entry = emptyRun();
            entry.runDataFile = filename;
            entry.waveSurferFile = h5File;
            entry.h5Pairing = pairing;
            entry.protocol = protocol;
            entry.parameterSummary = parameterSummary(runData);
            [entry.analysisOverrides,entry.stimulusTiming] = ...
                vstim.analysisOptionsForRun(runData);
            entry.status = "Ready";
            cellSession.runs(end+1) = entry;
            selectedRow = numel(cellSession.runs);
            if string(protocolDropDown.Value) ~= "All protocols"
                protocolDropDown.Value = char(protocolPage(protocol));
            end
            consensusResult = [];
            refreshTable();
            showSelectedRun();
            statusLabel.Text = "Added "+protocol;
        catch ME
            uialert(fig,ME.message,'Could not add stimulus run');
        end
    end

    function runSelected(~,event)
        if isempty(event.Indices)
            return
        end
        displayedRow = event.Indices(1);
        if displayedRow > numel(visibleRunIndices)
            return
        end
        selectedRow = visibleRunIndices(displayedRow);
        selectedTrialIndex = 1;
        selectedConditionFilter = "All";
        updateButtons();
        showSelectedRun();
    end

    function protocolPageChanged(~,~)
        selectedRow = [];
        refreshTable();
        showSelectedRun();
        statusLabel.Text = "Viewing "+string(protocolDropDown.Value);
    end

    function replaceH5Pressed(~,~)
        if isempty(selectedRow)
            return
        end
        [file,path] = uigetfile({'*.h5;*.hdf5', ...
            'WaveSurfer recordings (*.h5, *.hdf5)'}, ...
            'Select corresponding WaveSurfer file', ...
            char(fileparts(cellSession.runs(selectedRow).runDataFile)));
        if isequal(file,0)
            return
        end
        cellSession.runs(selectedRow).waveSurferFile = ...
            string(fullfile(path,file));
        cellSession.runs(selectedRow).h5Pairing = "Manual";
        cellSession.runs(selectedRow).analysisResult = [];
        cellSession.runs(selectedRow).status = "Ready";
        consensusResult = [];
        refreshTable();
        showSelectedRun();
    end

    function analyzeSelectedPressed(~,~)
        if isempty(selectedRow)
            return
        end
        entry = cellSession.runs(selectedRow);
        try
            requirePipelineFunctions();
            analyzeButton.Enable = 'off';
            statusLabel.Text = sprintf('Loading H5 for run %d…',selectedRow);
            statusLabel.FontColor = [0.75 0.35 0];
            drawnow;
            runData = vstim.loadRun(entry.runDataFile);
            data = vstim.loadWaveSurferForAnalysis( ...
                char(entry.waveSurferFile));
            statusLabel.Text = 'Running RF spike preprocessing…';
            drawnow;
            data = vstim.preprocessForAnalysis(data);
            statusLabel.Text = 'Estimating RF and bootstrap uncertainty…';
            drawnow;
            result = vstim.analyzeSpikeReceptiveField( ...
                runData,data,entry.analysisOverrides);
            result.runDataFile = entry.runDataFile;
            result.waveSurferFile = entry.waveSurferFile;
            result.preprocessing = ...
                'vstim.preprocessForAnalysis (RF-only)';
            statusLabel.Text = 'Building inspection views…';
            drawnow;
            % Reusing the same already-loaded/preprocessed data and the
            % same alignment convention analysisDataMetrics already
            % recomputes independently below - no second H5 load, and
            % this data goes out of scope once this callback returns (it
            % is never cached on the run entry; both display modes render
            % entirely from the lightweight products stored here).
            alignment = vstim.alignRecordedStimuli(runData,data);
            fullOptions = vstim.analysisOptions(runData,entry.analysisOverrides);
            inspection = struct();
            inspection.trialView = vstim.buildTrialInspection(runData,data,alignment);
            switch entry.protocol
                case "Moving bars"
                    inspection.responseView = vstim.analyzeMovingBarInspection( ...
                        runData,data,alignment,fullOptions,result);
                case "Fast Gabor tiling"
                    inspection.responseView = vstim.analyzeGaborMapInspection( ...
                        runData,data,alignment,fullOptions);
                otherwise
                    inspection.responseView = [];
            end
            cellSession.runs(selectedRow).analysisResult = result;
            cellSession.runs(selectedRow).inspectionResult = inspection;
            cellSession.runs(selectedRow).dataMetrics = ...
                vstim.analysisDataMetrics(runData,data,result);
            cellSession.runs(selectedRow).status = "Analyzed";
            selectedTrialIndex = 1;
            selectedConditionFilter = "All";
            consensusResult = [];
            refreshTable();
            showSelectedRun();
            statusLabel.Text = sprintf('Run %d analysis complete',selectedRow);
            statusLabel.FontColor = [0.2 0.4 0.2];
        catch ME
            cellSession.runs(selectedRow).status = "Error";
            refreshTable();
            statusLabel.Text = 'Analysis failed';
            statusLabel.FontColor = [0.8 0.1 0.1];
            uialert(fig,ME.message,'Analysis error');
        end
        updateButtons();
    end

    function viewSelectedPressed(~,~)
        showSelectedRun();
    end

    function consensusPressed(~,~)
        results = analyzedResults();
        try
            consensusResult = vstim.consensusReceptiveField(results);
            cellSession.consensusResult = consensusResult;
            plotConsensus();
            summaryArea.Value = cellstr(consensusSummary(consensusResult));
            consensusLabel.Text = sprintf( ...
                'Consensus: %.2f° az, %.2f° el', ...
                consensusResult.rfCenterAzimuthDeg, ...
                consensusResult.rfCenterElevationDeg);
            statusLabel.Text = 'Consensus RF generated';
        catch ME
            uialert(fig,ME.message,'Could not generate consensus');
        end
    end

    function saveSessionPressed(~,~)
        if isempty(cellSession.runs)
            uialert(fig,'Add at least one run before saving.', ...
                'Nothing to save');
            return
        end
        cellIdChanged([],[]);
        cellSession.updatedAt = datetime('now');
        cellSession.consensusResult = consensusResult;
        [folder,base] = fileparts(cellSession.runs(1).runDataFile);
        if strlength(cellSession.cellID)>0
            base = matlab.lang.makeValidName(char(cellSession.cellID));
        else
            base = base+"_cell";
        end
        suggested = fullfile(folder,string(base)+"_rf_session.mat");
        [file,path] = uiputfile('*.mat','Save cell analysis session',suggested);
        if isequal(file,0)
            return
        end
        cellAnalysisSession = cellSession;
        save(fullfile(path,file),'cellAnalysisSession','-v7.3');
        statusLabel.Text = "Saved session: "+string(fullfile(path,file));
    end

    function loadSessionPressed(~,~)
        [file,path] = uigetfile('*.mat','Load cell analysis session');
        if isequal(file,0)
            return
        end
        try
            loaded = load(fullfile(path,file),'cellAnalysisSession');
            if ~isfield(loaded,'cellAnalysisSession') || ...
                    ~isfield(loaded.cellAnalysisSession,'runs')
                error('vstim:InvalidCellSession', ...
                    'File does not contain a cell analysis session.')
            end
            cellSession = loaded.cellAnalysisSession;
            cellSession = relocateSessionFiles(cellSession,string(path));
            cellSession = upgradeSession(cellSession);
            if isfield(cellSession,'consensusResult')
                consensusResult = cellSession.consensusResult;
            else
                consensusResult = [];
            end
            cellIdField.Value = char(string(cellSession.cellID));
            selectedRow = [];
            refreshTable();
            showSelectedRun();
            if ~isempty(consensusResult)
                plotConsensus();
            end
            statusLabel.Text = 'Cell analysis session loaded';
        catch ME
            uialert(fig,ME.message,'Could not load session');
        end
    end

    function cellIdChanged(~,~)
        cellSession.cellID = string(cellIdField.Value);
    end

    function refreshTable()
        page = string(protocolDropDown.Value);
        if page == "All protocols"
            visibleRunIndices = 1:numel(cellSession.runs);
        else
            families = strings(numel(cellSession.runs),1);
            for runIndex = 1:numel(cellSession.runs)
                families(runIndex) = protocolPage( ...
                    cellSession.runs(runIndex).protocol);
            end
            visibleRunIndices = find(families==page)';
        end
        n = numel(visibleRunIndices);
        rows = cell(n,7);
        for displayedIndex = 1:n
            i = visibleRunIndices(displayedIndex);
            entry = cellSession.runs(i);
            rows{displayedIndex,1} = i;
            rows{displayedIndex,2} = char(entry.protocol);
            rows{displayedIndex,3} = char(shortName(entry.runDataFile));
            rows{displayedIndex,4} = char(shortName(entry.waveSurferFile));
            rows{displayedIndex,5} = char(entry.status);
            if isempty(entry.analysisResult)
                rows{displayedIndex,6} = '—';
                rows{displayedIndex,7} = entry.parameterSummary;
            else
                r = entry.analysisResult;
                if r.usableCenter
                    rows{displayedIndex,6} = sprintf('%.1f°, %.1f°', ...
                        r.rfCenterAzimuthDeg,r.rfCenterElevationDeg);
                else
                    rows{displayedIndex,6} = 'Unusable';
                end
                warningText = strjoin(r.warnings,'; ');
                if strlength(warningText)==0
                    warningText = "None";
                end
                rows{displayedIndex,7} = char(warningText);
            end
        end
        runTable.Data = rows;
        updateButtons();
    end

    function updateButtons()
        hasSelection = ~isempty(selectedRow) && ...
            selectedRow<=numel(cellSession.runs);
        setEnabled(analyzeButton,hasSelection);
        setEnabled(replaceH5Button,hasSelection);
        hasResult = hasSelection && ...
            ~isempty(cellSession.runs(selectedRow).analysisResult);
        setEnabled(viewButton,hasResult);
        setEnabled(consensusButton,numel(analyzedResults())>=2);
    end

    function showSelectedRun()
        clearContainer(runDisplayContent);
        if isempty(selectedRow) || selectedRow>numel(cellSession.runs)
            placeholderLabel(runDisplayContent,'Selected run');
            analysisTable.Data = cell(0,2);
            metricsTable.Data = cell(0,2);
            parameterTimingLabel.Text = ...
                'Select a run to view its saved protocol settings.';
            return
        end
        entry = cellSession.runs(selectedRow);
        analysisTable.Data = ...
            vstim.structToTableData(entry.analysisOverrides);
        parameterTimingLabel.Text = timingDescription(entry);
        if isempty(fieldnames(entry.dataMetrics))
            metricsTable.Data = stimulusMetrics(entry);
        else
            metricsTable.Data = vstim.structToTableData(entry.dataMetrics);
        end
        if isempty(entry.analysisResult)
            summaryArea.Value = cellstr([
                "Run "+selectedRow+": "+entry.protocol
                "Stimulus: "+entry.runDataFile
                "H5: "+entry.waveSurferFile
                "Pairing: "+entry.h5Pairing
                "Parameters: "+entry.parameterSummary
                "Status: "+entry.status]);
            placeholderLabel(runDisplayContent,'Run not analyzed');
            return
        end
        r = entry.analysisResult;
        summaryArea.Value = cellstr(resultSummary(r,selectedRow));
        if selectedDisplayMode == "Vm / Trials"
            renderTrialInspectionView(runDisplayContent,entry);
        else
            renderResponseRfView(runDisplayContent,entry);
        end
    end

    function setDisplayMode(mode)
        selectedDisplayMode = mode;
        updateModeButtonStyles();
        showSelectedRun();
    end

    function updateModeButtonStyles()
        highlightColor = [0.25 0.55 0.85];
        normalColor = [0.94 0.94 0.94];
        if selectedDisplayMode == "Vm / Trials"
            vmModeButton.BackgroundColor = highlightColor;
            vmModeButton.FontColor = [1 1 1];
            responseModeButton.BackgroundColor = normalColor;
            responseModeButton.FontColor = [0 0 0];
        else
            responseModeButton.BackgroundColor = highlightColor;
            responseModeButton.FontColor = [1 1 1];
            vmModeButton.BackgroundColor = normalColor;
            vmModeButton.FontColor = [0 0 0];
        end
    end

    function renderResponseRfView(container,entry)
        r = entry.analysisResult;
        hasResponseView = ~isempty(entry.inspectionResult) && ...
            ~isempty(entry.inspectionResult.responseView);
        switch entry.protocol
            case "Moving bars"
                if ~hasResponseView
                    placeholderLabel(container, ...
                        'Re-analyze this run to enable this view.');
                    return
                end
                renderMovingBarResponseView(container, ...
                    entry.inspectionResult.responseView,r);
            case "Fast Gabor tiling"
                if ~hasResponseView
                    placeholderLabel(container, ...
                        'Re-analyze this run to enable this view.');
                    return
                end
                renderGaborMapResponseView(container, ...
                    entry.inspectionResult.responseView,r);
            otherwise
                ax = singleAxesContainer(container);
                plotRunResult(ax,r);
        end
    end

    function renderMovingBarResponseView(container,inspection,r)
        directions = inspection.directions;
        nDirections = max(1,numel(directions));
        gridAxes = axesGrid(container,2,nDirections);
        [styleColor,styleLineStyle,styleNote] = vstim.rfOverlayStyle(r);
        polarityColors = containers.Map({-1,1},{[0.1 0.1 0.8],[0.8 0.1 0.1]});
        for d = 1:numel(directions)
            block = directions{d};
            rasterAxes = gridAxes(1,d);
            psthAxes = gridAxes(2,d);

            % Individual per-spike tick marks are not handle-hidden: on
            % uiaxes, HandleVisibility='off' excludes an object from
            % automatic axis-limit computation (not only from legends), so
            % hiding every raster tick left the axes at their unscaled
            % default [0,1] range with almost every real tick clipped out
            % of view. Neither axes here uses a legend, so there is no
            % downside to leaving every plotted object handle-visible.
            hold(rasterAxes,'on');
            rowCursor = 0;
            for p = 1:numel(block.polarities)
                pol = block.polarities{p};
                color = polarityColors(pol.polarity);
                for t = 1:numel(pol.spikePositionsDegByTrial)
                    rowCursor = rowCursor+1;
                    positions = pol.spikePositionsDegByTrial{t};
                    plot(rasterAxes,positions,rowCursor*ones(size(positions)), ...
                        '|','Color',color,'MarkerSize',6,'LineWidth',1);
                end
            end
            hold(rasterAxes,'off');
            ylabel(rasterAxes,'Trial');
            ylim(rasterAxes,[0,rowCursor+1]);
            title(rasterAxes,strrep(block.direction,'_',' '),'Interpreter','none');

            hold(psthAxes,'on');
            for p = 1:numel(block.polarities)
                pol = block.polarities{p};
                color = polarityColors(pol.polarity);
                valid = isfinite(pol.meanSpikesPerTrial);
                fill(psthAxes, ...
                    [pol.binCentersDeg(valid),fliplr(pol.binCentersDeg(valid))], ...
                    [pol.upperBandSpikesPerTrial(valid), ...
                     fliplr(pol.lowerBandSpikesPerTrial(valid))], ...
                    color,'FaceAlpha',0.2,'EdgeColor','none');
                plot(psthAxes,pol.binCentersDeg(valid),pol.meanSpikesPerTrial(valid), ...
                    '-','Color',color,'LineWidth',1.5);
            end
            if block.axis == "azimuth"
                profile = inspection.rfProfiles.azimuth;
                centerDeg = r.rfCenterAzimuthDeg;
            else
                profile = inspection.rfProfiles.elevation;
                centerDeg = r.rfCenterElevationDeg;
            end
            plot(psthAxes,profile.positionDeg,profile.gaussianPredictionHz, ...
                '--','Color',[0.3 0.3 0.3],'LineWidth',1);
            if isfinite(centerDeg)
                xline(psthAxes,centerDeg,styleLineStyle,'Color',styleColor, ...
                    'LineWidth',1.5,'Label',"RF ("+styleNote+")", ...
                    'LabelOrientation','horizontal','HandleVisibility','off');
            end
            hold(psthAxes,'off');
            xlabel(psthAxes,sprintf('%s position (deg)',block.axis));
            ylabel(psthAxes,'Spikes/trial');
            % Set an explicit x-range from the known bin-center span (shared
            % across polarities within one direction) rather than relying on
            % uiaxes' automatic scaling to resolve before linkaxes reads it:
            % linkaxes can lock in whichever XLim each axes currently
            % reports, and uiaxes' own auto-scale recompute is asynchronous,
            % so without this the shared range was sometimes still the
            % unscaled default when linked, clipping nearly all real data
            % out of view.
            xRangeDeg = [min(block.polarities{1}.binCentersDeg), ...
                max(block.polarities{1}.binCentersDeg)];
            xlim(rasterAxes,xRangeDeg);
            xlim(psthAxes,xRangeDeg);
            linkaxes([rasterAxes,psthAxes],'x');
        end
    end

    function renderGaborMapResponseView(container,inspection,r)
        % No continuous locator plot here - the cell consensus panel is
        % where the model's conclusion is shown as a real, continuous
        % azimuth/elevation position. This view stays purely about the raw
        % per-position response structure, but still marks the single grid
        % tile nearest the fitted center as a lightweight cross-reference
        % back to that conclusion.
        nAz = numel(inspection.azimuthAxisDeg);
        nEl = numel(inspection.elevationAxisDeg);
        gridAxes = axesGrid(container,nEl,nAz);
        [styleColor,styleLineStyle] = vstim.rfOverlayStyle(r);
        [nearestRow,nearestCol] = nearestGaborTile(r,inspection.azimuthAxisDeg, ...
            inspection.elevationAxisDeg,nEl);

        positionByCell = cell(nEl,nAz);
        sharedUpperLimit = 0;
        for i = 1:numel(inspection.positions)
            p = inspection.positions{i};
            col = find(inspection.azimuthAxisDeg==p.azimuthDeg);
            row = nEl-find(inspection.elevationAxisDeg==p.elevationDeg)+1;
            positionByCell{row,col} = p;
            sharedUpperLimit = max(sharedUpperLimit,max(p.upperBandHz,[],'omitnan'));
        end
        if ~isfinite(sharedUpperLimit) || sharedUpperLimit==0
            sharedUpperLimit = 1;
        end

        for row = 1:nEl
            for col = 1:nAz
                ax = gridAxes(row,col);
                p = positionByCell{row,col};
                if isempty(p)
                    axis(ax,'off');
                    continue
                end
                hold(ax,'on');
                fill(ax,[p.binCentersMs,fliplr(p.binCentersMs)], ...
                    [p.upperBandHz,fliplr(p.lowerBandHz)],[0.2 0.2 0.2], ...
                    'FaceAlpha',0.2,'EdgeColor','none');
                plot(ax,p.binCentersMs,p.meanRateHz,'-','Color',[0.2 0.2 0.2], ...
                    'LineWidth',1.2);
                xline(ax,0,'-','Color',[0 0 0]);
                xline(ax,inspection.responseWindowMs,':','Color',[0.3 0.3 0.3]);
                xline(ax,inspection.baselineWindowMs,':','Color',[0.6 0.6 0.6]);
                hold(ax,'off');
                xlim(ax,inspection.displayWindowMs);
                ylim(ax,[0,sharedUpperLimit]);
                title(ax,sprintf('%g, %g',p.azimuthDeg,p.elevationDeg),'FontSize',8);
                if row==nearestRow && col==nearestCol
                    rectangle(ax,'Position',[inspection.displayWindowMs(1),0, ...
                        diff(inspection.displayWindowMs),sharedUpperLimit], ...
                        'EdgeColor',styleColor,'LineWidth',2,'LineStyle',styleLineStyle);
                end
            end
        end
    end

    function renderTrialInspectionView(container,entry)
        inspection = entry.inspectionResult.trialView;
        layout = uigridlayout(container,[3 1]);
        layout.RowHeight = {'1x',40,'2x'};
        layout.Padding = [4 4 4 4];
        layout.RowSpacing = 6;

        overviewAxes = uiaxes(layout);
        ov = inspection.overview;
        plot(overviewAxes,ov.timeSec,ov.voltMv,'Color',[0.2 0.2 0.2],'DisplayName','V_m');
        hold(overviewAxes,'on');
        isBurst = ov.spikeIsBurst;
        plot(overviewAxes,ov.spikeTimesSec(~isBurst),ov.spikeVoltageMv(~isBurst), ...
            '.','Color',[0.1 0.1 0.8],'MarkerSize',6,'DisplayName','Isolated spike');
        plot(overviewAxes,ov.spikeTimesSec(isBurst),ov.spikeVoltageMv(isBurst), ...
            '.','Color',[0.8 0.1 0.1],'MarkerSize',6,'DisplayName','Burst spike');
        for i = 1:numel(ov.trialOnsetTimesSec)
            xline(overviewAxes,ov.trialOnsetTimesSec(i),'Color',[0.85 0.85 0.85], ...
                'HandleVisibility','off');
        end
        hold(overviewAxes,'off');
        xlabel(overviewAxes,'Time (s)');
        ylabel(overviewAxes,'Corrected V_m (mV)');
        title(overviewAxes,sprintf('%s — whole recording (%.0f s)', ...
            entry.protocol,ov.recordingDurationSec),'Interpreter','none');
        xlim(overviewAxes,[0,max(1,ov.recordingDurationSec)]);
        legend(overviewAxes,'Location','best');

        trials = inspection.trials;
        eligibleRows = eligibleTrialRows(trials,selectedConditionFilter);
        if isempty(eligibleRows) || ~ismember(selectedTrialIndex,eligibleRows)
            if isempty(eligibleRows)
                selectedTrialIndex = 1;
            else
                selectedTrialIndex = eligibleRows(1);
            end
        end

        controlBar = uigridlayout(layout,[1 5]);
        controlBar.ColumnWidth = {60,60,70,'1x',80};
        controlBar.Padding = [0 0 0 0];
        controlBar.ColumnSpacing = 6;
        uibutton(controlBar,'Text','◀ Prev','ButtonPushedFcn',@(~,~) stepTrial(-1));
        uibutton(controlBar,'Text','Next ▶','ButtonPushedFcn',@(~,~) stepTrial(1));
        uispinner(controlBar,'Limits',[1,height(trials)],'RoundFractionalValues','on', ...
            'Value',selectedTrialIndex,'ValueChangedFcn',@trialSpinnerChanged);
        conditionItems = unique(["All";trials.conditionLabel],'stable');
        uidropdown(controlBar,'Items',cellstr(conditionItems), ...
            'Value',char(selectedConditionFilter),'ValueChangedFcn',@conditionFilterChanged);
        % Short verdict word only (PASS/WARN/INCOMPLETE); the full sentence
        % does not fit this row, so it is a tooltip instead.
        uilabel(controlBar,'Text',inspection.stimulusTiming.verdict, ...
            'FontColor',verdictColor(inspection.stimulusTiming.verdict), ...
            'FontWeight','bold','HorizontalAlignment','right', ...
            'Tooltip',inspection.stimulusTiming.summary);

        trialAxes = uiaxes(layout);
        drawTrialWindow(trialAxes,inspection,selectedTrialIndex);
    end

    function stepTrial(delta)
        if isempty(selectedRow)
            return
        end
        entry = cellSession.runs(selectedRow);
        if isempty(entry.inspectionResult)
            return
        end
        trials = entry.inspectionResult.trialView.trials;
        eligibleRows = eligibleTrialRows(trials,selectedConditionFilter);
        if isempty(eligibleRows)
            return
        end
        currentPosition = find(eligibleRows==selectedTrialIndex,1);
        if isempty(currentPosition)
            currentPosition = 1;
        end
        newPosition = min(max(1,currentPosition+delta),numel(eligibleRows));
        selectedTrialIndex = eligibleRows(newPosition);
        showSelectedRun();
    end

    function conditionFilterChanged(dropdown,~)
        selectedConditionFilter = string(dropdown.Value);
        showSelectedRun();
    end

    function trialSpinnerChanged(spinner,~)
        selectedTrialIndex = round(spinner.Value);
        showSelectedRun();
    end

    function analysisParametersEdited(~,~)
        if isempty(selectedRow)
            return
        end
        try
            template = cellSession.runs(selectedRow).analysisOverrides;
            edited = vstim.tableDataToStruct(analysisTable.Data,template);
            validateAnalysisSettings( ...
                cellSession.runs(selectedRow).protocol,edited);
            cellSession.runs(selectedRow).analysisOverrides = edited;
            cellSession.runs(selectedRow).analysisResult = [];
            cellSession.runs(selectedRow).inspectionResult = [];
            cellSession.runs(selectedRow).dataMetrics = struct();
            cellSession.runs(selectedRow).status = "Ready";
            consensusResult = [];
            refreshTable();
            showSelectedRun();
            statusLabel.Text = 'Analysis parameters updated; rerun required';
            statusLabel.FontColor = [0.75 0.35 0];
        catch ME
            analysisTable.Data = vstim.structToTableData( ...
                cellSession.runs(selectedRow).analysisOverrides);
            uialert(fig,ME.message,'Invalid analysis parameter');
        end
    end

    function plotConsensus()
        resetPlotAxes(consensusAxes);
        hold(consensusAxes,'on');
        colors = lines(max(1,numel(cellSession.runs)));
        for i = 1:numel(cellSession.runs)
            r = cellSession.runs(i).analysisResult;
            if isempty(r) || ~r.usableCenter
                continue
            end
            plot(consensusAxes,r.rfCenterAzimuthDeg, ...
                r.rfCenterElevationDeg,'o','Color',colors(i,:), ...
                'MarkerFaceColor',colors(i,:),'DisplayName', ...
                sprintf('%d: %s',i,r.protocol));
            plotEllipse(consensusAxes,r.rfCenterAzimuthDeg, ...
                r.rfCenterElevationDeg,r.confidenceEllipse95, ...
                colors(i,:),'--');
        end
        plot(consensusAxes,consensusResult.rfCenterAzimuthDeg, ...
            consensusResult.rfCenterElevationDeg,'kp', ...
            'MarkerSize',15,'MarkerFaceColor','y', ...
            'DisplayName','Consensus');
        plotEllipse(consensusAxes,consensusResult.rfCenterAzimuthDeg, ...
            consensusResult.rfCenterElevationDeg, ...
            consensusResult.confidenceEllipse95,[0 0 0],'-');
        hold(consensusAxes,'off');
        xlabel(consensusAxes,'Azimuth (deg)');
        ylabel(consensusAxes,'Elevation (deg)');
        title(consensusAxes,sprintf( ...
            'Consensus (%d runs, %d families)', ...
            consensusResult.runCount,consensusResult.protocolFamilyCount));
        axis(consensusAxes,'equal');
        grid(consensusAxes,'on');
        legend(consensusAxes,'Location','best');
    end

    function results = analyzedResults()
        results = {};
        for runIndex = 1:numel(cellSession.runs)
            current = cellSession.runs(runIndex).analysisResult;
            if ~isempty(current) && isfield(current,'usableCenter') && ...
                    current.usableCenter
                results{end+1,1} = current; %#ok<AGROW>
            end
        end
    end
end

function session = newSession()
session.schemaVersion = "1.0.0";
session.cellID = "";
session.createdAt = datetime('now');
session.updatedAt = datetime('now');
session.runs = repmat(emptyRun(),0,1);
session.consensusResult = [];
end

function run = emptyRun()
run.runDataFile = "";
run.waveSurferFile = "";
run.h5Pairing = "";
run.protocol = "";
run.parameterSummary = "";
run.status = "";
run.analysisResult = [];
run.analysisOverrides = struct();
run.stimulusTiming = struct();
run.dataMetrics = struct();
run.inspectionResult = [];
end

function tableData = emptyRunTable()
tableData = cell(0,7);
end

function pages = protocolPages()
pages = ["All protocols","Moving bars","Flashed bars","Sparse noise", ...
    "Fast Gabor tiling","Targeted Gabor grid"];
end

function page = protocolPage(protocol)
page = string(protocol);
end

function session = upgradeSession(session)
template = emptyRun();
names = fieldnames(template);
invalidatedLegacyResult = false;
for i = 1:numel(session.runs)
    for j = 1:numel(names)
        if ~isfield(session.runs(i),names{j})
            session.runs(i).(names{j}) = template.(names{j});
        end
    end
    if isempty(session.runs(i).analysisOverrides)
        session.runs(i).analysisOverrides = struct();
    end
    if isempty(session.runs(i).stimulusTiming)
        session.runs(i).stimulusTiming = struct();
    end
    if isempty(session.runs(i).dataMetrics)
        session.runs(i).dataMetrics = struct();
    end
    if isempty(fieldnames(session.runs(i).analysisOverrides))
        try
            runData = vstim.loadRun(session.runs(i).runDataFile);
            [session.runs(i).analysisOverrides, ...
                session.runs(i).stimulusTiming] = ...
                vstim.analysisOptionsForRun(runData);
        catch
            % Preserve the older session even if a referenced run moved.
        end
    end
    result = session.runs(i).analysisResult;
    if ~isempty(result) && (~isfield(result,'fitSuccessful') || ...
            ~isfield(result,'responseDynamicRange'))
        session.runs(i).analysisResult = [];
        session.runs(i).dataMetrics = struct();
        session.runs(i).status = "Ready — reanalyze with quality gates";
        invalidatedLegacyResult = true;
    end
end
if invalidatedLegacyResult
    session.consensusResult = [];
end
end

function session = relocateSessionFiles(session,sessionFolder)
% Saved sessions may be copied between macOS and Windows. If an absolute
% pointer no longer exists, look for the same filename beside the session.
for i = 1:numel(session.runs)
    if ~isfile(session.runs(i).runDataFile)
        candidate = fullfile(sessionFolder, ...
            shortName(session.runs(i).runDataFile));
        if isfile(candidate)
            session.runs(i).runDataFile = string(candidate);
        end
    end
    if ~isfile(session.runs(i).waveSurferFile)
        candidate = fullfile(sessionFolder, ...
            shortName(session.runs(i).waveSurferFile));
        if isfile(candidate)
            session.runs(i).waveSurferFile = string(candidate);
        end
    end
end
end

function description = timingDescription(entry)
t = entry.stimulusTiming;
if isempty(fieldnames(t))
    description = 'Stimulus timing is unavailable.';
    return
end
description = sprintf( ...
    'Stimulus %.1f ms; blank %.1f ms; minimum onset interval %.1f ms. %s', ...
    t.medianStimulusDurationMs,t.medianInterStimulusMs, ...
    t.minimumOnsetIntervalMs,t.windowAdjustment);
end

function tableData = stimulusMetrics(entry)
t = entry.stimulusTiming;
metrics.protocol = entry.protocol;
metrics.parameterSummary = entry.parameterSummary;
if ~isempty(fieldnames(t))
    metrics.medianStimulusDurationMs = t.medianStimulusDurationMs;
    metrics.minimumStimulusDurationMs = t.minimumStimulusDurationMs;
    metrics.medianInterStimulusMs = t.medianInterStimulusMs;
    metrics.minimumInterStimulusMs = t.minimumInterStimulusMs;
    metrics.minimumOnsetIntervalMs = t.minimumOnsetIntervalMs;
    metrics.windowAdjustment = t.windowAdjustment;
end
metrics.analysisStatus = entry.status;
tableData = vstim.structToTableData(metrics);
end

function validateAnalysisSettings(protocol,options)
mustBeFinitePositiveInteger(options.bootstrapRepetitions, ...
    'bootstrapRepetitions',20);
mustBeFinitePositiveInteger(options.randomSeed,'randomSeed',0);
mustBePositiveScalar(options.minimumPeakResponseHz, ...
    'minimumPeakResponseHz');
mustBePositiveScalar(options.minimumResponseDynamicRangeHz, ...
    'minimumResponseDynamicRangeHz');
if ~isscalar(options.minimumFitQuality) || ...
        ~isfinite(options.minimumFitQuality) || ...
        options.minimumFitQuality<0 || options.minimumFitQuality>1
    error('vstim:InvalidAnalysisParameter', ...
        'minimumFitQuality must be between 0 and 1.')
end
protocol = string(protocol);
if any(protocol==["Flashed bars","Fast Gabor tiling", ...
        "Targeted Gabor grid"])
    validateWindow(options.responseWindowMs,'responseWindowMs');
    validateWindow(options.baselineWindowMs,'baselineWindowMs');
    if options.responseWindowMs(1)<0
        error('vstim:InvalidAnalysisWindow', ...
            'The response window must begin at or after stimulus onset.')
    end
    if options.baselineWindowMs(2)>0
        error('vstim:InvalidAnalysisWindow', ...
            'The baseline window must end at or before stimulus onset.')
    end
elseif protocol=="Moving bars"
    validateWindow(options.spikeLatencyRangeMs,'spikeLatencyRangeMs');
    mustBePositiveScalar(options.spikeBinMs,'spikeBinMs');
    mustBePositiveScalar(options.positionBinDeg,'positionBinDeg');
    mustBeFinitePositiveInteger(options.minimumSweeps,'minimumSweeps',1);
elseif protocol=="Sparse noise"
    if isempty(options.testedLagsMs) || ...
            any(~isfinite(options.testedLagsMs)) || ...
            any(options.testedLagsMs<0)
        error('vstim:InvalidAnalysisParameter', ...
            'testedLagsMs must contain finite nonnegative values.')
    end
    mustBePositiveScalar(options.spikeBinMs,'spikeBinMs');
    if ~isscalar(options.regularizationStrength) || ...
            ~isfinite(options.regularizationStrength) || ...
            options.regularizationStrength<0
        error('vstim:InvalidAnalysisParameter', ...
            'regularizationStrength must be nonnegative.')
    end
    mustBeFinitePositiveInteger(options.crossValidationFolds, ...
        'crossValidationFolds',2);
end
end

function validateWindow(value,name)
if ~isnumeric(value) || numel(value)~=2 || any(~isfinite(value)) || ...
        value(2)<=value(1)
    error('vstim:InvalidAnalysisWindow', ...
        '%s must be a two-element increasing numeric window.',name)
end
end

function mustBePositiveScalar(value,name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value<=0
    error('vstim:InvalidAnalysisParameter', ...
        '%s must be a positive scalar.',name)
end
end

function mustBeFinitePositiveInteger(value,name,minimum)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value<minimum || value~=round(value)
    error('vstim:InvalidAnalysisParameter', ...
        '%s must be an integer of at least %d.',name,minimum)
end
end

function [h5File,pairing] = chooseH5ForRun(runData,runDataFile)
detected = vstim.detectedH5ForRun(runData);
h5File = "";
pairing = "";
if strlength(detected)>0 && isfile(detected)
    choice = questdlg(sprintf( ...
        'The stimulus run points to this WaveSurfer file:\n\n%s',detected), ...
        'WaveSurfer file detected','Load detected H5', ...
        'Choose different H5','Cancel','Load detected H5');
    if strcmp(choice,'Load detected H5')
        h5File = detected;
        pairing = "Metadata";
        return
    elseif ~strcmp(choice,'Choose different H5')
        return
    end
elseif strlength(detected)>0
    uiwait(warndlg(['The H5 saved in the run metadata was not found. ' ...
        'Select the corresponding H5 manually.'],'H5 not found','modal'));
end
[file,path] = uigetfile({'*.h5;*.hdf5', ...
    'WaveSurfer recordings (*.h5, *.hdf5)'}, ...
    'Select corresponding WaveSurfer file',char(fileparts(runDataFile)));
if ~isequal(file,0)
    h5File = string(fullfile(path,file));
    pairing = "Manual";
end
end

function requirePipelineFunctions()
projectRoot = fileparts(mfilename('fullpath'));
vendorRoot = fullfile(projectRoot,'vendor','in_vivo_patch');
addpath(genpath(vendorRoot));
addpath(projectRoot,'-begin');
missing = strings(0,1);
if isempty(which('loadws')), missing(end+1) = "loadws"; end
if isempty(which('loadDataFile')), missing(end+1) = "loadDataFile"; end
if isempty(which('preprocess')), missing(end+1) = "preprocess"; end
if isempty(missing)
    return
end
error('vstim:BundledPipelineMissing', ...
    'Package-local analysis files are missing: %s',strjoin(missing,', '))
end

function summary = parameterSummary(runData)
p = runData.params.stimulus;
protocol = string(runData.params.protocol);
switch protocol
    case "Moving bars"
        summary = sprintf('%.1f° bar, %.1f°/s, %d repeats', ...
            p.barWidthDeg,p.barSpeedDegPerSec,p.repetitionsPerCondition);
    case "Flashed bars"
        summary = sprintf('%.1f° bar, %.1f° spacing, %d repeats', ...
            p.barWidthDeg,p.positionSpacingDeg,p.repetitionsPerCondition);
    case "Sparse noise"
        summary = sprintf('%.1f° tiles, %.0f s', ...
            p.tileSizeDeg(1),p.totalDurationSec);
    case {"Fast Gabor tiling","Targeted Gabor grid"}
        summary = sprintf('%.1f° patch, %.3f cyc/°, %d repeats', ...
            p.diameterDeg,p.spatialFrequencyCyclesPerDeg, ...
            p.repetitionsPerCondition);
    otherwise
        summary = char(protocol);
end
end

function plotRunResult(ax,result)
resetPlotAxes(ax);
if isfield(result.maps,'combined') && istable(result.maps.combined)
    map = result.maps.combined;
    if ismember('combinedWeight',map.Properties.VariableNames)
        value = map.combinedWeight;
    else
        value = map.responseHz;
    end
    scatter(ax,map.azimuthDeg,map.elevationDeg,90,value,'filled');
    colorbar(ax);
    if result.usableCenter
        hold(ax,'on');
        plot(ax,result.rfCenterAzimuthDeg,result.rfCenterElevationDeg, ...
            'rx','MarkerSize',14,'LineWidth',2);
        plotEllipse(ax,result.rfCenterAzimuthDeg, ...
            result.rfCenterElevationDeg,result.confidenceEllipse95, ...
            [0.8 0 0],'-');
        hold(ax,'off');
    end
    xlabel(ax,'Azimuth (deg)');
    ylabel(ax,'Elevation (deg)');
    axis(ax,'equal');
elseif isfield(result.profiles,'azimuth')
    p = result.profiles.azimuth;
    q = result.profiles.elevation;
    azSizes = responseMarkerSizes(p.combinedResponseHz);
    elSizes = responseMarkerSizes(q.combinedResponseHz);
    scatter(ax,p.positionDeg, ...
        repmat(result.rfCenterElevationDeg,height(p),1), ...
        azSizes,[0.1 0.45 0.85],'filled','DisplayName','Azimuth profile');
    hold(ax,'on');
    scatter(ax,repmat(result.rfCenterAzimuthDeg,height(q),1), ...
        q.positionDeg,elSizes,[0.2 0.65 0.3],'filled', ...
        'DisplayName','Elevation profile');
    if result.usableCenter
        plot(ax,result.rfCenterAzimuthDeg,result.rfCenterElevationDeg, ...
            'rx','MarkerSize',14,'LineWidth',2,'DisplayName','RF center');
        plotEllipse(ax,result.rfCenterAzimuthDeg, ...
            result.rfCenterElevationDeg,result.confidenceEllipse95, ...
            [0.8 0 0],'-');
    end
    hold(ax,'off');
    xlabel(ax,'Azimuth position (deg)');
    ylabel(ax,'Elevation position (deg)');
    axis(ax,'equal');
    grid(ax,'on');
    legend(ax,'Location','best');
end
if result.usableCenter
    title(ax,string(result.protocol)+" spike RF");
else
    title(ax,string(result.protocol)+" — unusable RF estimate");
end
end

function resetPlotAxes(ax)
% A normal cla preserves children with HandleVisibility='off'. Confidence
% ellipses use hidden handles to stay out of legends, so use reset to ensure
% old RF outlines cannot accumulate between run/protocol redraws.
colorbar(ax,'off');
cla(ax,'reset');
end

function clearContainer(container)
% Delete every child of a display container before rebuilding it: unlike
% resetPlotAxes (one fixed uiaxes, cleared in place), the selected-run
% display container's content varies in shape between protocols/modes -
% a single uiaxes, a grid of uiaxes, or the Vm/Trials controls+axes - so
% it is rebuilt from scratch on every showSelectedRun() call instead.
delete(container.Children);
end

function placeholderLabel(container,text)
layout = uigridlayout(container,[1 1]);
layout.Padding = [0 0 0 0];
uilabel(layout,'Text',text,'HorizontalAlignment','center','FontAngle','italic');
end

function ax = singleAxesContainer(container)
% One uiaxes, grid-managed so it fills its container the same way the
% original fixed runAxes filled its own uigridlayout cell.
layout = uigridlayout(container,[1 1]);
layout.Padding = [0 0 0 0];
ax = uiaxes(layout);
end

function axesHandles = axesGrid(container,rows,cols)
% A rows x cols grid of small-multiple uiaxes: the only way to get small
% multiples inside a uifigure (no tiledlayout/subplot/bare-figure
% alternative is used anywhere in this app).
layout = uigridlayout(container,[rows,cols]);
layout.Padding = [4 4 4 4];
layout.RowSpacing = 4;
layout.ColumnSpacing = 4;
axesHandles = gobjects(rows,cols);
for r = 1:rows
    for c = 1:cols
        axesHandles(r,c) = uiaxes(layout);
    end
end
end

function [row,col] = nearestGaborTile(result,azimuthAxisDeg,elevationAxisDeg,nEl)
% The (row,col) of the spatial PSTH grid closest to result's fitted
% center, using the same elevation-flip convention as the grid itself
% (highest tested elevation at row 1). Returns (0,0) - never a real tile -
% when no finite center is available, so the caller's equality check
% simply never highlights a tile.
row = 0; col = 0;
if ~isfinite(result.rfCenterAzimuthDeg) || ~isfinite(result.rfCenterElevationDeg)
    return
end
[~,col] = min(abs(azimuthAxisDeg-result.rfCenterAzimuthDeg));
[~,elevationIndex] = min(abs(elevationAxisDeg-result.rfCenterElevationDeg));
row = nEl-elevationIndex+1;
end

function rows = eligibleTrialRows(trials,filterLabel)
if filterLabel == "All"
    rows = (1:height(trials))';
else
    rows = find(trials.conditionLabel==filterLabel);
end
end

function drawTrialWindow(ax,inspection,trialIndex)
row = inspection.trials(trialIndex,:);
timeMs = inspection.trialWindowTimeMs;
isBurst = row.spikeIsBurst{1};
% Not handle-hidden: on uiaxes that also excludes it from automatic
% Y-limit computation, which could clip the trace to whatever narrow
% range the spike markers alone happen to span. Giving it a DisplayName
% keeps it out of an ugly auto-generated legend entry instead.
plot(ax,timeMs,row.vmMv,'Color',[0.2 0.2 0.2],'DisplayName','V_m');
hold(ax,'on');
plot(ax,row.spikeTimesMs{1}(~isBurst),row.spikeVoltageMv{1}(~isBurst),'.', ...
    'Color',[0.1 0.1 0.8],'MarkerSize',10,'DisplayName','Isolated spike');
plot(ax,row.spikeTimesMs{1}(isBurst),row.spikeVoltageMv{1}(isBurst),'.', ...
    'Color',[0.8 0.1 0.1],'MarkerSize',10,'DisplayName','Burst spike');
xline(ax,0,'-','Color',[0 0 0],'HandleVisibility','off');
hold(ax,'off');
xlabel(ax,'Time since trial onset (ms)');
ylabel(ax,'Corrected V_m (mV)');
title(ax,sprintf('Trial %d/%d — %s',trialIndex,height(inspection.trials), ...
    row.conditionLabel),'Interpreter','none');
xlim(ax,[timeMs(1),timeMs(end)]);
legend(ax,'Location','best');
end

function color = verdictColor(verdict)
switch verdict
    case "PASS"
        color = [0.2 0.5 0.2];
    case "WARN"
        color = [0.75 0.35 0];
    otherwise
        color = [0.6 0.6 0.6];
end
end

function plotEllipse(ax,azimuth,elevation,ellipse,color,lineStyle)
if ~isfinite(ellipse.semiMajorDeg)
    return
end
t = linspace(0,2*pi,100);
points = [ellipse.semiMajorDeg*cos(t);ellipse.semiMinorDeg*sin(t)];
angle = deg2rad(ellipse.angleDeg);
rotation = [cos(angle),-sin(angle);sin(angle),cos(angle)];
points = rotation*points;
plot(ax,points(1,:)+azimuth,points(2,:)+elevation, ...
    'Color',color,'LineStyle',lineStyle,'LineWidth',1.3, ...
    'HandleVisibility','off');
end

function text = resultSummary(result,index)
text = "Run "+index+": "+result.protocol;
if result.usableCenter
    text = [text
        sprintf('Center: az %.2f°, el %.2f°', ...
            result.rfCenterAzimuthDeg,result.rfCenterElevationDeg)
        sprintf('95%% uncertainty radius: %.2f°',result.uncertaintyRadiusDeg)];
else
    text = [text
        "Center: WITHHELD — response/fit quality checks failed"
        "95% uncertainty: not reported for an unusable fit"];
end
text = [text
    sprintf('Fit quality: %.3f',result.fitQuality)
    sprintf('Response dynamic range: %.3f',result.responseDynamicRange)
    sprintf('Split-half reliability: %.3f',result.splitHalfReliability)
    sprintf('Matched trials: %d',result.trialCount)
    "Edge warning: "+string(result.edgeWarning)
    "Usable center: "+string(result.usableCenter)];
if isfield(result,'peakLagMs') && isfinite(result.peakLagMs)
    text(end+1) = sprintf('Peak response lag: %.1f ms',result.peakLagMs);
end
if ~isempty(result.warnings)
    text = [text;"Warnings:";"  "+result.warnings(:)];
end
end

function sizes = responseMarkerSizes(response)
response = max(double(response(:)),0);
if isempty(response) || max(response)==0
    sizes = repmat(25,size(response));
else
    sizes = 25+125*response/max(response);
end
end

function text = consensusSummary(result)
text = [
    "CELL CONSENSUS RF"
    sprintf('Center: az %.2f°, el %.2f°', ...
        result.rfCenterAzimuthDeg,result.rfCenterElevationDeg)
    sprintf('95%% uncertainty radius: %.2f°',result.uncertaintyRadiusDeg)
    sprintf('Runs: %d',result.runCount)
    sprintf('Protocol families: %d',result.protocolFamilyCount)
    sprintf('Reduced disagreement: %.2f',result.reducedDisagreement)
    sprintf('Uncertainty inflation: %.2fx',result.inflationFactor)];
if ~isempty(result.warnings)
    text = [text;"Warnings:";"  "+result.warnings(:)];
end
end

function value = shortName(filename)
[~,name,extension] = fileparts(filename);
value = string(name)+string(extension);
end

function setEnabled(control,value)
if value, control.Enable='on'; else, control.Enable='off'; end
end

function lines = analysisExplanation()
lines = {
    'Sequential cell workflow'
    ''
    '1. Add a stimulus run and confirm its H5.'
    '2. Analyze the selected run.'
    '3. Add later mapping runs to the same table.'
    '4. Generate consensus when at least two runs are usable.'
    '5. Save the cell session to continue later.'
    ''
    'Consensus hierarchy'
    '• Every recording is fitted independently.'
    '• Repeats combine within mapping-protocol family.'
    '• Protocol families then combine by center covariance.'
    '• Excess disagreement inflates the reported uncertainty.'
    '• All component estimates remain visible.'
    ''
    'Gabor orientations are pooled, and classical/inverse/full-field'
    'responses are not analyzed in this quick-look application.'
    };
end
