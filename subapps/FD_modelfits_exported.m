classdef FD_modelfits_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        DatafittingUIFigure       matlab.ui.Figure
        FitresultsPanel           matlab.ui.container.Panel
        ModelLabel                matlab.ui.control.Label
        prefixunitsSwitch         matlab.ui.control.Switch
        prefixunitsSwitchLabel    matlab.ui.control.Label
        ShowFitStatsButton        matlab.ui.control.Button
        UITable2                  matlab.ui.control.Table
        ModelsPanel               matlab.ui.container.Panel
        EditModelsButton          matlab.ui.control.Button
        ResEditField              matlab.ui.control.NumericEditField
        ResEditFieldLabel         matlab.ui.control.Label
        yUnitLabel                matlab.ui.control.Label
        xUnitLabel                matlab.ui.control.Label
        evaluateatEditField       matlab.ui.control.EditField
        evaluateatEditFieldLabel  matlab.ui.control.Label
        TestButton                matlab.ui.control.Button
        DescriptionTextArea       matlab.ui.control.TextArea
        DescriptionTextAreaLabel  matlab.ui.control.Label
        FormulaEditField          matlab.ui.control.EditField
        FormulaEditFieldLabel     matlab.ui.control.Label
        ModelparametersLabel      matlab.ui.control.Label
        UITable                   matlab.ui.control.Table
        ModeldetailsLabel         matlab.ui.control.Label
        AvailablefitmodelsLabel   matlab.ui.control.Label
        AvailableFitModelsTree    matlab.ui.container.Tree
        SelectdataPanel           matlab.ui.container.Panel
        datapartButtonGroup       matlab.ui.container.ButtonGroup
        SelectButton              matlab.ui.control.Button
        manualselectButton        matlab.ui.control.RadioButton
        allbutBLButton            matlab.ui.control.RadioButton
        CPendButton               matlab.ui.control.RadioButton
        directionButtonGroup      matlab.ui.container.ButtonGroup
        retractButton             matlab.ui.control.RadioButton
        approachButton            matlab.ui.control.RadioButton
        FitButton                 matlab.ui.control.Button
        ModelsContextMenu         matlab.ui.container.ContextMenu
        newMenu                   matlab.ui.container.Menu
        editMenu                  matlab.ui.container.Menu
        saveMenu                  matlab.ui.container.Menu
    end

    
    properties (Access = private)
        MainApp
        subfigs = struct('Datafit', [], 'ModelEval', []) % struct of subfigures: Datafit & ModelEval
    end
    
    properties (Access = public)
        fit_models % Description
        last_fit
        dataPointsSelection
    end
    
    methods (Access = private)
        
        function fillResultsTableWithFit(app, fitres)

            if isempty(fitres)
                app.UITable2.Data = [];
                return
            end

            freeParIdx = ~fitres.model.parameter_isfixed;

            app.UITable2.Data = table(...
                'Size', [sum(freeParIdx), 3] ...
                ,'VariableTypes', {'double', 'double', 'double'}...
                ,'RowNames', fitres.model.parameters(freeParIdx)'...
                ,'VariableNames', {'value','U error','L error'}...
                );
            app.UITable2.ColumnName = app.UITable2.Data.Properties.VariableNames;
            if strcmp(app.prefixunitsSwitch.Value, 'On')
                app.UITable2.Data.value(:) = fitres.paramRes .* 10.^(-fitres.model.parameterNexponents(freeParIdx));
                app.UITable2.Data.('U error')(:) = fitres.errors(2,:) .* 10.^(-fitres.model.parameterNexponents(freeParIdx));
                app.UITable2.Data.('L error')(:) = fitres.errors(1,:) .* 10.^(-fitres.model.parameterNexponents(freeParIdx));
                app.UITable2.RowName = cellfun(@(x,y) [x, ' / ' y], fitres.model.parameters(freeParIdx), fitres.model.parameterNdims(freeParIdx), 'UniformOutput',false);
                %app.UITable2.Data.Unit(:) = fitres.model.parameterNdims(freeParIdx);
            else
                app.UITable2.Data.value = fitres.paramRes';
                app.UITable2.Data.('U error') = fitres.errors(2,:)';
                app.UITable2.Data.('L error') = fitres.errors(1,:)';
                app.UITable2.RowName = cellfun(@(x,y) [x, ' / ' y], fitres.model.parameters(freeParIdx), fitres.model.parameterdims(freeParIdx), 'UniformOutput',false);
                %app.UITable2.Data.Unit(:) = fitres.model.parameterdims(freeParIdx);
            end
        end
        
        
        
        function plotModelFit(app, fitres)

            if isempty(app.subfigs.Datafit) || ~isgraphics(app.subfigs.Datafit)
                app.subfigs.Datafit = uifigure();
                ah = axes(app.subfigs.Datafit);
            else
                ah = findobj(app.subfigs.Datafit.Children, 'Type', 'Axes');
            end

            if numel(app.MainApp.iSelectedData) > 1
            else
                %dataIdxs = 6; %TODO!
                expIdxs = app.MainApp.iSelectedData;
            end



            %get xdata and ydata.
            if istable(fitres.data)
                xData = fitres.data.x;
                yData = fitres.data.y;
            else
                exper = app.MainApp.Data(expIdxs);
                xData = exper.(fitres.trace).(fitres.xchannel)(fitres.data);
                yData = exper.(fitres.trace).(fitres.ychannel)(fitres.data);
            end



            fitres.plot(ah, 'XData', xData, 'YData', yData);
            title(ah, ['Fit result for ' app.MainApp.DataNames{expIdxs}], "Interpreter","none");
            app.subfigs.Datafit.Name = ['Fit result'];
            app.ModelLabel.Text = ['Model: ' fitres.model.ID];
            legend(ah,"show", "Location","best");

        end
        
        function modelSelectionChanged(app)
            %get actual model
            if isempty(app.AvailableFitModelsTree.SelectedNodes)
                model_no = [];
            else
                model_no = app.AvailableFitModelsTree.SelectedNodes.NodeData;
            end
            
            if isempty(model_no)
                app.fillResultsTableWithFit([]);
                if ~isempty(app.subfigs.Datafit) && isgraphics(app.subfigs.Datafit)
                    ah = findobj(app.subfigs.Datafit.Children, 'Type', 'Axes');
                    cla(ah);
                end
                app.FormulaEditField.Value = '';
                app.DescriptionTextArea.Value = '';

                app.yUnitLabel.Text = '';
                app.xUnitLabel.Text = '';
                app.TestButton.Enable = 'off';
                app.FitButton.Enable = 'off';
                app.UITable.Data = table();
                return
            end

            actModel = app.fit_models(model_no);
            %check if fit with actual model for actual data exists
            selData = app.MainApp.Data(app.MainApp.iSelectedData);
            if isscalar(selData)
                if isempty(selData.DataFits)
                    fitIdx = [];
                else
                    fitIdx = find(arrayfun(@(x) strcmp(actModel.ID,x.model.ID), selData.DataFits),1 );
                end
            end
            if ~isscalar(selData) || isempty(fitIdx) %if not: clear result table and plot
                app.fillResultsTableWithFit([]);
                if ~isempty(app.subfigs.Datafit) && isgraphics(app.subfigs.Datafit)
                    ah = findobj(app.subfigs.Datafit.Children, 'Type', 'Axes');
                    cla(ah);
                end
            else %if yes: load start configuration of fit, show results in table and plot
                oldFit = app.MainApp.Data(app.MainApp.iSelectedData).DataFits(fitIdx);
                actModel = oldFit.model;
                app.fillResultsTableWithFit(oldFit);
                app.plotModelFit(oldFit);

                if strcmp(oldFit.trace, 'ap')
                    app.directionButtonGroup.SelectedObject = app.approachButton;
                else
                    app.directionButtonGroup.SelectedObject = app.retractButton;
                end

                if ~istable(oldFit.data) 
                    %check indices of fitted data
                    CPIdxs = selData.(oldFit.trace).iCP(1)+1;
                    noBLIdxs = selData.(oldFit.trace).iBl(2)+1;
                    numelIdx = numel(selData.(oldFit.trace).(oldFit.xchannel));
                    if isequaln(oldFit.data,  (CPIdxs:numelIdx))
                        app.datapartButtonGroup.SelectedObject = app.CPendButton;
                    elseif isequaln(oldFit.data,  (noBLIdxs:numelIdx))
                        app.datapartButtonGroup.SelectedObject = app.allbutBLButton;
                    else
                        app.datapartButtonGroup.SelectedObject = app.manualselectButton;
                    end
                end

            end
            
            app.FormulaEditField.Value = [actModel.dependent '(' actModel.independent ') = '  actModel.funcStr];
            app.DescriptionTextArea.Value = actModel.description;

            app.TestButton.Enable = "on";
            app.FitButton.Enable = "on";
            app.yUnitLabel.Text = actModel.dependentdim;
            app.xUnitLabel.Text = actModel.independentdim;
            app.UITable.Data = table(...actModel.parametervalues, actModel.parameter_isfixed...
                'Size', [numel(actModel.parameters), 4] ...
                ,'VariableTypes', {'double', 'logical', 'double', 'double'}...
                ,'RowNames', actModel.parameters'...
                ,'VariableNames', {'value','fix?','L bound','U bound'}...
                );
             app.UITable.Data.value = actModel.parametervalues';
             app.UITable.Data.(2) = actModel.parameter_isfixed';
             
             app.UITable.Data.('L bound') = actModel.parameter_lbounds';
             app.UITable.Data.('U bound') = actModel.parameter_ubounds';
             
             app.UITable.RowName = cellfun(@(x,y) [x, ' / ' y], actModel.parameters, actModel.parameterdims, 'UniformOutput',false);
             app.UITable.ColumnEditable = true(1,4);
             if iscell(actModel.inputfunction)
                 app.UITable.ColumnEditable = true(1,4);
                 app.UITable.ColumnEditable(1) = false;
             end
            
        end
    end
    
    methods (Access = public)
        
        
        function dataSelectionChange(app)
            dataIdxs = app.MainApp.iSelectedData;
            %get no. of selected data
            if isscalar(dataIdxs)
                fitIdx = [];
                %find ID of selected model in saved fits of selected data in MainApp
                if ~isempty(app.AvailableFitModelsTree.SelectedNodes)
                    actModel = app.fit_models(app.AvailableFitModelsTree.SelectedNodes.NodeData);
                    if  ~any(isempty(app.MainApp.Data(dataIdxs).DataFits))
                        fitIdx = find(arrayfun(@(x) strcmp(actModel.ID,x.model.ID), app.MainApp.Data(dataIdxs).DataFits),1 );
                    end
                end
                if isempty(fitIdx) && ~isempty(app.MainApp.Data(dataIdxs).DataFits) && numel(app.MainApp.Data(dataIdxs).DataFits) > 0
                    newModelID = app.MainApp.Data(dataIdxs).DataFits(1).model.ID;
                    newModelIdx = find(arrayfun(@(x) strcmp(newModelID, x.ID), app.fit_models),1);
                    %newModelName = app.MainApp.Data(dataIdxs).DataFits(1).model.name;
                    %th = findobj(app.AvailableFitModelsTree, 'Text', newModelName);
                    th = findobj(app.AvailableFitModelsTree, 'NodeData', newModelIdx);
                    app.AvailableFitModelsTree.SelectedNodes = th;
                    %th.NodeData;
                end
            else
                %not implemented yet...
                %.. modelSelectionChanged() clears plot window for now.
            end
            app.modelSelectionChanged();
            
        end

        function buildModelTree(app)
            %build tree for available models:
            %models with category entry are placed as subnode in this category 
            if ~isempty(app.AvailableFitModelsTree.Children)
                delete(app.AvailableFitModelsTree.Children)
            end

            allCategories = cell(0);
            for ii=1:numel(app.fit_models)

                troot = app.AvailableFitModelsTree;
                tn = app.AvailableFitModelsTree;
                category = app.fit_models(ii).category;
                if ~isempty(category)
                    category = split(category, '/');                    
                end

                while ~isempty(category)
                    tnn = findobj(tn.Children, 'Text', category{1});
                    if isempty(tnn)
                        tn = uitreenode(tn,'Text', category{1});
                        allCategories{end+1} = category{1};
                    else
                        tn = tnn;
                    end
                    category(1) = [];
                end
                th = uitreenode(tn,'Text',app.fit_models(ii).name,'NodeData',ii);
            end

            allCategories = unique(allCategories);
            [~,sortIdx] = sort(arrayfun(@(x) x.Text, troot.Children, "UniformOutput", false));
            troot.Children = troot.Children(sortIdx);

            %sorting
            for ii = 1:numel(allCategories)
                tn = findobj(troot.Children, 'Text', allCategories{ii});
                kidsText = arrayfun(@(x) x.Text, tn.Children, "UniformOutput", false);
                [~,sortIdx] = sort(kidsText);
                tn.Children = tn.Children(sortIdx);
            end

            app.modelSelectionChanged();
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, MainApp)
            app.MainApp = MainApp;
            app.MainApp.subapp.Fitmodels = app.DatafittingUIFigure;

            app.fit_models = loadFDfitmodels();
            standardModelIDs = arrayfun(@(x) x.ID, app.fit_models, 'UniformOutput', false);
            addModelIDs = cell(0);
            
            [thisFilePath, ~, ~] = fileparts(mfilename("fullpath"));
            if isfile(fullfile(thisFilePath, 'user_models.json'))
                jsontext = fileread(fullfile(thisFilePath, 'user_models.json'));
                modelsStruct = jsondecode(jsontext);
                for ii = 1:numel(modelsStruct)
                    if ~any(strcmp(modelsStruct(ii).ID,[standardModelIDs addModelIDs]))
                        app.fit_models(end+1) = fitmodelDef(modelsStruct(ii));
                        addModelIDs{end+1} = modelsStruct(ii).ID;
                    elseif any(strcmp(modelsStruct(ii).ID, addModelIDs))
                        uialert(app.DatafittingUIFigure,...
                            ['Duplicate ModelID: "' modelsStruct(ii).ID '".'], ...
                            'Loading failure', 'Icon','error');
                    elseif any(strcmp(modelsStruct(ii).ID, standardModelIDs))
                        %warning('User file contains modelIDs used in standard file. Not loaded!')
                    end
                end
            end
            app.buildModelTree();

        end

        % Close request function: DatafittingUIFigure
        function DatafittingUIFigureCloseRequest(app, event)
            if isvalid(app.MainApp)
                app.MainApp.subapp.Fitmodels = [];
            end
            structfun(@delete, app.subfigs);
            delete(app)            
        end

        % Selection changed function: AvailableFitModelsTree
        function AvailableFitModelsTreeSelectionChanged(app, event)
            %selectedNodes = app.AvailableFitModelsTree.SelectedNodes;
            %selectedModel = app.fit_models(selectedNodes.NodeData);
            app.modelSelectionChanged();
            
        end

        % Button pushed function: SelectButton
        function SelectButtonPushed(app, event)
            %get selected data
            if numel(app.MainApp.iSelectedData) > 1
                uialert(app.DatafittingUIFigure,'Manual selection of data points is only possible for selection of single curves.', ...
                    'Selection error.','Icon','error','Modal',true);
                return
            else
                dataIdxs = app.MainApp.iSelectedData;
            end
            %get selected channel
            xChan = app.MainApp.DropDown_xAxisData.Value;
            yChan = app.MainApp.DropDown_yAxisData.Value;
            %get selected trace
            if strcmp(app.directionButtonGroup.SelectedObject.Text, 'approach')
                selTrace = 'ap';
                lineprop = '.b';
            else
                selTrace = 'rt';
                lineprop = '.r';
            end
            %obtain data
            dataPart = app.MainApp.Data(dataIdxs).(selTrace);
            %send this data to selection process in main window
            app.MainApp.startSelectData('multi', dataPart, xChan, yChan, ...
                'LineProp', lineprop,...
                'Title', "Select baseline data points", ...
                'xLabel', 'Height / m',...
                'yLabel', 'Force / N',...
                'selectID', 'modelFit');
            %main app will save logical index vector of selected data into
            % app.dataPointsSelection
        end

        % Button pushed function: FitButton
        function FitButtonPushed(app, event)
            selectedNodes = app.AvailableFitModelsTree.SelectedNodes;
            if isempty(selectedNodes) || isempty(selectedNodes.NodeData)
                uialert(app.DatafittingUIFigure,'Please select a model.', 'No model','Icon','warning','Modal',true);
                return
            end
            actModel = app.fit_models(selectedNodes.NodeData);

            %get full data(channel)
            dataIdxs = app.MainApp.iSelectedData;
            if numel(app.MainApp.iSelectedData) > 1
                wbh = uiprogressdlg(app.DatafittingUIFigure, 'Message',['Starting fits']...
                ,'Title','Fitting in progress' ...
                ...,'Visible', 'off'...
                ,'Value', 0);
            else
                
            end

            %get selected trace
            if strcmp(app.directionButtonGroup.SelectedObject.Text, 'approach')
                selTrace = 'ap';
            else
                selTrace = 'rt';
            end

            
            %which data channel?
            Xchannel = app.MainApp.DropDown_xAxisData.Value; %'Ind';
            Ychannel = app.MainApp.DropDown_yAxisData.Value; %'Fc';

            %which data part?
            whichDataTag = app.datapartButtonGroup.SelectedObject.Tag;

            for ii = 1:numel(dataIdxs)
                if numel(dataIdxs) > 1
                    wbh.Value = ii/numel(dataIdxs);
                    wbh.Message = ['Fitting dataset ' app.MainApp.DataNames{dataIdxs(ii)}];
                end

                dataTrace = app.MainApp.Data(dataIdxs(ii)).(selTrace);
                
                %get data indices
                switch whichDataTag
                    case 'noBL'
                        sIdx = dataTrace.iBl(2)+1;
                        eIdx = numel(dataTrace.(Xchannel));
                        dataTraceIdxs = (sIdx:eIdx);
                    case 'CPend'
                        sIdx = dataTrace.iCP(1)+1;
                        eIdx = numel(dataTrace.(Xchannel));
                        dataTraceIdxs = (sIdx:eIdx);
                    case 'manual'
                        if ~isempty(app.dataPointsSelection) && numel(app.dataPointsSelection) == numel(dataTrace.(Xchannel))
                            dataTraceIdxs = app.dataPointsSelection;
                        else
                            uialert(app.DatafittingUIFigure, 'Error: No valid selection of data points.', ...
                                'Data selection error.','Icon','error','Modal',true);
                            return
                        end
                end
    
                %get data
                xData = dataTrace.(Xchannel)(dataTraceIdxs);
                yData = dataTrace.(Ychannel)(dataTraceIdxs);
                
                                
                %set up FDdatafit object
                actFit = FDdataFit(actModel);            
    
                %perform fit
                try
                    actFit = actFit.fit('XData', xData, 'YData', yData);
                catch ME
                    uialert(app.DatafittingUIFigure,ME.message,'Fit error','Icon','error');
                end
    
                %insert data info to FDdatafit object
                actFit.data = dataTraceIdxs;
                actFit.xchannel = Xchannel;
                actFit.ychannel = Ychannel;
                actFit.trace = selTrace;
    
                
                datatable = table(xData, yData, 'VariableNames', {actModel.independent, actModel.dependent});
                datatable.Properties.VariableUnits = {actModel.independentdim, actModel.dependentdim};
                app.last_fit = struct('fit', actFit, 'data', datatable);
    
                %save fit into FDdata_ar object in MainApp
                
                %für mehrere gespeicherte Fits: suche index des gleichen
                %fitmodels und überschreibe es dann
                if isempty(app.MainApp.Data(dataIdxs(ii)).DataFits)
                    app.MainApp.Data(dataIdxs(ii)).DataFits = actFit;
                else
                    fitIdx = find(arrayfun(@(x) strcmp(actModel.ID,x.model.ID), app.MainApp.Data(dataIdxs(ii)).DataFits),1 );
                    if isempty(fitIdx)
                        fitIdx = numel(app.MainApp.Data(dataIdxs(ii)).DataFits)+1;
                    end
                    app.MainApp.Data(dataIdxs(ii)).DataFits(fitIdx) = actFit;
                end

            end
            if exist('wbh', 'var'), close(wbh); end

            if isscalar(dataIdxs)
                %show fit results and plot fit
                app.fillResultsTableWithFit(app.last_fit.fit);
                app.plotModelFit(actFit);
            end
            

        end

        % Selection changed function: datapartButtonGroup
        function datapartButtonGroupSelectionChanged(app, event)
            selectedButton = app.datapartButtonGroup.SelectedObject;
            
        end

        % Cell edit callback: UITable
        function UITableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            iM = app.AvailableFitModelsTree.SelectedNodes.NodeData;

            switch indices(2)
                case 1
                    app.fit_models(iM).parametervalues(indices(1)) = newData;
                case 2
                    app.fit_models(iM).parameter_isfixed(indices(1)) = newData;
                case 3
                    app.fit_models(iM).parameter_lbounds(indices(1)) = newData;
                case 4
                    app.fit_models(iM).parameter_ubounds(indices(1)) = newData;
            end
            
        end

        % Button pushed function: ShowFitStatsButton
        function ShowFitStatsButtonPushed(app, event)
            fitstats = struct('GoF', app.last_fit.fit.gof, 'out', app.last_fit.fit.outp, 'Fit', app.last_fit.fit.cfit, 'Data', app.last_fit.data);
            ShowFitStats(fitstats);
        end

        % Value changed function: prefixunitsSwitch
        function prefixunitsSwitchValueChanged(app, event)
            value = app.prefixunitsSwitch.Value;
            app.fillResultsTableWithFit(app.last_fit.fit);
        end

        % Button pushed function: TestButton
        function TestButtonPushed(app, event)
            try
                %xs = str2num(app.evaluateatEditField.Value);
                xs = eval(app.evaluateatEditField.Value);
                if ~all(isnumeric(xs)) || ~all(isfinite(xs))
                    error('Input cannot be evaluated to valid numbers.')
                end
            catch ME
                uialert(app.DatafittingUIFigure,ME.message, 'Input error', 'Icon','error');
                return
            end

            actModel = app.fit_models(app.AvailableFitModelsTree.SelectedNodes.NodeData);
            actParVals = num2cell(app.UITable.Data{:,1});

            if any(cellfun(@isnan,actParVals))
                uialert(app.DatafittingUIFigure,'Function cannot be evaluated if not all parameters are set to finite values.', 'Error', 'Icon','error');
                return
            end

            ys = actModel.modelfunction(actParVals{:}, xs);

            if isscalar(ys)                
                app.ResEditField.Value = ys;
            else
                app.ResEditField.Value = 0;

                if isempty(app.subfigs.ModelEval) || ~isgraphics(app.subfigs.ModelEval)
                    app.subfigs.ModelEval = uifigure();
                    app.subfigs.ModelEval.Name = 'Model test';
                    ah = axes(app.subfigs.ModelEval);
                else
                    ah = findobj(app.subfigs.ModelEval.Children, 'Type', 'Axes');
                end

                plot(ah, xs,ys,'-r');
                xlabel(ah, [actModel.independentdescription '  \it' actModel.independent '\rm  / ' actModel.independentdim]);
                ylabel(ah, [actModel.dependentdescription '  \it' actModel.dependent '\rm  / ' actModel.dependentdim]);

                title(ah, ['Evaluation for model "' actModel.ID '".'], "Interpreter","none");
                
            end


        end

        % Button pushed function: EditModelsButton
        function EditModelsButtonButtonPushed(app, event)
            selectedNodes = app.AvailableFitModelsTree.SelectedNodes;
            if ~isempty(selectedNodes) && ~isempty(selectedNodes.NodeData)
                app.editMenu.Enable = "on";
            else
                app.editMenu.Enable = "off";
            end
            
            coords = app.EditModelsButton.Parent.Position(1:2) + ...
                    app.EditModelsButton.Position(1:2)+[app.EditModelsButton.Position(3), - 3];
            open(app.ModelsContextMenu,coords);
        end

        % Menu selected function: newMenu
        function newMenuSelected(app, event)
            FitModelEdit(app, []);
        end

        % Menu selected function: editMenu
        function editMenuSelected(app, event)
            model_no = app.AvailableFitModelsTree.SelectedNodes.NodeData;
            FitModelEdit(app, app.fit_models(model_no));
        end

        % Menu selected function: saveMenu
        function saveMenuSelected(app, event)
             %TODO: If models have been modified: ask for saving before closing!
             
             [thisFilePath, ~, ~] = fileparts(mfilename("fullpath"));
             fname = fullfile(thisFilePath, 'user_models.json');
             fid = fopen(fname, 'w');
             fprintf(fid, '%s', app.fit_models.jsonencode(PrettyPrint=true));
             fclose(fid);


        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create DatafittingUIFigure and hide until all components are created
            app.DatafittingUIFigure = uifigure('Visible', 'off');
            app.DatafittingUIFigure.Position = [100 100 415 764];
            app.DatafittingUIFigure.Name = 'Data fitting';
            app.DatafittingUIFigure.CloseRequestFcn = createCallbackFcn(app, @DatafittingUIFigureCloseRequest, true);

            % Create FitButton
            app.FitButton = uibutton(app.DatafittingUIFigure, 'push');
            app.FitButton.ButtonPushedFcn = createCallbackFcn(app, @FitButtonPushed, true);
            app.FitButton.Position = [365 249 44 43];
            app.FitButton.Text = 'Fit !';

            % Create SelectdataPanel
            app.SelectdataPanel = uipanel(app.DatafittingUIFigure);
            app.SelectdataPanel.Title = 'Select data';
            app.SelectdataPanel.Position = [19 211 340 112];

            % Create directionButtonGroup
            app.directionButtonGroup = uibuttongroup(app.SelectdataPanel);
            app.directionButtonGroup.Title = 'direction';
            app.directionButtonGroup.Position = [10 11 100 73];

            % Create approachButton
            app.approachButton = uiradiobutton(app.directionButtonGroup);
            app.approachButton.Text = 'approach';
            app.approachButton.Position = [11 27 73 22];
            app.approachButton.Value = true;

            % Create retractButton
            app.retractButton = uiradiobutton(app.directionButtonGroup);
            app.retractButton.Text = 'retract';
            app.retractButton.Position = [11 5 57 22];

            % Create datapartButtonGroup
            app.datapartButtonGroup = uibuttongroup(app.SelectdataPanel);
            app.datapartButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @datapartButtonGroupSelectionChanged, true);
            app.datapartButtonGroup.Title = 'data part';
            app.datapartButtonGroup.Position = [120 11 212 73];

            % Create CPendButton
            app.CPendButton = uiradiobutton(app.datapartButtonGroup);
            app.CPendButton.Tag = 'CPend';
            app.CPendButton.Text = 'CP–end';
            app.CPendButton.Position = [11 27 65 22];
            app.CPendButton.Value = true;

            % Create allbutBLButton
            app.allbutBLButton = uiradiobutton(app.datapartButtonGroup);
            app.allbutBLButton.Tag = 'noBL';
            app.allbutBLButton.Text = 'all but BL';
            app.allbutBLButton.Position = [11 5 73 22];

            % Create manualselectButton
            app.manualselectButton = uiradiobutton(app.datapartButtonGroup);
            app.manualselectButton.Tag = 'manual';
            app.manualselectButton.Text = 'manual select';
            app.manualselectButton.Position = [108 27 96 22];

            % Create SelectButton
            app.SelectButton = uibutton(app.datapartButtonGroup, 'push');
            app.SelectButton.ButtonPushedFcn = createCallbackFcn(app, @SelectButtonPushed, true);
            app.SelectButton.Position = [108 5 100 22];
            app.SelectButton.Text = 'Select';

            % Create ModelsPanel
            app.ModelsPanel = uipanel(app.DatafittingUIFigure);
            app.ModelsPanel.Title = 'Models';
            app.ModelsPanel.Position = [17 331 377 423];

            % Create AvailableFitModelsTree
            app.AvailableFitModelsTree = uitree(app.ModelsPanel);
            app.AvailableFitModelsTree.SelectionChangedFcn = createCallbackFcn(app, @AvailableFitModelsTreeSelectionChanged, true);
            app.AvailableFitModelsTree.Position = [8 290 340 87];

            % Create AvailablefitmodelsLabel
            app.AvailablefitmodelsLabel = uilabel(app.ModelsPanel);
            app.AvailablefitmodelsLabel.Position = [8 376 110 22];
            app.AvailablefitmodelsLabel.Text = 'Available fit models';

            % Create ModeldetailsLabel
            app.ModeldetailsLabel = uilabel(app.ModelsPanel);
            app.ModeldetailsLabel.Position = [7 264 78 22];
            app.ModeldetailsLabel.Text = 'Model details';

            % Create UITable
            app.UITable = uitable(app.ModelsPanel);
            app.UITable.ColumnName = {'value'; 'fix?'; 'L bound'; 'U bound'};
            app.UITable.ColumnWidth = {'auto', 40, 'auto', 'auto'};
            app.UITable.RowName = {'par1;par2'};
            app.UITable.CellEditCallback = createCallbackFcn(app, @UITableCellEdit, true);
            app.UITable.Multiselect = 'off';
            app.UITable.Position = [8 45 340 111];

            % Create ModelparametersLabel
            app.ModelparametersLabel = uilabel(app.ModelsPanel);
            app.ModelparametersLabel.Position = [9 164 103 22];
            app.ModelparametersLabel.Text = 'Model parameters';

            % Create FormulaEditFieldLabel
            app.FormulaEditFieldLabel = uilabel(app.ModelsPanel);
            app.FormulaEditFieldLabel.Position = [8 243 49 22];
            app.FormulaEditFieldLabel.Text = 'Formula';

            % Create FormulaEditField
            app.FormulaEditField = uieditfield(app.ModelsPanel, 'text');
            app.FormulaEditField.Editable = 'off';
            app.FormulaEditField.FontSize = 10;
            app.FormulaEditField.Position = [77 243 269 22];

            % Create DescriptionTextAreaLabel
            app.DescriptionTextAreaLabel = uilabel(app.ModelsPanel);
            app.DescriptionTextAreaLabel.Position = [7 212 67 22];
            app.DescriptionTextAreaLabel.Text = 'Description';

            % Create DescriptionTextArea
            app.DescriptionTextArea = uitextarea(app.ModelsPanel);
            app.DescriptionTextArea.Editable = 'off';
            app.DescriptionTextArea.FontSize = 10;
            app.DescriptionTextArea.Position = [77 185 269 51];

            % Create TestButton
            app.TestButton = uibutton(app.ModelsPanel, 'push');
            app.TestButton.ButtonPushedFcn = createCallbackFcn(app, @TestButtonPushed, true);
            app.TestButton.Position = [9 11 48 22];
            app.TestButton.Text = 'Test';

            % Create evaluateatEditFieldLabel
            app.evaluateatEditFieldLabel = uilabel(app.ModelsPanel);
            app.evaluateatEditFieldLabel.HorizontalAlignment = 'right';
            app.evaluateatEditFieldLabel.Position = [60 11 67 22];
            app.evaluateatEditFieldLabel.Text = 'evaluate at:';

            % Create evaluateatEditField
            app.evaluateatEditField = uieditfield(app.ModelsPanel, 'text');
            app.evaluateatEditField.Position = [132 11 74 22];

            % Create xUnitLabel
            app.xUnitLabel = uilabel(app.ModelsPanel);
            app.xUnitLabel.Position = [211 11 33 22];
            app.xUnitLabel.Text = 'xUnit';

            % Create yUnitLabel
            app.yUnitLabel = uilabel(app.ModelsPanel);
            app.yUnitLabel.Position = [341 11 33 22];
            app.yUnitLabel.Text = 'yUnit';

            % Create ResEditFieldLabel
            app.ResEditFieldLabel = uilabel(app.ModelsPanel);
            app.ResEditFieldLabel.HorizontalAlignment = 'right';
            app.ResEditFieldLabel.Position = [254 11 33 22];
            app.ResEditFieldLabel.Text = 'Res.:';

            % Create ResEditField
            app.ResEditField = uieditfield(app.ModelsPanel, 'numeric');
            app.ResEditField.Editable = 'off';
            app.ResEditField.Position = [289 11 45 22];

            % Create EditModelsButton
            app.EditModelsButton = uibutton(app.ModelsPanel, 'push');
            app.EditModelsButton.ButtonPushedFcn = createCallbackFcn(app, @EditModelsButtonButtonPushed, true);
            app.EditModelsButton.Icon = 'gear-solid.svg';
            app.EditModelsButton.Position = [349 355 26 22];
            app.EditModelsButton.Text = '';

            % Create FitresultsPanel
            app.FitresultsPanel = uipanel(app.DatafittingUIFigure);
            app.FitresultsPanel.Title = 'Fit results';
            app.FitresultsPanel.Position = [18 11 376 193];

            % Create UITable2
            app.UITable2 = uitable(app.FitresultsPanel);
            app.UITable2.ColumnName = {'value'; 'U error'; 'L error'; 'Column 4'};
            app.UITable2.RowName = {};
            app.UITable2.Position = [19 37 340 113];

            % Create ShowFitStatsButton
            app.ShowFitStatsButton = uibutton(app.FitresultsPanel, 'push');
            app.ShowFitStatsButton.ButtonPushedFcn = createCallbackFcn(app, @ShowFitStatsButtonPushed, true);
            app.ShowFitStatsButton.Position = [260 8 100 22];
            app.ShowFitStatsButton.Text = 'Show FitStats';

            % Create prefixunitsSwitchLabel
            app.prefixunitsSwitchLabel = uilabel(app.FitresultsPanel);
            app.prefixunitsSwitchLabel.HorizontalAlignment = 'center';
            app.prefixunitsSwitchLabel.Position = [20 8 64 22];
            app.prefixunitsSwitchLabel.Text = 'prefix units';

            % Create prefixunitsSwitch
            app.prefixunitsSwitch = uiswitch(app.FitresultsPanel, 'slider');
            app.prefixunitsSwitch.ValueChangedFcn = createCallbackFcn(app, @prefixunitsSwitchValueChanged, true);
            app.prefixunitsSwitch.Tooltip = {'Best fitting prefix for start value is used.'};
            app.prefixunitsSwitch.Position = [114 12 30 13];

            % Create ModelLabel
            app.ModelLabel = uilabel(app.FitresultsPanel);
            app.ModelLabel.Position = [20 149 340 22];
            app.ModelLabel.Text = 'Model:';

            % Create ModelsContextMenu
            app.ModelsContextMenu = uicontextmenu(app.DatafittingUIFigure);

            % Create newMenu
            app.newMenu = uimenu(app.ModelsContextMenu);
            app.newMenu.MenuSelectedFcn = createCallbackFcn(app, @newMenuSelected, true);
            app.newMenu.Text = 'new';

            % Create editMenu
            app.editMenu = uimenu(app.ModelsContextMenu);
            app.editMenu.MenuSelectedFcn = createCallbackFcn(app, @editMenuSelected, true);
            app.editMenu.Text = 'edit';

            % Create saveMenu
            app.saveMenu = uimenu(app.ModelsContextMenu);
            app.saveMenu.MenuSelectedFcn = createCallbackFcn(app, @saveMenuSelected, true);
            app.saveMenu.Text = 'save';

            % Show the figure after all components are created
            app.DatafittingUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FD_modelfits_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.DatafittingUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.DatafittingUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.DatafittingUIFigure)
        end
    end
end