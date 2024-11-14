classdef ShowIndEvalData_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        FitvalueoverviewUIFigure  matlab.ui.Figure
        DataMenu                  matlab.ui.container.Menu
        OpendataMenu              matlab.ui.container.Menu
        SavedataMenu              matlab.ui.container.Menu
        CloseMenu                 matlab.ui.container.Menu
        PlotsMenu                 matlab.ui.container.Menu
        SavecurrentplotMenu       matlab.ui.container.Menu
        TabGroup                  matlab.ui.container.TabGroup
        HistogramTab              matlab.ui.container.Tab
        ButtonGroup               matlab.ui.container.ButtonGroup
        EditField                 matlab.ui.control.NumericEditField
        EditFieldLabel            matlab.ui.control.Label
        HistogramBinsSpinner      matlab.ui.control.Spinner
        BinsizeButton             matlab.ui.control.RadioButton
        noofBinsButton            matlab.ui.control.RadioButton
        FittypeDropDown           matlab.ui.control.DropDown
        FittypeDropDownLabel      matlab.ui.control.Label
        byDatasetTab              matlab.ui.container.Tab
        xaxisscaleSwitch          matlab.ui.control.Switch
        xaxisscaleSwitchLabel     matlab.ui.control.Label
        yaxisscaleSwitch          matlab.ui.control.Switch
        yaxisscaleLabel           matlab.ui.control.Label
        xaxisDropDown             matlab.ui.control.DropDown
        xaxisDropDownLabel        matlab.ui.control.Label
        UITable                   matlab.ui.control.Table
        DisplayerrorsSwitch       matlab.ui.control.Switch
        DisplayerrorsSwitchLabel  matlab.ui.control.Label
        ValuetoplotDropDown       matlab.ui.control.DropDown
        ValuetoplotDropDownLabel  matlab.ui.control.Label
        UIAxes                    matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        fits % Description
        binsSpinnerVals
        binsSizeVals
        ModelParameters
        Models
        DataGroups
    end
    
    methods (Access = private)
        
        function actualize_plot(app)
            
            valName = app.ValuetoplotDropDown.Value;
            cla(app.UIAxes);
            app.UIAxes.NextPlot = "add";
            if strcmp(app.TabGroup.SelectedTab.Title,"Histogram")
                selModelIdx = strcmp(app.FittypeDropDown.Value, app.Models.IDs);
                thisModelDataIdxs = app.Models.Idxs{selModelIdx};
                
                if any(strcmp(valName, app.fits{thisModelDataIdxs(1)}.coefs))
                    valIdx = find(strcmp(valName, app.fits{thisModelDataIdxs(1)}.coefs));
                    histData = cellfun(@(x) x.coefvals(valIdx), app.fits(thisModelDataIdxs));
                    xDim = app.fits{thisModelDataIdxs(1)}.coefs{valIdx};
                    xUnit = app.fits{thisModelDataIdxs(1)}.coefdims{valIdx};
                    valsIdx = valIdx+2;
                elseif any(strcmp(valName, app.fits{thisModelDataIdxs(1)}.evals))
                    valIdx = find(strcmp(valName, app.fits{thisModelDataIdxs(1)}.evals));
                    histData = cellfun(@(x) x.evalvals(valIdx), app.fits(thisModelDataIdxs));
                    xDim = app.fits{thisModelDataIdxs(1)}.evals{valIdx};
                    xUnit = app.fits{thisModelDataIdxs(1)}.evaldims{valIdx};
                    valsIdx = valIdx + numel(app.fits{thisModelDataIdxs(1)}.coefs)+2;
                elseif strcmp(valName, 'indent')
                    histData = cellfun(@(x) max(x.fitdata.X), app.fits(thisModelDataIdxs))*1e-9;
                    xDim = 'max. indentation';
                    xUnit = 'm';
                    valsIdx = 1;
                elseif strcmp(valName, 'goodness')
                    histData = cellfun(@(x) x.fit_gof.sse, app.fits(thisModelDataIdxs));
                    xaxislabel = 'sse';
                    xUnit = '';
                    valsIdx = 2;
                end

                if ~strcmp(valName, 'goodness')
                    [histData, xUnit] = app.exp2pref(histData, xUnit);
                    xaxislabel = [xDim ' / ' xUnit];
                end

                app.EditFieldLabel.Text = xUnit;


                for ii = 1:size(app.DataGroups,1)
                    thisGroupsIdxs = app.DataGroups(ii).Idxs;
                    if numel(thisGroupsIdxs) > 0
                        if app.noofBinsButton.Value
                            if app.binsSpinnerVals{selModelIdx}(valsIdx) == 0
                                hh_t = histogram(app.UIAxes,histData(thisGroupsIdxs));
                                app.binsSpinnerVals{selModelIdx}(valsIdx) = hh_t.NumBins;
                                app.HistogramBinsSpinner.Value = hh_t.NumBins;
                            else
                                hh_t = histogram(app.UIAxes,histData(thisGroupsIdxs), app.binsSpinnerVals{selModelIdx}(valsIdx));
                            end
                        else
                            if app.binsSizeVals{selModelIdx}(valsIdx) == 0
                                hh_t = histogram(app.UIAxes,histData(thisGroupsIdxs));
                                app.binsSizeVals{selModelIdx}(valsIdx) = mean(diff(hh_t.BinEdges));
                                app.EditField.Value = mean(diff(hh_t.BinEdges));
                            else
                                binSize = app.binsSizeVals{selModelIdx}(valsIdx);
                                edges = (min(histData(thisGroupsIdxs)):binSize:max(histData(thisGroupsIdxs)));
                                hh_t = histogram(app.UIAxes,histData(thisGroupsIdxs), edges);
                            end
                        end
                        hh_t.DisplayName = app.DataGroups(ii).Name;
                    end
                end

                if size(app.DataGroups,1) > 1
                    legend(app.UIAxes,"Location","best");
                end

                app.UIAxes.XLabel.String = xaxislabel;
                app.UIAxes.YLabel.String = 'counts';

            else %plot datasets
                
                cla(app.UIAxes);
                app.UIAxes.NextPlot = 'add';
                if size(app.UITable.Data,1)>7
                    colororder(app.UIAxes, turbo(size(app.UITable.Data,1)));
                else
                    colororder(app.UIAxes, 'default');
                end
                yMaxVal = 0;
                xMaxVal = 0;
                markertypes = {'.', 'o', 'p', '^', 'v', '<', '>', 'd'};
                if any(strcmp(valName, {'dataset', 'indent', 'sse', 'goodness'}))
                    modelsToPlot = true(size(app.UITable.Data(:,2)));
                else
                    modelsToPlot = cellfun(@(x) any(strcmp(x, valName)),app.ModelParameters);
                end
                
                %plot only checked ones
                modelsToPlot = modelsToPlot & cell2mat(app.UITable.Data(:,2));

                if ~any(strcmp(app.xaxisDropDown.Value, {'dataset', 'indent', 'sse', 'goodness'}))
                    xValName = app.xaxisDropDown.Value;
                    modelsToPlot = modelsToPlot & cellfun(@(x) any(strcmp(x, xValName)),app.ModelParameters);                    
                end
                modelsToPlot = find(modelsToPlot)'; %change from logical to index
                for ii = modelsToPlot
                    %indices of datasets with valids fits with this model
                    hasFitWithThisModel = cellfun(@(x) ~isempty(x) && strcmp(x.fitmodelLong, app.UITable.Data{ii,1}), app.fits);
                    thisModelDataIdxs = find(hasFitWithThisModel);
                    [thisModelDataRowIdxs, ~] = ind2sub(size(app.fits),thisModelDataIdxs);
                    %is chosen parameter a fit parameter or an evaluated one
                    if ~isempty(thisModelDataIdxs) && any(strcmp(valName, app.fits{thisModelDataIdxs(1)}.coefs))
                        valType = 'coef';
                    elseif ~isempty(thisModelDataIdxs) && any(strcmp(valName, app.fits{thisModelDataIdxs(1)}.evals))
                        valType = 'eval';
                    elseif any(strcmp(valName, {'dataset', 'indent', 'sse', 'goodness'}))
                        valType = 'gen';
                    else
                        valType = '';
                    end

                    if ~isempty(valType)
                        if ~strcmp(valType, 'gen')    
                            valIdx = find(strcmp(valName, app.fits{thisModelDataIdxs(1)}.([valType 's']) ));
                            yDim = app.fits{thisModelDataIdxs(1)}.([valType 's']){valIdx};
                            yUnit = app.fits{thisModelDataIdxs(1)}.([valType 'dims']){valIdx};
                        elseif strcmp(valName,'indent')
                            yDim = 'max. indentation';
                            yUnit = 'm';
                        elseif strcmp(valName,'goodness')
                            yaxislabel = 'sse';
                        end


                        isFstPlotOfThisModel = true;
    
                        for iGroup = 1:length(app.DataGroups)
                            

                            isInGroup = false(size(app.fits));
                            isInGroup(app.DataGroups(iGroup).Idxs,:) = true;

                            %linear index of entries in app.fits (from logical indexing of the matrix)
                            thisDataPlotIdxs = find(hasFitWithThisModel & isInGroup);

                            if ~strcmp(valType, 'gen')
                                thisPlotData = cellfun(@(x) x.([valType 'vals'])(valIdx), app.fits(thisDataPlotIdxs));
                                thisPlotErrs = cellfun(@(x) x.([valType 'errs'])(valIdx), app.fits(thisDataPlotIdxs));
                            elseif strcmp(valName,'indent')
                                thisPlotData = cellfun(@(x) max(x.fitdata.X), app.fits(thisDataPlotIdxs))*1e-9;
                                thisPlotErrs = zeros(size(thisPlotData));
                            elseif strcmp(valName,'goodness')
                                thisPlotData = cellfun(@(x) x.fit_gof.sse, app.fits(thisDataPlotIdxs));
                                thisPlotErrs = zeros(size(thisPlotData));
                            end

                            if ~isempty(thisPlotData)
    
                                switch app.xaxisDropDown.Value
                                    case 'dataset'
                                        [xData, ~] = ind2sub(size(app.fits), thisDataPlotIdxs); % get row index of linear indices
                                        xaxislabel = 'Dataset no.';
                                    case 'indent'
                                        xData = cellfun(@(x) max(x.fitdata.X), app.fits(thisDataPlotIdxs))*1e-9;
                                        xMaxVal = max(xMaxVal, max(xData));
                                        xDim = 'max. indentation';
                                        xUnit = 'm';
                                    case 'goodness'
                                        xData = cellfun(@(x) x.fit_gof.sse, app.fits(thisDataPlotIdxs));
                                        xaxislabel = ['sse'];
                                    otherwise
                                        if any(strcmp(xValName, app.fits{thisDataPlotIdxs(1)}.coefs))
                                            xValIdx = find(strcmp(xValName, app.fits{thisDataPlotIdxs(1)}.coefs));
                                            xData = cellfun(@(x) x.coefvals(xValIdx), app.fits(thisDataPlotIdxs));
                                            xDim = app.fits{thisDataPlotIdxs(1)}.coefs{xValIdx};
                                            xUnit = app.fits{thisDataPlotIdxs(1)}.coefdims{xValIdx};
                                        elseif any(strcmp(xValName, app.fits{thisDataPlotIdxs(1)}.evals))
                                            xValIdx = find(strcmp(xValName, app.fits{thisDataPlotIdxs(1)}.evals));
                                            xData = cellfun(@(x) x.evalvals(xValIdx), app.fits(thisDataPlotIdxs));
                                            xDim = app.fits{thisDataPlotIdxs(1)}.evals{xValIdx};
                                            xUnit = app.fits{thisDataPlotIdxs(1)}.evaldims{xValIdx};
                                        else
                                            xData = [];
                                            xDim = "";
                                            xUnit = "";
                                        end
                                        xMaxVal = max([xMaxVal; max(xData)]);
                                        xaxislabel = [xDim " / " xUnit];
                                        %TODO: plot unterdrücken, wenn
                                        %x-variable nicht im Modell
                                        %auftaucht!

                                end
        
                                if ~isempty(xData)
                                    if app.DisplayerrorsSwitch.Value == "On"
                                        tPh = errorbar(app.UIAxes, xData, thisPlotData, thisPlotErrs, '.', ...
                                            'Marker', markertypes{iGroup}, 'MarkerSize', 5, ...
                                            'Color', app.UIAxes.ColorOrder(ii,:));
                                    else
                                        tPh = plot(app.UIAxes, xData, thisPlotData, '.', ...
                                            'Marker', markertypes{iGroup}, 'MarkerSize', 8, ...
                                            'Color', app.UIAxes.ColorOrder(ii,:));
                                    end
                                    
                                    tPh.DisplayName = app.DataGroups(iGroup).Name;
                                    if isFstPlotOfThisModel
                                        isFstPlotOfThisModel = false;
                                    else
                                        tPh.Annotation.LegendInformation.IconDisplayStyle = 'off';
                                    end
                                end
                            end
                            yMaxVal = max([yMaxVal; max(thisPlotData)]);
                        end
    
                        
                    end
                end
                app.UIAxes.NextPlot = "replace";
                app.UIAxes.XScale = app.xaxisscaleSwitch.Value;
                app.UIAxes.YScale = app.yaxisscaleSwitch.Value;

                if numel(app.UIAxes.Children) > 0
                    if any(strcmp(app.xaxisDropDown.Value, {'dataset', 'goodness'}))
                        xfact = 1;
                    else
                        [newxMaxVal, xUnit] = app.exp2pref(xMaxVal, xUnit);
                        xfact = newxMaxVal/xMaxVal;
                        xaxislabel = [xDim ' / ' xUnit];
                    end

                    if strcmp(valName, 'goodness') 
                        yfact = 1;
                    else
                        [newyMaxVal, yUnit] = app.exp2pref(yMaxVal, yUnit);
                        yfact = newyMaxVal/yMaxVal;
                        yaxislabel = [yDim ' / ' yUnit];
                    end

                    for ii = 1:length(app.UIAxes.Children)
                        app.UIAxes.Children(ii).XData = app.UIAxes.Children(ii).XData *xfact;
                        app.UIAxes.Children(ii).YData = app.UIAxes.Children(ii).YData *yfact;
                        if app.DisplayerrorsSwitch.Value == "On"
                            app.UIAxes.Children(ii).YNegativeDelta = app.UIAxes.Children(ii).YNegativeDelta *yfact;
                            app.UIAxes.Children(ii).YPositiveDelta = app.UIAxes.Children(ii).YPositiveDelta *yfact;
                        end
                    end                    
        
                    app.UIAxes.XLabel.String = xaxislabel;
                    app.UIAxes.YLabel.String = yaxislabel;
    
                    lh = legend(app.UIAxes, app.Models.Names(modelsToPlot),"Location","best");
                end
            end

            


        end
        
        function [new_value, unit_w_prefix]= exp2pref(app, old_value, varargin)
            
            if nargin == 3
                bare_unit = varargin{1};
                if iscell(bare_unit) && numel(bare_unit) > 1                    
                    if numel(bare_unit) == numel(bare_unit)
                        if all(strcmp(bare_unit{1}, bare_unit))
                            error('Imput units must all be equal.')
                        else
                            bare_unit = bare_unit{1};
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
        
        function loadData(app, fitdata)
            %expects fitdata as cell of structures with the structures having
            %the following fields:
            %coefs, coefdims, coefvals, coeferrs
            %(optional) evals, evaldims, evalvals, evalerrs
            %fitmodel OR fitmodelLong

            if iscell(fitdata)
                checkCell = cellfun(@(x) (isempty(x) | ...
                    (isfield(x,'coefs') & isfield(x,'coefdims') & isfield(x,'coefvals') & isfield(x,'coeferrs') &...
                    isfield(x,'fitmodel') & isfield(x,'fitmodelLong')) )...
                    , fitdata);
                if ~all(checkCell,"all")
                    uialert(app.FitvalueoverviewUIFigure,"File Error","Error",...
                    "Modal",true,"Icon","error");
                return
                end

            else
                uialert(app.FitvalueoverviewUIFigure,"File Error","Error",...
                    "Modal",true,"Icon","error");
                return
            end

            %if check is o.k.
            app.fits = fitdata;


            if ~isvector(app.fits)
                existModels = all(cellfun(@(x) isempty(x) ,app.fits), 1);
                app.fits(:,existModels) = [];
            end

            hasLongName = cellfun(@(x) ~isempty(x) && isfield(x, 'fitmodelLong'),app.fits);
            hasModelID = cellfun(@(x) ~isempty(x) && isfield(x, 'fitmodel'),app.fits);
            emptyIDs = cellfun(@(x) isempty(x),app.fits);
            
            modelIDs = cell(size(app.fits));
            modelNames = modelIDs;

            

            if sum(hasLongName+hasModelID,"all")/2 + sum(emptyIDs,"all") < numel(app.fits)
                %what to do if names are not provided...?
            else
                modelNames(hasLongName) = cellfun(@(x) x.fitmodelLong,app.fits(hasLongName), "UniformOutput",false);
                modelIDs(hasModelID) = cellfun(@(x) x.fitmodel,app.fits(hasModelID), "UniformOutput",false);
            end

            modelIDs(emptyIDs) = cellfun(@(x) '', cell(sum(emptyIDs,'all'),1), "UniformOutput", false);

            [uniqueModelIDs, uniqueIdxs] = unique(modelIDs,"sorted");
            if isempty(uniqueModelIDs{1}) && numel(uniqueModelIDs) > 1
                uniqueModelIDs(1) = [];
                uniqueIdxs(1) = [];
            end

            uniqueModelNames = modelNames(uniqueIdxs);

            if isempty(uniqueModelIDs{1})
                uniqueModelIDs{1} = [];
            end

            %set properties(global variables)

            app.ModelParameters = cellfun(@(x) [x.coefs; x.evals] ,app.fits(uniqueIdxs),"UniformOutput",false);
            allParameters = unique(vertcat(app.ModelParameters{:}));
            app.Models.IDs = uniqueModelIDs;
            app.Models.Names = uniqueModelNames;
            app.Models.uIdxs = uniqueIdxs;
            app.Models.Idxs = cellfun(@(x) find(strcmp(x, modelIDs)), uniqueModelIDs, "UniformOutput",false);

            app.binsSpinnerVals = cellfun(@(x) zeros(length(x)+2,1) ,app.ModelParameters, "UniformOutput",false);
            app.binsSizeVals = cellfun(@(x) zeros(length(x)+2,1) ,app.ModelParameters, "UniformOutput",false);

            %set interactive tools properties
            app.ValuetoplotDropDown.Items = [{'max. indent.';'goodness of fit'}; allParameters];
            app.ValuetoplotDropDown.ItemsData = [{'indent';'goodness'}; allParameters];

            app.xaxisDropDown.Items = [{'dataset no.';'max. indent.';'goodness of fit'}; allParameters];
            app.xaxisDropDown.ItemsData = [{'dataset';'indent';'goodness'}; allParameters];

            validModels = find(cellfun(@(x) any(strcmp(allParameters(1), x)),app.ModelParameters));

            %select only models which contain the 1st parameter
            app.FittypeDropDown.Items = uniqueModelNames(validModels);
            app.FittypeDropDown.ItemsData = uniqueModelIDs(validModels);            
            app.FittypeDropDown.Value = app.FittypeDropDown.ItemsData(1);
            
            %put all models in Table
            app.UITable.Data = [uniqueModelNames num2cell(true(size(uniqueModelNames)))];

            app.FittypeDropDownValueChanged([]);

            %enable UI components
            app.SavedataMenu.Enable = "on";
            app.SavecurrentplotMenu.Enable = "on";

            app.ValuetoplotDropDown.Enable = "on";

            app.HistogramBinsSpinner.Enable = "on";
            app.FittypeDropDown.Enable = "on";

            app.UITable.Enable = "on";
            app.yaxisscaleSwitch.Enable = "on";
            app.xaxisDropDown.Enable = "on";
            app.DisplayerrorsSwitch.Enable = "on";
            
        end
        
        
        function initializeApp(app)
            %set properties(global variables)

            app.ModelParameters = {"--"};
            %allParameters = unique(vertcat(app.ModelParameters{:}));
            app.Models = struct('IDs','','Names','','uIDxs','','Idxs','');
            app.binsSpinnerVals = {0};
            app.binsSizeVals = {0};

            %set interactive tools properties
            app.ValuetoplotDropDown.Items = {'--'};

            %select only models which contain the 1st parameter
            app.FittypeDropDown.Items = {'--'};
            app.FittypeDropDown.ItemsData = {'--'};
            app.FittypeDropDown.Value = '--';
            
            %put all models in Table
            app.UITable.Data = {'---' false};


            cla(app.UIAxes);

            %disable UI components
            app.SavedataMenu.Enable = "off";
            app.SavecurrentplotMenu.Enable = "off";

            app.ValuetoplotDropDown.Enable = "off";

            app.HistogramBinsSpinner.Enable = "off";
            app.FittypeDropDown.Enable = "off";

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
            %expects input as cell of structures with the structures having
            %the following fields:
            %coefs, coefdims, coefvals, coeferrs
            %(optional) evals, evaldims, evalvals, evalerrs
            %fitmodel OR fitmodelLong

            app.initializeApp;

            if nargin > 1
                app.loadData(varargin{1});
                if nargin > 2
                    if isstruct(varargin{2}) && isfield(varargin{2}, 'Idxs') && numel([varargin{2}.Idxs]) == size(app.fits,1)
                        app.DataGroups = varargin{2};
                    else
                        uialert(app.FitvalueoverviewUIFigure,'Sizes don''t fit', 'Input Error','Icon','error');
                    end
                end
            end
            if ~isempty(app.fits)
                app.actualize_plot();
            end
        end

        % Value changed function: FittypeDropDown
        function FittypeDropDownValueChanged(app, event)
            selModelIdx = strcmp(app.FittypeDropDown.Value, app.FittypeDropDown.ItemsData);
          
            ValueToPlot = app.ValuetoplotDropDown.Value;
            if strcmp(ValueToPlot,'indent')
                thisModelValueIdx = 1;
            elseif strcmp(ValueToPlot,'goodness')
                thisModelValueIdx = 2;
            else
                thisModelValueIdx = find(strcmp(ValueToPlot,app.ModelParameters{selModelIdx}),1);
            end
            
            app.HistogramBinsSpinner.Value = app.binsSpinnerVals{selModelIdx}(thisModelValueIdx);
            app.EditField.Value = app.binsSizeVals{selModelIdx}(thisModelValueIdx);
            
            app.actualize_plot();
        end

        % Value changed function: ValuetoplotDropDown
        function ValuetoplotDropDownValueChanged(app, event)
            value = app.ValuetoplotDropDown.Value;
            valIdx = find(strcmp(value, app.ValuetoplotDropDown.ItemsData),1);
            
            if valIdx > 2
                validModels = find(cellfun(@(x) any(strcmp(value, x)),app.ModelParameters));
            else
                validModels = (1:length(app.ModelParameters));
            end

            app.FittypeDropDown.Items = app.Models.Names(validModels);
            app.FittypeDropDown.ItemsData = app.Models.IDs(validModels);            
            app.FittypeDropDown.Value = app.FittypeDropDown.ItemsData(1);

            if valIdx > 2
            thisModelValueIdx = find(strcmp(value,app.ModelParameters{validModels(1)}),1);
            app.HistogramBinsSpinner.Value = app.binsSpinnerVals{validModels(1)}(thisModelValueIdx);
            app.EditField.Value = app.binsSizeVals{validModels(1)}(thisModelValueIdx);
            else
                app.HistogramBinsSpinner.Value = app.binsSpinnerVals{validModels(1)}(valIdx);
                app.EditField.Value = app.binsSizeVals{validModels(1)}(valIdx);
            end
            app.actualize_plot();
        end

        % Value changed function: HistogramBinsSpinner
        function HistogramBinsSpinnerValueChanged(app, event)
            value = app.HistogramBinsSpinner.Value;
            modelIdx = find(strcmp(app.FittypeDropDown.Value, app.Models.IDs),1);
            valIdx = find(strcmp(app.ValuetoplotDropDown.Value, app.ModelParameters{modelIdx}),1);
            app.binsSpinnerVals{modelIdx}(valIdx) = value;
            app.actualize_plot();
        end

        % Value changed function: EditField
        function EditFieldValueChanged(app, event)
            value = app.EditField.Value;
            modelIdx = find(strcmp(app.FittypeDropDown.Value, app.Models.IDs),1);
            valIdx = find(strcmp(app.ValuetoplotDropDown.Value, app.ModelParameters{modelIdx}),1);
            app.binsSizeVals{modelIdx}(valIdx) = value;
            app.actualize_plot();            
        end

        % Callback function: ButtonGroup, DisplayerrorsSwitch, TabGroup, 
        % ...and 4 other components
        function JustActualize_Callback(app, event)
            if ~isempty(app.fits)
                app.actualize_plot();
            end
        end

        % Menu selected function: OpendataMenu
        function OpendataMenuSelected(app, event)
            [files, path]=(uigetfile([pwd,'/.mat'],'MultiSelect','off'));
            if isnumeric(files) && files == 0, return; end   %end execution if user pressed "cancel"
            load(fullfile(path, files), 'fitdata');
            
            if isstruct(fitdata)
                app.DataGroups = fitdata.groups;
                fitdata = fitdata.fits;
            end

            app.loadData(fitdata);
        end

        % Menu selected function: SavedataMenu
        function SavedataMenuSelected(app, event)
            [dfilename, pathname] = uiputfile({'/*.mat'},...
                    'Save fits', [pwd]);

            fitdata = struct('fits', {app.fits}, 'groups', {app.DataGroups});

            save([pathname dfilename], "fitdata");
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
            app.TabGroup.Position = [4 19 196 304];

            % Create HistogramTab
            app.HistogramTab = uitab(app.TabGroup);
            app.HistogramTab.Title = 'Histogram';

            % Create FittypeDropDownLabel
            app.FittypeDropDownLabel = uilabel(app.HistogramTab);
            app.FittypeDropDownLabel.Position = [14 240 46 22];
            app.FittypeDropDownLabel.Text = 'Fit type';

            % Create FittypeDropDown
            app.FittypeDropDown = uidropdown(app.HistogramTab);
            app.FittypeDropDown.ValueChangedFcn = createCallbackFcn(app, @FittypeDropDownValueChanged, true);
            app.FittypeDropDown.Position = [14 211 100 22];

            % Create ButtonGroup
            app.ButtonGroup = uibuttongroup(app.HistogramTab);
            app.ButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.ButtonGroup.Title = 'Button Group';
            app.ButtonGroup.Position = [5 64 184 129];

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

            % Create byDatasetTab
            app.byDatasetTab = uitab(app.TabGroup);
            app.byDatasetTab.Title = 'by Dataset';

            % Create DisplayerrorsSwitchLabel
            app.DisplayerrorsSwitchLabel = uilabel(app.byDatasetTab);
            app.DisplayerrorsSwitchLabel.HorizontalAlignment = 'center';
            app.DisplayerrorsSwitchLabel.Position = [8 26 79 22];
            app.DisplayerrorsSwitchLabel.Text = 'Display errors';

            % Create DisplayerrorsSwitch
            app.DisplayerrorsSwitch = uiswitch(app.byDatasetTab, 'slider');
            app.DisplayerrorsSwitch.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.DisplayerrorsSwitch.Position = [132 30 33 14];

            % Create UITable
            app.UITable = uitable(app.byDatasetTab);
            app.UITable.ColumnName = {'Model Name'; 'Show?'};
            app.UITable.RowName = {};
            app.UITable.ColumnEditable = [false true];
            app.UITable.CellEditCallback = createCallbackFcn(app, @JustActualize_Callback, true);
            app.UITable.Position = [7 160 179 113];

            % Create xaxisDropDownLabel
            app.xaxisDropDownLabel = uilabel(app.byDatasetTab);
            app.xaxisDropDownLabel.HorizontalAlignment = 'right';
            app.xaxisDropDownLabel.Position = [8 121 41 22];
            app.xaxisDropDownLabel.Text = 'x-axis:';

            % Create xaxisDropDown
            app.xaxisDropDown = uidropdown(app.byDatasetTab);
            app.xaxisDropDown.Items = {'dataset no.', 'max. indent.', 'goodness of fit'};
            app.xaxisDropDown.ItemsData = {'dataset', 'indent', 'goodness'};
            app.xaxisDropDown.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.xaxisDropDown.Position = [65 121 100 22];
            app.xaxisDropDown.Value = 'dataset';

            % Create yaxisscaleLabel
            app.yaxisscaleLabel = uilabel(app.byDatasetTab);
            app.yaxisscaleLabel.HorizontalAlignment = 'center';
            app.yaxisscaleLabel.Position = [18 61 69 22];
            app.yaxisscaleLabel.Text = 'y-axis scale';

            % Create yaxisscaleSwitch
            app.yaxisscaleSwitch = uiswitch(app.byDatasetTab, 'slider');
            app.yaxisscaleSwitch.Items = {'linear', 'log'};
            app.yaxisscaleSwitch.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.yaxisscaleSwitch.Position = [134 65 33 15];
            app.yaxisscaleSwitch.Value = 'linear';

            % Create xaxisscaleSwitchLabel
            app.xaxisscaleSwitchLabel = uilabel(app.byDatasetTab);
            app.xaxisscaleSwitchLabel.HorizontalAlignment = 'center';
            app.xaxisscaleSwitchLabel.Position = [17 82 69 22];
            app.xaxisscaleSwitchLabel.Text = 'x-axis scale';

            % Create xaxisscaleSwitch
            app.xaxisscaleSwitch = uiswitch(app.byDatasetTab, 'slider');
            app.xaxisscaleSwitch.Items = {'linear', 'log'};
            app.xaxisscaleSwitch.ValueChangedFcn = createCallbackFcn(app, @JustActualize_Callback, true);
            app.xaxisscaleSwitch.Position = [133 86 33 15];
            app.xaxisscaleSwitch.Value = 'linear';

            % Show the figure after all components are created
            app.FitvalueoverviewUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ShowIndEvalData_exported(varargin)

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