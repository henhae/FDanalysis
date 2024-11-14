classdef FitModelEdit_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        FitmodeleditingUIFigure        matlab.ui.Figure
        TestButton                     matlab.ui.control.Button
        CancelButton                   matlab.ui.control.Button
        OKButton                       matlab.ui.control.Button
        FitmodelpropertiesLabel        matlab.ui.control.Label
        parametersEditField            matlab.ui.control.EditField
        parametersEditFieldLabel       matlab.ui.control.Label
        UITable                        matlab.ui.control.Table
        SIunitEditField_2              matlab.ui.control.EditField
        SIunitLabel_2                  matlab.ui.control.Label
        dependentvariableyEditField    matlab.ui.control.EditField
        dependentvariableyEditFieldLabel  matlab.ui.control.Label
        SIunitEditField                matlab.ui.control.EditField
        SIunitLabel                    matlab.ui.control.Label
        independentvariablexEditField  matlab.ui.control.EditField
        independentvariablexEditFieldLabel  matlab.ui.control.Label
        FunctionTextArea               matlab.ui.control.TextArea
        FunctionLabel                  matlab.ui.control.Label
        DescriptionTextArea            matlab.ui.control.TextArea
        DescriptionTextAreaLabel       matlab.ui.control.Label
        CategoryEditField              matlab.ui.control.EditField
        CategoryEditFieldLabel         matlab.ui.control.Label
        NameEditField                  matlab.ui.control.EditField
        NameLabel                      matlab.ui.control.Label
        IDEditField                    matlab.ui.control.EditField
        IDLabel                        matlab.ui.control.Label
    end

    
    properties (Access = private)
        CallingApp        % Description
        editModelID       %ID of the model to be edited (empty for new models!)
    end
    
    methods (Access = private)
        
        function results = variableInFormularPatter(app, varName)
            %variable name must be surrounded by either mathematical
            %operations, whitespace or be at the end of the string.
            mathOpsPattern = characterListPattern("+-*/^.,()");
            boundaryPattern = whitespacePattern | textBoundary | mathOpsPattern;
            befPat = lookBehindBoundary(boundaryPattern);
            aftPat = lookAheadBoundary(boundaryPattern);

            results = befPat + varName + aftPat;
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, CallingApp, model)
            app.CallingApp = CallingApp;
            
            if ~isempty(model)
                if ~isa(model, "fitmodelDef")
                    error('wrong input')
                end
                app.IDEditField.Value = model.ID;
                app.IDEditField.Editable = "off";
                app.editModelID = model.ID;
                app.NameEditField.Value = model.name;
                app.DescriptionTextArea.Value = model.description;
                app.CategoryEditField.Value = model.category;
                if model.isLinear
                    app.FunctionTextArea.Value = strjoin(model.inputfunction, '; ');
                else
                    app.FunctionTextArea.Value = model.funcStr;
                end
                app.independentvariablexEditField.Value = model.independent;
                app.SIunitEditField.Value = model.independentdim;
                app.dependentvariableyEditField.Value = model.dependent;
                app.SIunitEditField_2.Value = model.dependentdim;
                app.parametersEditField.Value = strjoin(model.parameters, ', ');

                app.UITable.Data = table(...
                'Size', [numel(model.parameters), 4] ...
                ,'VariableTypes', {'string', 'double', 'double', 'string'}...
                ,'RowNames', model.parameters'...
                ,'VariableNames', {'SI unit','L bound','U bound', 'description'}...
                );
                 app.UITable.Data.(1) = model.parameterdims';
                 app.UITable.Data.('L bound') = model.parameter_lbounds';
                 app.UITable.Data.('U bound') = model.parameter_ubounds';
                 if isempty(model.parameterdescription)
                     app.UITable.Data.(4) = cell(numel(model.parameters),1 );
                 else
                    app.UITable.Data.(4) = model.parameterdescription';
                 end
                 
                 app.UITable.RowName = model.parameters;
                 app.UITable.ColumnEditable = true(1,4);
            else
                app.editModelID = '';
            end
        end

        % Value changed function: parametersEditField
        function parametersEditFieldValueChanged(app, event)
            oldVal = event.PreviousValue;
            value = app.parametersEditField.Value;

            newParams = strip(split(value, ','));
            if ~isempty(oldVal)
                oldTab = app.UITable.Data;
                oldParams = app.UITable.RowName;
            else
                oldParams = [];
            end
            
            
            
            
            app.UITable.Data = table(...
                'Size', [numel(newParams), 4] ...
                ,'VariableTypes', {'string', 'double', 'double', 'string'}...
                ,'RowNames', newParams'...
                ,'VariableNames', {'SI unit','L bound','U bound', 'description'}...
                );
            app.UITable.RowName = app.UITable.Data.Properties.RowNames;
            for ii = 1:numel(newParams)
                oldIdx = find(strcmp(newParams{ii}, oldParams),1);
                if ~isempty(oldIdx)
                    app.UITable.Data(ii,:) = oldTab(oldIdx,:);
                else
                    app.UITable.Data(ii,:) = [{''}, -Inf, Inf, {''}];
                end
            end
           
            
        end

        % Button pushed function: TestButton
        function TestButtonPushed(app, event)
            
            try
                paramStr = app.parametersEditField.Value;
                paramCell = strip(split(paramStr, ','));
    
                if contains(app.FunctionTextArea.Value, ';') %function with linear coefficients
                    newFct = strip(split(app.FunctionTextArea.Value, ';')');
                    if numel(paramCell) > 0 && numel(paramCell) ~= numel(newFct)
                        uialert(app.FitmodeleditingUIFigure...
                            ,'Number of parameters not equal to number of function terms.'...
                            , 'Error' ,'Icon','error');
                        return
                    end
    
                else %non-linear function definition
            
                    if isempty(app.independentvariablexEditField.Value)
                        indepName = 'x';
                    else
                        indepName = app.independentvariablexEditField.Value;
                    end
        
                    fctStr = "@(" + join(paramCell, ', ') + ', ' + indepName ...
                                + ")" + app.FunctionTextArea.Value;
                    newFct = str2func(fctStr);
                end

            
                success = true;
                oldwarn = lastwarn('', "");
                newModel = fitmodelDef(newFct);
                newwarn = lastwarn;
                if ~isempty(newwarn) %|| ~strcmp(oldwarn, newwarn)
                    uialert(app.FitmodeleditingUIFigure, newwarn,...
                    'Warning', 'Icon','warning');
                    success = false;
                end
            catch ME
                uialert(app.FitmodeleditingUIFigure, ME.message,'Error', ...
                    'Icon','error');
                success = false;
                return
            end

            try
                newModel.fitType;
            catch
                uialert(app.FitmodeleditingUIFigure, ...
                    'Function could not be transformed to model function. Something went wrong. Please check declaration.',...
                    'Error', 'Icon','error');
                return
            end

            if success
                uialert(app.FitmodeleditingUIFigure, 'Function check successful.',...
                    'Success', 'Icon', 'success');
            end


        end

        % Callback function: CancelButton, FitmodeleditingUIFigure
        function FitmodeleditingUIFigureCloseRequest(app, event)
            delete(app)
            
        end

        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            %collect all entries
            newModelStruct = struct();
            newModelStruct.ID = app.IDEditField.Value;
            newModelStruct.Name = app.NameEditField.Value;
            newModelStruct.Description = app.DescriptionTextArea.Value;
            newModelStruct.Category = app.CategoryEditField.Value;

            if contains(app.FunctionTextArea.Value, ';')
                newModelStruct.Function = strip(split(app.FunctionTextArea.Value,';')');
                newModelStruct.Coefficients = strip(split(app.parametersEditField.Value,[";",","])');
                newModelStruct.CoeffUnits = app.UITable.Data{:,1}';
                newModelStruct.XName = app.independentvariablexEditField.Value;
            else
                fctStr = "@(" + app.parametersEditField.Value + ", " + app.independentvariablexEditField.Value + ")" ...
                    + app.FunctionTextArea.Value;
                newModelStruct.Function = fctStr;
                %parameters are automatically detected
                newModelStruct.ParameterUnits = app.UITable.Data{:,1}';
            end
            newModelStruct.ParameterLBounds = app.UITable.Data{:,2}';
            newModelStruct.ParameterUBounds = app.UITable.Data{:,3}';
            newModelStruct.ParameterDescription = app.UITable.Data{:,4}';

            newModelStruct.XUnit = app.SIunitEditField.Value;
            newModelStruct.YName = app.dependentvariableyEditField.Value;
            newModelStruct.YUnit = app.SIunitEditField_2.Value;

            try
                oldwarn = lastwarn('', "");
                newModel = fitmodelDef(newModelStruct);
                newwarn = lastwarn;
                if ~isempty(newwarn) %|| ~strcmp(oldwarn, newwarn)
                    error(['Warning occured while creating model: ' newwarn]);
                end

                %if model is new, check if modelID already exists
                if isempty(app.editModelID) && any(arrayfun(@(x) strcmp(newModel.ID,x.ID), app.CallingApp.fit_models))
                    error('ID is already in use. Please choose a different one.')
                end
            catch ME
                uialert(app.FitmodeleditingUIFigure, ME.message, 'Error', ...
                    'Icon','error');
                return
            end
            
            modelIdx = find(arrayfun(@(x) strcmp(x.ID, newModelStruct.ID), app.CallingApp.fit_models),1);
            if isempty(modelIdx)
                modelIdx = numel(app.CallingApp.fit_models)+1;
            end
            app.CallingApp.fit_models(modelIdx) = newModel;
            app.CallingApp.buildModelTree();

            app.FitmodeleditingUIFigureCloseRequest();
            
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create FitmodeleditingUIFigure and hide until all components are created
            app.FitmodeleditingUIFigure = uifigure('Visible', 'off');
            app.FitmodeleditingUIFigure.Position = [100 100 414 524];
            app.FitmodeleditingUIFigure.Name = 'Fitmodel editing';
            app.FitmodeleditingUIFigure.CloseRequestFcn = createCallbackFcn(app, @FitmodeleditingUIFigureCloseRequest, true);

            % Create IDLabel
            app.IDLabel = uilabel(app.FitmodeleditingUIFigure);
            app.IDLabel.HorizontalAlignment = 'right';
            app.IDLabel.Position = [44 459 25 22];
            app.IDLabel.Text = 'ID*';

            % Create IDEditField
            app.IDEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.IDEditField.Tooltip = {'unique identifier'};
            app.IDEditField.Position = [76 459 278 22];

            % Create NameLabel
            app.NameLabel = uilabel(app.FitmodeleditingUIFigure);
            app.NameLabel.HorizontalAlignment = 'right';
            app.NameLabel.Position = [27 429 42 22];
            app.NameLabel.Text = 'Name*';

            % Create NameEditField
            app.NameEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.NameEditField.Position = [76 429 278 22];

            % Create CategoryEditFieldLabel
            app.CategoryEditFieldLabel = uilabel(app.FitmodeleditingUIFigure);
            app.CategoryEditFieldLabel.HorizontalAlignment = 'right';
            app.CategoryEditFieldLabel.Position = [14 397 55 22];
            app.CategoryEditFieldLabel.Text = 'Category';

            % Create CategoryEditField
            app.CategoryEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.CategoryEditField.Tooltip = {'Category to be placed in. Use "/" for sub-categories.'};
            app.CategoryEditField.Position = [76 397 278 22];

            % Create DescriptionTextAreaLabel
            app.DescriptionTextAreaLabel = uilabel(app.FitmodeleditingUIFigure);
            app.DescriptionTextAreaLabel.HorizontalAlignment = 'right';
            app.DescriptionTextAreaLabel.Position = [2 358 67 22];
            app.DescriptionTextAreaLabel.Text = 'Description';

            % Create DescriptionTextArea
            app.DescriptionTextArea = uitextarea(app.FitmodeleditingUIFigure);
            app.DescriptionTextArea.Position = [76 311 278 71];

            % Create FunctionLabel
            app.FunctionLabel = uilabel(app.FitmodeleditingUIFigure);
            app.FunctionLabel.HorizontalAlignment = 'right';
            app.FunctionLabel.Position = [10 273 56 22];
            app.FunctionLabel.Text = 'Function*';

            % Create FunctionTextArea
            app.FunctionTextArea = uitextarea(app.FitmodeleditingUIFigure);
            app.FunctionTextArea.Tooltip = {'given as full function declaration or semicolon separated list of terms (-> "linear function", linear fit parameters will be automatically added)'};
            app.FunctionTextArea.Position = [76 258 278 38];

            % Create independentvariablexEditFieldLabel
            app.independentvariablexEditFieldLabel = uilabel(app.FitmodeleditingUIFigure);
            app.independentvariablexEditFieldLabel.HorizontalAlignment = 'right';
            app.independentvariablexEditFieldLabel.Position = [9 229 134 22];
            app.independentvariablexEditFieldLabel.Text = 'independent variable (x)';

            % Create independentvariablexEditField
            app.independentvariablexEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.independentvariablexEditField.Tooltip = {'default: x. Must appear in the function declaration'};
            app.independentvariablexEditField.Position = [158 229 100 22];

            % Create SIunitLabel
            app.SIunitLabel = uilabel(app.FitmodeleditingUIFigure);
            app.SIunitLabel.HorizontalAlignment = 'right';
            app.SIunitLabel.Position = [296 229 44 22];
            app.SIunitLabel.Text = 'SI unit*';

            % Create SIunitEditField
            app.SIunitEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.SIunitEditField.Position = [353 229 55 22];

            % Create dependentvariableyEditFieldLabel
            app.dependentvariableyEditFieldLabel = uilabel(app.FitmodeleditingUIFigure);
            app.dependentvariableyEditFieldLabel.HorizontalAlignment = 'right';
            app.dependentvariableyEditFieldLabel.Position = [19 198 124 22];
            app.dependentvariableyEditFieldLabel.Text = 'dependent variable (y)';

            % Create dependentvariableyEditField
            app.dependentvariableyEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.dependentvariableyEditField.Position = [158 198 100 22];

            % Create SIunitLabel_2
            app.SIunitLabel_2 = uilabel(app.FitmodeleditingUIFigure);
            app.SIunitLabel_2.HorizontalAlignment = 'right';
            app.SIunitLabel_2.Position = [296 198 44 22];
            app.SIunitLabel_2.Text = 'SI unit*';

            % Create SIunitEditField_2
            app.SIunitEditField_2 = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.SIunitEditField_2.Position = [353 198 55 22];

            % Create UITable
            app.UITable = uitable(app.FitmodeleditingUIFigure);
            app.UITable.ColumnName = {'SI unit'; 'L bound'; 'U bound'; 'description'};
            app.UITable.RowName = {'''numbered'''};
            app.UITable.Position = [9 49 399 106];

            % Create parametersEditFieldLabel
            app.parametersEditFieldLabel = uilabel(app.FitmodeleditingUIFigure);
            app.parametersEditFieldLabel.HorizontalAlignment = 'right';
            app.parametersEditFieldLabel.Tooltip = {'comma separated list of fit parameters which appear in the function declaration (not necessary for linear functions)'};
            app.parametersEditFieldLabel.Position = [-2 166 66 22];
            app.parametersEditFieldLabel.Text = 'parameters';

            % Create parametersEditField
            app.parametersEditField = uieditfield(app.FitmodeleditingUIFigure, 'text');
            app.parametersEditField.ValueChangedFcn = createCallbackFcn(app, @parametersEditFieldValueChanged, true);
            app.parametersEditField.Position = [79 166 275 22];

            % Create FitmodelpropertiesLabel
            app.FitmodelpropertiesLabel = uilabel(app.FitmodeleditingUIFigure);
            app.FitmodelpropertiesLabel.FontSize = 16;
            app.FitmodelpropertiesLabel.FontWeight = 'bold';
            app.FitmodelpropertiesLabel.Position = [14 495 159 22];
            app.FitmodelpropertiesLabel.Text = 'Fit model properties';

            % Create OKButton
            app.OKButton = uibutton(app.FitmodeleditingUIFigure, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            app.OKButton.Position = [14 14 100 22];
            app.OKButton.Text = 'OK';

            % Create CancelButton
            app.CancelButton = uibutton(app.FitmodeleditingUIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @FitmodeleditingUIFigureCloseRequest, true);
            app.CancelButton.Position = [134 14 100 22];
            app.CancelButton.Text = 'Cancel';

            % Create TestButton
            app.TestButton = uibutton(app.FitmodeleditingUIFigure, 'push');
            app.TestButton.ButtonPushedFcn = createCallbackFcn(app, @TestButtonPushed, true);
            app.TestButton.Position = [359 273 49 22];
            app.TestButton.Text = 'Test';

            % Show the figure after all components are created
            app.FitmodeleditingUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FitModelEdit_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.FitmodeleditingUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.FitmodeleditingUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.FitmodeleditingUIFigure)
        end
    end
end