classdef autocorrect_options_m < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        DatacorrectionoptionsUIFigure   matlab.ui.Figure
        BaselinenoisethresholdEditField  matlab.ui.control.NumericEditField
        BaselinenoisethresholdEditFieldLabel  matlab.ui.control.Label
        Bl_osc                          matlab.ui.control.DropDown
        SubtractbaselineoscillationDropDownLabel  matlab.ui.control.Label
        Bl_cor                          matlab.ui.control.DropDown
        BaselinesubtractionLabel        matlab.ui.control.Label
        CP_det                          matlab.ui.control.DropDown
        ContactpointdeterminationLabel  matlab.ui.control.Label
        CancelButton                    matlab.ui.control.Button
        OKButton                        matlab.ui.control.Button
    end

    
    properties (Access = public)
        MainApp
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, MainApp)
            %input data. Expects: struct with fields: CP_det, Bl_cor, Bl_osc
            inpt = MainApp.autoCorrectOptions;
            app.MainApp = MainApp;
            MainApp.subapp.AutoCorrectOptions = app.DatacorrectionoptionsUIFigure;

            app.DatacorrectionoptionsUIFigure.Position(1:2) = ...
                MainApp.FDUIFigure.Position(1:2) + MainApp.FDUIFigure.Position(3:4)/2 ...
                - app.DatacorrectionoptionsUIFigure.Position(3:4)/2;
            
            if isstruct(inpt)
                if isfield(inpt, 'BaselinePrio')
                    app.Bl_cor.Value = inpt.BaselinePrio;
                else
                    app.Bl_cor.Value = '0';
                end
                
                if isfield(inpt, 'ContactPointPrio')
                    app.CP_det.Value = inpt.ContactPointPrio;
                else
                    app.CP_det.Value = '0';
                end
                
                app.Bl_osc.Value = num2str(inpt.CorrectOsc);

                if isfield(inpt, 'BaselineThres')
                    app.BaselinenoisethresholdEditField.Value = inpt.BaselineThres;
                else
                    app.BaselinenoisethresholdEditField.Value = 3;
                end
            else
                app.Bl_cor.Value = '0';
                app.CP_det.Value = '0';
                app.Bl_osc.Value = '0';
                app.BaselinenoisethresholdEditField.Value = 3;
            end
            
            
        end

        % Close request function: DatacorrectionoptionsUIFigure
        function DatacorrectionoptionsUIFigureCloseRequest(app, event)
            if isvalid(app.MainApp)
                app.MainApp.subapp.AutoCorrectOptions = [];
            end
            delete(app)
        end

        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            output = struct('CorrectOsc', logical(str2double(app.Bl_osc.Value)));
            output.OscLambda = app.oscillationwavelengthEditField.Value * 1e-9;
            if app.Bl_cor.Value ~= '0'
                output.BaselinePrio = app.Bl_cor.Value;
            end
            if app.CP_det.Value ~= '0' 
                output.ContactPointPrio = app.CP_det.Value;
            end
            output.BaselineThres = app.BaselinenoisethresholdEditField.Value;

            app.MainApp.autoCorrectOptions = output;
        
            %close app
            app.DatacorrectionoptionsUIFigureCloseRequest();
        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, event)
            app.DatacorrectionoptionsUIFigureCloseRequest();
        end

        % Value changed function: Bl_osc
        function Bl_oscValueChanged(app, event)
            value = app.Bl_osc.Value;
            if logical(str2double(value))
                app.nmLabel.Enable = "on";
                app.oscillationwavelengthEditField.Enable = "on";
                app.oscillationwavelengthEditFieldLabel.Enable = "on";
            else
                app.nmLabel.Enable = "off";
                app.oscillationwavelengthEditField.Enable = "off";
                app.oscillationwavelengthEditFieldLabel.Enable = "off";
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create DatacorrectionoptionsUIFigure and hide until all components are created
            app.DatacorrectionoptionsUIFigure = uifigure('Visible', 'off');
            app.DatacorrectionoptionsUIFigure.Position = [100 100 320 239];
            app.DatacorrectionoptionsUIFigure.Name = 'Data correction options';
            app.DatacorrectionoptionsUIFigure.Resize = 'off';
            app.DatacorrectionoptionsUIFigure.CloseRequestFcn = createCallbackFcn(app, @DatacorrectionoptionsUIFigureCloseRequest, true);

            % Create OKButton
            app.OKButton = uibutton(app.DatacorrectionoptionsUIFigure, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            app.OKButton.Position = [47 12 100 22];
            app.OKButton.Text = 'OK';

            % Create CancelButton
            app.CancelButton = uibutton(app.DatacorrectionoptionsUIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [187 12 100 22];
            app.CancelButton.Text = 'Cancel';

            % Create ContactpointdeterminationLabel
            app.ContactpointdeterminationLabel = uilabel(app.DatacorrectionoptionsUIFigure);
            app.ContactpointdeterminationLabel.HorizontalAlignment = 'right';
            app.ContactpointdeterminationLabel.Position = [18 188 156 22];
            app.ContactpointdeterminationLabel.Text = 'Contact point determination';

            % Create CP_det
            app.CP_det = uidropdown(app.DatacorrectionoptionsUIFigure);
            app.CP_det.Items = {'Individually for approach and retract', 'Use approach CP for both', 'Use retract CP for both', 'Use lowest point as CP'};
            app.CP_det.ItemsData = {'0', 'ap', 'rt', 'lowest'};
            app.CP_det.Position = [85 167 219 22];
            app.CP_det.Value = '0';

            % Create BaselinesubtractionLabel
            app.BaselinesubtractionLabel = uilabel(app.DatacorrectionoptionsUIFigure);
            app.BaselinesubtractionLabel.HorizontalAlignment = 'right';
            app.BaselinesubtractionLabel.Position = [18 137 115 22];
            app.BaselinesubtractionLabel.Text = 'Baseline subtraction';

            % Create Bl_cor
            app.Bl_cor = uidropdown(app.DatacorrectionoptionsUIFigure);
            app.Bl_cor.Items = {'Individually', 'Use approach baseline for both', 'Use retract baseline for both'};
            app.Bl_cor.ItemsData = {'0', 'ap', 'rt'};
            app.Bl_cor.Position = [85 116 219 22];
            app.Bl_cor.Value = '0';

            % Create SubtractbaselineoscillationDropDownLabel
            app.SubtractbaselineoscillationDropDownLabel = uilabel(app.DatacorrectionoptionsUIFigure);
            app.SubtractbaselineoscillationDropDownLabel.HorizontalAlignment = 'right';
            app.SubtractbaselineoscillationDropDownLabel.Position = [19 47 156 22];
            app.SubtractbaselineoscillationDropDownLabel.Text = 'Subtract baseline oscillation';

            % Create Bl_osc
            app.Bl_osc = uidropdown(app.DatacorrectionoptionsUIFigure);
            app.Bl_osc.Items = {'Yes', 'No'};
            app.Bl_osc.ItemsData = {'1', '0'};
            app.Bl_osc.ValueChangedFcn = createCallbackFcn(app, @Bl_oscValueChanged, true);
            app.Bl_osc.Position = [212 47 93 22];
            app.Bl_osc.Value = '0';

            % Create BaselinenoisethresholdEditFieldLabel
            app.BaselinenoisethresholdEditFieldLabel = uilabel(app.DatacorrectionoptionsUIFigure);
            app.BaselinenoisethresholdEditFieldLabel.HorizontalAlignment = 'right';
            app.BaselinenoisethresholdEditFieldLabel.Position = [20 79 136 22];
            app.BaselinenoisethresholdEditFieldLabel.Text = 'Baseline noise threshold';

            % Create BaselinenoisethresholdEditField
            app.BaselinenoisethresholdEditField = uieditfield(app.DatacorrectionoptionsUIFigure, 'numeric');
            app.BaselinenoisethresholdEditField.Tooltip = {'Threshold (in multiples of baseline nosise) for determining end of baseline (default: 3).'};
            app.BaselinenoisethresholdEditField.Position = [264 79 40 22];
            app.BaselinenoisethresholdEditField.Value = 3;

            % Show the figure after all components are created
            app.DatacorrectionoptionsUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = autocorrect_options_m(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.DatacorrectionoptionsUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.DatacorrectionoptionsUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.DatacorrectionoptionsUIFigure)
        end
    end
end