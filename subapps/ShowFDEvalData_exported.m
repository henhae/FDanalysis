classdef ShowFDEvalData_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        FitvalueoverviewUIFigure  matlab.ui.Figure
        DataMenu                  matlab.ui.container.Menu
        OpendataMenu              matlab.ui.container.Menu
        SavedataMenu              matlab.ui.container.Menu
        CloseMenu                 matlab.ui.container.Menu
        PlotsMenu                 matlab.ui.container.Menu
        SavecurrentplotMenu       matlab.ui.container.Menu
        UITable                   matlab.ui.control.Table
        TabGroup                  matlab.ui.container.TabGroup
        HistogramTab              matlab.ui.container.Tab
        ButtonGroup               matlab.ui.container.ButtonGroup
        EditField                 matlab.ui.control.NumericEditField
        EditFieldLabel            matlab.ui.control.Label
        HistogramBinsSpinner      matlab.ui.control.Spinner
        BinsizeButton             matlab.ui.control.RadioButton
        noofBinsButton            matlab.ui.control.RadioButton
        individualTab             matlab.ui.container.Tab
        yaxisscaleSwitch          matlab.ui.control.Switch
        yaxisscaleLabel           matlab.ui.control.Label
        xaxisDropDown             matlab.ui.control.DropDown
        xaxisDropDownLabel        matlab.ui.control.Label
        DisplayerrorsSwitch       matlab.ui.control.Switch
        DisplayerrorsSwitchLabel  matlab.ui.control.Label
        ValuetoplotDropDown       matlab.ui.control.DropDown
        ValuetoplotDropDownLabel  matlab.ui.control.Label
        UIAxes                    matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        data % Description
        binsSpinnerVals
        binsSizeVals
        Parameters = ["AdhEnergy";"AdhForce";"AdhSep";"RuptLength"];
        ParameterUnits = struct("AdhEnergy", 'J', "AdhForce", 'N', ...
                                "AdhSep", 'm', "RuptLength", 'm');
        ParameterNames = struct("AdhEnergy", 'Adhesion Energy', ...
                                "AdhForce", 'Adhesion Force', ...
                                "AdhSep", 'Adhesion Separation',...
                                "RuptLength", 'Rupture Length');
        Models
        DataGroups
    end
    
    methods (Access = private)
        
        function actualize_plot(app)
            
            cla(app.UIAxes);
            app.UIAxes.NextPlot = "add";

            selGroups = find(cell2mat(app.UITable.Data(:,2)))';
            selPar = app.ValuetoplotDropDown.Value;

            allDataToPlotIdxs = [app.DataGroups(selGroups).Idxs];
            
            if contains(selPar, '__') %selPar is fit model parameter
                fitmodelname = extractAfter(selPar, '__');
                parName = extractBefore(selPar, '__');
                hasThisModel = false(size(app.data));
                modelIdxs = zeros(size(app.data));
                parvalues = zeros(size(app.data));
                parerrors = zeros(numel(app.data),2);
                ParDim = convertStringsToChars(parName);
                ParUnit = '';
                for ii = 1:numel(app.data)
                    if ~isempty(app.data(ii).DataFits)
                        mIdx = find(arrayfun(@(x) strcmp(x.model.ID,fitmodelname), app.data(ii).DataFits));
                        if ~isempty(mIdx)
                            hasThisModel(ii) = true;
                            modelIdxs(ii) = mIdx;
                            parIdx = find(strcmp(app.data(ii).DataFits(mIdx).model.parameters,parName));
                            parvalues(ii) = app.data(ii).DataFits(mIdx).paramRes(parIdx);
                            parerrors(ii,:) = app.data(ii).DataFits(mIdx).errors(:,parIdx)';
                            if isempty(ParUnit)
                                ParUnit = app.data(ii).DataFits(mIdx).model.parameterdims{parIdx};
                            end
                        end
                    end
                end
                hasNoValues = ~hasThisModel;                

            else %selPar is basic evaluation parameter
                parvalues = arrayfun(@(x) x.(selPar), app.data, "UniformOutput",true);
                %allData = {app.data.(selPar)};
                %allData = arrayfun(@(x) x.(selPar), app.data, "UniformOutput",false);
                %selParGroupsData = cellfun(@(x) [app.data(x).(selPar)], {app.DataGroups.Idxs}, 'UniformOutput', false);
                %hasNoValues = cellfun(@isempty, parvalues);
                hasNoValues = arrayfun(@isempty, parvalues);
    
                ParDim = app.ParameterNames.(selPar);
                ParUnit = app.ParameterUnits.(selPar);
            end
            
            %allData(hasNoValues) = {NaN};
            parvalues(hasNoValues) = NaN;
            selParGroupsData = cellfun(@(x) [parvalues(x)], {app.DataGroups.Idxs}, 'UniformOutput', false);


            %allDataMax = max(cellfun(@(x) max(abs(x)), selParGroupsData(selGroups)) );
            allDataMax = max(abs(parvalues));
            %plotDataVec = [selParGroupsData{selGroups}];
            %[newMax, ParUnit] = app.exp2pref(max(abs(plotDataVec)), ParUnit);
            %plotFact = newMax/max(plotDataVec);
            [newMax, ParUnit] = app.exp2pref(allDataMax, ParUnit);
            plotFact = newMax/allDataMax;

            if strcmp(app.TabGroup.SelectedTab.Title,"Histogram")                
               
                %select data for hist.
                xDim = ParDim;
                xUnit = ParUnit;

                app.EditFieldLabel.Text = xUnit;

                for ii = selGroups
                    thisGroupsIdxs = app.DataGroups(ii).Idxs;
                    thisGroupData = [selParGroupsData{ii}] * plotFact;
                    if numel(thisGroupsIdxs) > 0
                        if app.noofBinsButton.Value
                            if app.binsSpinnerVals.(selPar)(1) == 0
                                hh_t = histogram(app.UIAxes,thisGroupData);
                                app.binsSpinnerVals.(selPar)(1) = hh_t.NumBins;
                                app.HistogramBinsSpinner.Value = hh_t.NumBins;
                            else
                                hh_t = histogram(app.UIAxes,thisGroupData, app.binsSpinnerVals.(selPar)(1));
                            end
                        else
                            if app.binsSizeVals.(selPar)(1) == 0
                                hh_t = histogram(app.UIAxes,thisGroupData);
                                app.binsSizeVals.(selPar)(1) = mean(diff(hh_t.BinEdges));
                                app.EditField.Value = mean(diff(hh_t.BinEdges));
                            else
                                binSize = app.binsSizeVals.(selPar)(1);
                                minVal = floor(min(thisGroupData)/binSize)*binSize;
                                maxVal = ceil(max(thisGroupData)/binSize)*binSize;
                                edges = (minVal:binSize:maxVal);
                                if numel(edges) == 1
                                    edges = 1;
                                end
                                hh_t = histogram(app.UIAxes,thisGroupData, edges);
                            end
                        end
                        hh_t.DisplayName = app.DataGroups(ii).Name;
                    end
                end

                if numel(app.DataGroups) > 1
                    legend(app.UIAxes,"Location","best", "Interpreter","none");
                end

                app.UIAxes.XLabel.String = [xDim ' / ' xUnit];
                app.UIAxes.YLabel.String = 'counts';

            else %plot datasets
                
                cla(app.UIAxes);
                app.UIAxes.NextPlot = 'add';
                if size(app.UITable.Data,1)>7
                    colororder(app.UIAxes, turbo(size(app.UITable.Data,1)));
                else
                    colororder(app.UIAxes, 'default');
                end
                markertypes = {'d', 'o', 'p', '^', 'v', '<', '>', '.'};

                yDim = ParDim;
                yUnit = ParUnit;


                

                for ii = selGroups
                    
                    %linear index of entries in app.data (from logical indexing of the matrix)
                    isInThisGroup = false(size(app.data));
                    isInThisGroup(app.DataGroups(ii).Idxs) = true;
                    thisDataPlotIdxs = find(isInThisGroup & ~hasNoValues);
                    thisPlotData = [selParGroupsData{ii}] * plotFact;
                    if exist('parerrors', 'var')
                        %thisPlotErrs = cellfun(@(x) x.([valType 'errs'])(valIdx), app.data(thisDataPlotIdxs));
                        %cellfun(@(x) [parerrors(x)], {app.DataGroups.Idxs}, 'UniformOutput', false);
                        thisPlotErrsP = parerrors(thisDataPlotIdxs,2)* plotFact;
                        thisPlotErrsM = abs(parerrors(thisDataPlotIdxs,1))* plotFact;
                        app.DisplayerrorsSwitch.Enable = "on";
                    else
                        app.DisplayerrorsSwitch.Enable = "off";
                    end

                    if ~isempty(thisPlotData)

                        xPar = app.xaxisDropDown.Value;

                        if xPar == "dataset"
                            %xData = mod(thisDataPlotIdxs-1,size(app.fits,1))+1;
                            xData = thisDataPlotIdxs; %find(isInGroup(:,1));
                            xaxislabel = 'Dataset no.';
%                                 case 'indent'
%                                     xData = cellfun(@(x) max(x.fitdata.X), app.data(thisDataPlotIdxs))*1e-9;
%                                     if xMaxVal == 0
%                                         [xMaxVal, xUnit] = app.exp2pref(max(xData), 'm');
%                                         xaxislabel = ['max. indentation / ' xUnit];
%                                         xMaxVal = xMaxVal/max(xData);
%                                     end
%                                     xData = xData*xMaxVal;
%                                 case 'goodness'
%                                     xData = log10(cellfun(@(x) x.fit_gof.sse, app.data(thisDataPlotIdxs)));
%                                     %xData = log10(1-cellfun(@(x) x.fit_gof.adjrsquare, app.fits(thisDataPlotIdxs)));
%                                     %xaxislabel = ['log(1-adjusted R^2)'];
%                                     xaxislabel = ['sse'];
                        elseif isprop(app.data(1), xPar)
                            xData = [app.data(app.DataGroups(ii).Idxs).(xPar)];
                            xaxislabel = [app.ParameterNames.(xPar) ' / ' app.ParameterUnits.(xPar)];
                        else
                            xData = zeros(size(thisPlotData));
                            xaxislabel = '';
                        end


                        if ~isempty(xData) &&  ~isempty(thisPlotData) && numel(xData) == numel(thisPlotData)                    
                            if app.DisplayerrorsSwitch.Value == "On" && exist('thisPlotErrsM','var')
                                    tPh = errorbar(app.UIAxes, xData, thisPlotData, thisPlotErrsM, thisPlotErrsP, '.', ...
                                        'Marker', markertypes{mod(ii,8)+1}, 'MarkerSize', 5, ...
                                        'Color', app.UIAxes.ColorOrder(ii,:));
                            else
                                tPh = plot(app.UIAxes, xData, thisPlotData, '.', ...
                                    'Marker', markertypes{mod(ii,8)+1}, 'MarkerSize', 5, ...
                                    'MarkerFaceColor', app.UIAxes.ColorOrder(ii,:));
                            end
                            tPh.DisplayName = app.DataGroups(ii).Name;
                        end
                    end

                
                end
                app.UIAxes.NextPlot = "replace";
                app.UIAxes.YScale = app.yaxisscaleSwitch.Value;

                app.UIAxes.XLabel.String = xaxislabel;
                app.UIAxes.YLabel.String = [yDim ' / ' yUnit];

                lh = legend(app.UIAxes, {app.DataGroups(selGroups).Name} ,"Location","best", "Interpreter","none");
            end

            


        end
        
        function [new_value, unit_w_prefix]= exp2pref(~, old_value, varargin)
            
            if nargin == 3
                bare_unit = varargin{1};
                if iscell(bare_unit) && numel(bare_unit) > 1                    
                    if numel(old_value) == numel(bare_unit)
                        if all(strcmp(bare_unit{1}, bare_unit))
                            bare_unit = bare_unit{1};
                        else
                            error('Imput units must all be equal.')
                        end
                    elseif numel(old_value) ~= numel(bare_unit)
                        error('Number of value inputs must equal number of unit inputs.');
                    end
                end
            elseif nargin > 3
                error('Too many inputs.');
            else
                bare_unit = cellfun(@(x) '', cell(size(old_value)));
            end

            unitprefixes = {'P' 'T' 'G', 'M', 'k', '', 'm', '\mu', 'n', 'p', 'f', 'a'};
            prefix_exponent = [15 12 9 6 3 0 -3 -6 -9 -12 -15 -18];
            exponent = max(3*floor(log10(old_value)/3));
        
            if exponent < -18
                exponent = -18;
            elseif exponent > 15
                exponent = 15;
            end
            
            new_value = old_value .* 10.^(-exponent);
            unit_w_prefix = [unitprefixes{exponent == prefix_exponent}, bare_unit];            
            
        end
        
        function loadData(app, data)
            %expects data as array of FDdata_ar

            %the following fields:
            %coefs, coefdims, coefvals, coeferrs
            %(optional) evals, evaldims, evalvals, evalerrs
            %fitmodel OR fitmodelLong

            if isa(data, "FDdata_ar")
            else
                uialert(app.FitvalueoverviewUIFigure,"File Error","Error",...
                    "Modal",true,"Icon","error");
                return
            end

            %if check is o.k.
            app.data = data;            

            %set properties(global variables)

            %get all possible parameters from all fitmodels:
            params_tmp = cell(0);
            param_units_tmp = cell(0);
            for ii = 1:numel(data)
                if ~all(isempty(data(ii).DataFits))
                    for iif = 1:numel(data(ii).DataFits)
                        if ~isempty(data(ii).DataFits(iif))
                            thisfitparams = cellfun(@(x) [x '__' data(ii).DataFits(iif).model.ID], ...
                                data(ii).DataFits(iif).model.parameters, ...
                                "UniformOutput",false);
                            thisfitunits = data(ii).DataFits(iif).model.parameterdims;
                            if numel(thisfitparams)>1 && isrow(thisfitparams)
                                thisfitparams = thisfitparams';
                                thisfitunits = thisfitunits';
                            end
                            params_tmp = [params_tmp; thisfitparams];
                            param_units_tmp = [param_units_tmp; thisfitunits];
                        end
                    end
                end
            end
            [params, uniqueIdxs, ~] = unique(params_tmp);
            param_units = param_units_tmp(uniqueIdxs);

            validParams = [app.Parameters; params];
            validParamNames = [struct2cell(app.ParameterNames); ...
                cellfun(@(x) [strrep(x, '__', ' (' ) ')'], params, "UniformOutput", false)];
            validParamUnits = [struct2cell(app.ParameterUnits); param_units];

            app.binsSpinnerVals = zeros(size(params));
            app.binsSizeVals = zeros(size(params));

            tmp = cellfun(@(x) zeros(length(app.DataGroups),1), cell(size(validParams)), "UniformOutput",false);
            tmp = [cellstr(validParams) tmp]';
            tmp = struct(tmp{:});

            app.binsSpinnerVals = tmp;
            app.binsSizeVals = tmp;

            %set interactive tools properties
            app.ValuetoplotDropDown.Items = validParamNames;
            app.ValuetoplotDropDown.ItemsData = validParams; 

            

            app.xaxisDropDown.Items = ["dataset no"; validParamNames];
            app.xaxisDropDown.ItemsData = ["dataset"; validParams];

            
            %put all models in Table
            %app.UITable.Data = [uniqueModelNames num2cell(true(size(uniqueModelNames)))];
            app.UITable.Data = [{app.DataGroups.Name}', num2cell(true(numel(app.DataGroups),1))];

            app.ValuetoplotDropDownValueChanged([]);

            %enable UI components
            app.SavedataMenu.Enable = "on";
            app.SavecurrentplotMenu.Enable = "on";

            app.ValuetoplotDropDown.Enable = "on";

            app.HistogramBinsSpinner.Enable = "on";
            %app.FittypeDropDown.Enable = "on";

            app.UITable.Enable = "on";
            app.yaxisscaleSwitch.Enable = "on";
            app.xaxisDropDown.Enable = "on";
            %app.DisplayerrorsSwitch.Enable = "on";
            
        end
        
        
        function initializeApp(app)
            %set properties(global variables)

            %app.Parameters = ["AdhEnergy";"AdhForce";"AdhSep";"RuptLength"];
            
            app.binsSpinnerVals = structfun(@(x) 0, app.ParameterNames, "UniformOutput",false);
            app.binsSizeVals = structfun(@(x) 0 , app.ParameterNames, "UniformOutput",false);

            %set interactive tools properties
            app.ValuetoplotDropDown.Items = struct2cell(app.ParameterNames);
            app.ValuetoplotDropDown.ItemsData = app.Parameters; 

            app.xaxisDropDown.Items = ["dataset no"; struct2cell(app.ParameterNames)];
            app.xaxisDropDown.ItemsData = ["dataset"; app.Parameters];

            %put all groups in Table
            app.UITable.Data = {'---' false};

            cla(app.UIAxes);

            %disable UI components
            app.SavedataMenu.Enable = "off";
            app.SavecurrentplotMenu.Enable = "off";

            app.ValuetoplotDropDown.Enable = "off";

            app.HistogramBinsSpinner.Enable = "off";

            app.UITable.Enable = "off";
            app.yaxisscaleSwitch.Enable = "off";
            app.xaxisDropDown.Enable = "off";
            app.DisplayerrorsSwitch.Enable = "off";

            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, varargin)
            %expects as input #1: vector of FDdata_ar, #2 (opt): Datagroups 

            app.initializeApp;

            if nargin > 1
                if nargin > 2
                    if isstruct(varargin{2}) && isfield(varargin{2}, 'Idxs') && max([varargin{2}.Idxs]) <= numel(varargin{1})
                        app.DataGroups = varargin{2};
                    else
                        uialert(app.FitvalueoverviewUIFigure,'Sizes don''t fit', 'Input Error','Icon','error');
                    end
                end
                app.loadData(varargin{1});
            end
            app.actualize_plot();            


        end

        % Menu selected function: OpendataMenu
        function OpendataMenuSelected(app, event)
            [files, path]=(uigetfile([pwd,'/.mat'],'MultiSelect','off'));
            if isnumeric(files) && files == 0, return; end   %end execution if user pressed "cancel"
            load(fullfile(path, files), 'exdata');
            
            if isstruct(exdata)
                app.DataGroups = exdata.groups;
                exdata = exdata.data;
            end

            app.loadData(exdata);
        end

        % Menu selected function: SavedataMenu
        function SavedataMenuSelected(app, event)
            [dfilename, pathname] = uiputfile({'/*.mat'},...
                    'Save fits', [pwd]);

            exdata = struct('data', {app.data}, 'groups', {app.DataGroups});

            save([pathname dfilename], "exdata");
        end

        % Callback function
        function FittypeDropDownValueChanged(app, event)
            selModelIdx = strcmp(app.FittypeDropDown.Value, app.FittypeDropDown.ItemsData);

            ValueToPlot = app.ValuetoplotDropDown.Value;
            thisModelValueIdx = find(strcmp(ValueToPlot,app.Parameters{selModelIdx}),1);
            
            app.HistogramBinsSpinner.Value = app.binsSpinnerVals{selModelIdx}(thisModelValueIdx);
            app.EditField.Value = app.binsSizeVals{selModelIdx}(thisModelValueIdx);
            
            app.actualize_plot();
        end

        % Value changed function: ValuetoplotDropDown
        function ValuetoplotDropDownValueChanged(app, event)
            value = app.ValuetoplotDropDown.Value;
            %valIdx = find(strcmp(value, app.ValuetoplotDropDown.Items),1);
            
            selPar = app.ValuetoplotDropDown.Value;
            grIdx = 1;
            app.HistogramBinsSpinner.Value = app.binsSpinnerVals.(selPar)(grIdx);
            app.EditField.Value = app.binsSizeVals.(selPar)(grIdx);            

            app.actualize_plot();
        end

        % Value changed function: HistogramBinsSpinner
        function HistogramBinsSpinnerValueChanged(app, event)
            value = app.HistogramBinsSpinner.Value;
            selPar = app.ValuetoplotDropDown.Value;
            grIdx = 1;
            app.binsSpinnerVals.(selPar)(grIdx) = value;
            app.actualize_plot();
        end

        % Value changed function: EditField
        function EditFieldValueChanged(app, event)
            value = app.EditField.Value;
            selPar = app.ValuetoplotDropDown.Value;
            grIdx = 1;

            app.binsSizeVals.(selPar)(grIdx) = value;
            app.actualize_plot();            
        end

        % Callback function: ButtonGroup, DisplayerrorsSwitch, TabGroup, 
        % ...and 3 other components
        function JustActualize_Callback(app, event)
            if ~isempty(app.data)
                app.actualize_plot();
            end
        end

        % Callback function: CloseMenu, FitvalueoverviewUIFigure
        function FitvalueoverviewUIFigureCloseRequest(app, event)
            delete(app)            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create FitvalueoverviewUIFigure and hide until all components are created
            app.FitvalueoverviewUIFigure = uifigure('Visible', 'off');
            app.FitvalueoverviewUIFigure.Position = [100 100 679 418];
            app.FitvalueoverviewUIFigure.Name = 'Fit value overview';
            app.FitvalueoverviewUIFigure.CloseRequestFcn = createCallbackFcn(app, @FitvalueoverviewUIFigureCloseRequest, true);

            % Create DataMenu
            app.DataMenu = uimenu(app.FitvalueoverviewUIFigure);
            app.DataMenu.Text = 'Data';

            % Create OpendataMenu
            app.OpendataMenu = uimenu(app.DataMenu);
            app.OpendataMenu.MenuSelectedFcn = createCallbackFcn(app, @OpendataMenuSelected, true);
            app.OpendataMenu.Text = 'Open data';

            % Create SavedataMenu
            app.SavedataMenu = uimenu(app.DataMenu);
            app.SavedataMenu.MenuSelectedFcn = createCallbackFcn(app, @SavedataMenuSelected, true);
            app.SavedataMenu.Text = 'Save data';

            % Create CloseMenu
            app.CloseMenu = uimenu(app.DataMenu);
            app.CloseMenu.MenuSelectedFcn = createCallbackFcn(app, @FitvalueoverviewUIFigureCloseRequest, true);
            app.CloseMenu.Text = 'Close';

            % Create PlotsMenu
            app.PlotsMenu = uimenu(app.FitvalueoverviewUIFigure);
            app.PlotsMenu.Text = 'Plots';

            % Create SavecurrentplotMenu
            app.SavecurrentplotMenu = uimenu(app.PlotsMenu);
            app.SavecurrentplotMenu.Text = 'Save current plot';

            % Create UIAxes
            app.UIAxes = uiaxes(app.FitvalueoverviewUIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Box = 'on';
            app.UIAxes.Position = [199 29 468 362];

            % Create ValuetoplotDropDownLabel
            app.ValuetoplotDropDownLabel = uilabel(app.FitvalueoverviewUIFigure);
            app.ValuetoplotDropDownLabel.HorizontalAlignment = 'right';
            app.ValuetoplotDropDownLabel.Position = [21 369 72 22];
            app.ValuetoplotDropDownLabel.Text = 'Value to plot';

            % Create ValuetoplotDropDown
            app.ValuetoplotDropDown = uidropdown(app.FitvalueoverviewUIFigure);
            app.ValuetoplotDropDown.ValueChangedFcn = createCallbackFcn(app, @ValuetoplotDropDownValueChanged, true);
            app.ValuetoplotDropDown.Position = [27 338 100 22];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.FitvalueoverviewUIFigure);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.TabGroup.Position = [4 29 196 173];

            % Create HistogramTab
            app.HistogramTab = uitab(app.TabGroup);
            app.HistogramTab.Title = 'Histogram';

            % Create ButtonGroup
            app.ButtonGroup = uibuttongroup(app.HistogramTab);
            app.ButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.ButtonGroup.Title = 'Button Group';
            app.ButtonGroup.Position = [6 11 184 129];

            % Create noofBinsButton
            app.noofBinsButton = uiradiobutton(app.ButtonGroup);
            app.noofBinsButton.Text = 'no. of Bins:';
            app.noofBinsButton.Position = [11 83 83 22];
            app.noofBinsButton.Value = true;

            % Create BinsizeButton
            app.BinsizeButton = uiradiobutton(app.ButtonGroup);
            app.BinsizeButton.Text = 'Bin size';
            app.BinsizeButton.Position = [9 33 64 22];

            % Create HistogramBinsSpinner
            app.HistogramBinsSpinner = uispinner(app.ButtonGroup);
            app.HistogramBinsSpinner.Limits = [0 Inf];
            app.HistogramBinsSpinner.ValueChangedFcn = createCallbackFcn(app, @HistogramBinsSpinnerValueChanged, true);
            app.HistogramBinsSpinner.Position = [30 61 79 22];

            % Create EditFieldLabel
            app.EditFieldLabel = uilabel(app.ButtonGroup);
            app.EditFieldLabel.HorizontalAlignment = 'right';
            app.EditFieldLabel.Position = [122 12 56 22];
            app.EditFieldLabel.Text = 'Edit Field';

            % Create EditField
            app.EditField = uieditfield(app.ButtonGroup, 'numeric');
            app.EditField.ValueChangedFcn = createCallbackFcn(app, @EditFieldValueChanged, true);
            app.EditField.Position = [26 12 83 22];

            % Create individualTab
            app.individualTab = uitab(app.TabGroup);
            app.individualTab.Title = 'individual';

            % Create DisplayerrorsSwitchLabel
            app.DisplayerrorsSwitchLabel = uilabel(app.individualTab);
            app.DisplayerrorsSwitchLabel.HorizontalAlignment = 'center';
            app.DisplayerrorsSwitchLabel.Position = [8 41 79 22];
            app.DisplayerrorsSwitchLabel.Text = 'Display errors';

            % Create DisplayerrorsSwitch
            app.DisplayerrorsSwitch = uiswitch(app.individualTab, 'slider');
            app.DisplayerrorsSwitch.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.DisplayerrorsSwitch.Position = [132 45 33 14];

            % Create xaxisDropDownLabel
            app.xaxisDropDownLabel = uilabel(app.individualTab);
            app.xaxisDropDownLabel.HorizontalAlignment = 'right';
            app.xaxisDropDownLabel.Position = [9 115 41 22];
            app.xaxisDropDownLabel.Text = 'x-axis:';

            % Create xaxisDropDown
            app.xaxisDropDown = uidropdown(app.individualTab);
            app.xaxisDropDown.Items = {'dataset no.', 'max. indent.', 'goodness of fit'};
            app.xaxisDropDown.ItemsData = {'dataset', 'indent', 'goodness'};
            app.xaxisDropDown.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.xaxisDropDown.Position = [66 115 100 22];
            app.xaxisDropDown.Value = 'dataset';

            % Create yaxisscaleLabel
            app.yaxisscaleLabel = uilabel(app.individualTab);
            app.yaxisscaleLabel.HorizontalAlignment = 'center';
            app.yaxisscaleLabel.Position = [17 79 69 22];
            app.yaxisscaleLabel.Text = 'y-axis scale';

            % Create yaxisscaleSwitch
            app.yaxisscaleSwitch = uiswitch(app.individualTab, 'slider');
            app.yaxisscaleSwitch.Items = {'linear', 'log'};
            app.yaxisscaleSwitch.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.yaxisscaleSwitch.Position = [133 83 33 15];
            app.yaxisscaleSwitch.Value = 'linear';

            % Create UITable
            app.UITable = uitable(app.FitvalueoverviewUIFigure);
            app.UITable.ColumnName = {'Group Name'; 'Show?'};
            app.UITable.RowName = {};
            app.UITable.ColumnEditable = [false true];
            app.UITable.CellEditCallback = createCallbackFcn(app, @JustActualize_Callback, true);
            app.UITable.Position = [10 217 179 113];

            % Show the figure after all components are created
            app.FitvalueoverviewUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ShowFDEvalData_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.FitvalueoverviewUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.FitvalueoverviewUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.FitvalueoverviewUIFigure)
        end
    end
end