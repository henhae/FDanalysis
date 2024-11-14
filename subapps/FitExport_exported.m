classdef FitExport_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        FitExportUIFigure              matlab.ui.Figure
        FilestoexportButtonGroup       matlab.ui.container.ButtonGroup
        onlyselectedfilesButton        matlab.ui.control.RadioButton
        allfilesButton                 matlab.ui.control.RadioButton
        ChoosefolderfilenameEditField  matlab.ui.control.EditField
        ChoosefolderfilenameEditFieldLabel  matlab.ui.control.Label
        ChooseFolderButton             matlab.ui.control.Button
        ExModelParameterCheckBox       matlab.ui.control.CheckBox
        ExDataCheckBox                 matlab.ui.control.CheckBox
        CancelButton                   matlab.ui.control.Button
        OKButton                       matlab.ui.control.Button
        ChoosefitmodelDropDown         matlab.ui.control.DropDown
        ChoosefitmodelDropDownLabel    matlab.ui.control.Label
    end

    
    properties (Access = private)
        MainApp  % Description
        Folder
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, MainApp)
            app.MainApp = MainApp;
            app.MainApp.subapp.FitExport = app.FitExportUIFigure;
            %app.Folder = app.MainApp.LastFolder;
            app.Folder = pwd;

            app.FitExportUIFigure.Position(1:2) = MainApp.FDUIFigure.Position(1:2) + ...
                0.5*(MainApp.FDUIFigure.Position(3:4) - app.FitExportUIFigure.Position(3:4));

            %fill fit model dropdown menu
            getPropOfExistingFitsFun = @(x,y) arrayfun(@(z) z.model.(y), x.DataFits, 'UniformOutput', false);
            allModelIDs = cell(0);
            allModelNames = cell(0);
            for ii = 1:numel(MainApp.Data)
                allModelIDs = [allModelIDs getPropOfExistingFitsFun(MainApp.Data(ii), 'ID')];
                allModelNames = [allModelNames getPropOfExistingFitsFun(MainApp.Data(ii), 'name')];
            end
            [allModelIDs, uniqueIDxs, ~] = unique(allModelIDs);
            allModelNames = allModelNames(uniqueIDxs);

            app.ChoosefitmodelDropDown.Items = allModelNames;
            app.ChoosefitmodelDropDown.ItemsData = allModelIDs;


        end

        % Callback function: CancelButton, FitExportUIFigure
        function FitExportUIFigureCloseRequest(app, event)
            if isvalid(app.MainApp)
                app.MainApp.subapp.FitExport = [];
            end
            delete(app)  
        end

        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            %construct output structure
            if strcmp(app.FilestoexportButtonGroup.SelectedObject.Text, 'all files')
                fileIDs = (1:numel(app.MainApp.Data));
            else
                fileIDs = app.MainApp.iSelectedData;
            end
            iExport = false(size(app.MainApp.Data));
            iExport(fileIDs) = true;

            outp = struct('modelID', app.ChoosefitmodelDropDown.Value ...
                ,'exportData', app.ExDataCheckBox.Value ...
                ,'exportParams', app.ExModelParameterCheckBox.Value...
                ,'saveDest', app.ChoosefolderfilenameEditField.Value ...
                ,'dataToExp', iExport...
                );

            app.MainApp.exportFits(outp);
            app.FitExportUIFigureCloseRequest();


        end

        % Button pushed function: ChooseFolderButton
        function ChooseFolderButtonPushed(app, event)
            filename = app.MainApp.DataNames{app.MainApp.iSelectedData(1)};
            lastdotIdx = find(filename == '.', 1,"last");
            if isempty(lastdotIdx)
                lastdotIdx = numel(filename)+1;
            end
            filename = filename(1:lastdotIdx-1);
            
            [dfilename, pathname] = uiputfile({'/*.txt'},...
                        'Save', [app.Folder filename '_curves']);
            app.Folder = fullfile(pathname, filename);
            app.ChoosefolderfilenameEditField.Value = fullfile(pathname, dfilename);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create FitExportUIFigure and hide until all components are created
            app.FitExportUIFigure = uifigure('Visible', 'off');
            app.FitExportUIFigure.Position = [100 100 238 285];
            app.FitExportUIFigure.Name = 'Fit Export';
            app.FitExportUIFigure.CloseRequestFcn = createCallbackFcn(app, @FitExportUIFigureCloseRequest, true);

            % Create ChoosefitmodelDropDownLabel
            app.ChoosefitmodelDropDownLabel = uilabel(app.FitExportUIFigure);
            app.ChoosefitmodelDropDownLabel.HorizontalAlignment = 'right';
            app.ChoosefitmodelDropDownLabel.Position = [15 249 97 22];
            app.ChoosefitmodelDropDownLabel.Text = 'Choose fit model';

            % Create ChoosefitmodelDropDown
            app.ChoosefitmodelDropDown = uidropdown(app.FitExportUIFigure);
            app.ChoosefitmodelDropDown.Position = [16 228 200 22];

            % Create OKButton
            app.OKButton = uibutton(app.FitExportUIFigure, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            app.OKButton.Position = [23 19 84 22];
            app.OKButton.Text = 'OK';

            % Create CancelButton
            app.CancelButton = uibutton(app.FitExportUIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @FitExportUIFigureCloseRequest, true);
            app.CancelButton.Position = [136 19 84 22];
            app.CancelButton.Text = 'Cancel';

            % Create ExDataCheckBox
            app.ExDataCheckBox = uicheckbox(app.FitExportUIFigure);
            app.ExDataCheckBox.Text = 'Export data and data fits to file';
            app.ExDataCheckBox.Position = [20 197 187 22];

            % Create ExModelParameterCheckBox
            app.ExModelParameterCheckBox = uicheckbox(app.FitExportUIFigure);
            app.ExModelParameterCheckBox.Text = 'Export model parameter to file';
            app.ExModelParameterCheckBox.Position = [20 167 185 22];

            % Create ChooseFolderButton
            app.ChooseFolderButton = uibutton(app.FitExportUIFigure, 'push');
            app.ChooseFolderButton.ButtonPushedFcn = createCallbackFcn(app, @ChooseFolderButtonPushed, true);
            app.ChooseFolderButton.Icon = 'file-export-solid.svg';
            app.ChooseFolderButton.Tooltip = {'Filenames will be automatically appended with ''_curves'' and ''_fitpars''.'};
            app.ChooseFolderButton.Position = [18 116 30 22];
            app.ChooseFolderButton.Text = '';

            % Create ChoosefolderfilenameEditFieldLabel
            app.ChoosefolderfilenameEditFieldLabel = uilabel(app.FitExportUIFigure);
            app.ChoosefolderfilenameEditFieldLabel.Position = [20 140 130 22];
            app.ChoosefolderfilenameEditFieldLabel.Text = 'Choose folder/filename';

            % Create ChoosefolderfilenameEditField
            app.ChoosefolderfilenameEditField = uieditfield(app.FitExportUIFigure, 'text');
            app.ChoosefolderfilenameEditField.Editable = 'off';
            app.ChoosefolderfilenameEditField.Position = [59 116 156 22];
            app.ChoosefolderfilenameEditField.Value = '...';

            % Create FilestoexportButtonGroup
            app.FilestoexportButtonGroup = uibuttongroup(app.FitExportUIFigure);
            app.FilestoexportButtonGroup.Title = 'Files to export';
            app.FilestoexportButtonGroup.Position = [16 57 205 52];

            % Create allfilesButton
            app.allfilesButton = uiradiobutton(app.FilestoexportButtonGroup);
            app.allfilesButton.Text = 'all files';
            app.allfilesButton.Position = [11 6 58 22];
            app.allfilesButton.Value = true;

            % Create onlyselectedfilesButton
            app.onlyselectedfilesButton = uiradiobutton(app.FilestoexportButtonGroup);
            app.onlyselectedfilesButton.Text = 'only selected files';
            app.onlyselectedfilesButton.Position = [77 6 118 22];

            % Show the figure after all components are created
            app.FitExportUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FitExport_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.FitExportUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.FitExportUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.FitExportUIFigure)
        end
    end
end