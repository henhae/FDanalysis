classdef ExportPropsSelection_m < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        Tree                       matlab.ui.container.CheckBoxTree
        allNode                    matlab.ui.container.TreeNode
        SelectvaluestoexportLabel  matlab.ui.control.Label
        CancelButton               matlab.ui.control.Button
        OKButton                   matlab.ui.control.Button
    end

    
    properties (Access = private)
        CallingApp      %handle to calling app
        outpVarName     %Name of variable in calling app where to fill in output
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, callingApp, optionList, outpVarName)
            app.CallingApp = callingApp;
            app.outpVarName = outpVarName;
            
            %determin main figure from calling app object
            propsOfCallingApp = properties(callingApp);
            propIsFigure = cellfun(@(y) (numel(y) == 1 && y == 1), ... %set all empty and array entries to false
                cellfun(@(x) isgraphics(callingApp.(x), 'figure'), propsOfCallingApp, 'UniformOutput', false));
            callingFigName = propsOfCallingApp(propIsFigure);
            callingFigure = callingApp.(callingFigName{1});
            app.UIFigure.Position(1:2) = callingFigure.Position(1:2) + ...
                floor(0.5*(callingFigure.Position(3:4) - app.UIFigure.Position(3:4)));


            for ii=1:length(optionList)
                if isstruct(optionList) && optionList(ii).optionIsValid
                    newNode = uitreenode(app.allNode, "Text", optionList(ii).optionLongName, "NodeData", optionList(ii).option);
                elseif iscell(optionList)
                    uitreenode(app.allNode, "Text", optionList{ii}, "NodeData", optionList{ii});
                end
            end
            app.Tree.CheckedNodes = app.allNode;
            app.allNode.expand();
        end

        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            checkedNodesVar = app.Tree.CheckedNodes;
            hasKids = arrayfun(@(x) ~isempty(x.Children), checkedNodesVar);
            checkedNodesVar(hasKids) = [];
            optionsListOutp = arrayfun(@(x) x.NodeData, checkedNodesVar, "UniformOutput",false);

            callingApp = app.CallingApp;
            expVar = app.outpVarName;

            app.UIFigureCloseRequest();
            callingApp.(expVar) = optionsListOutp;            
        end

        % Callback function: CancelButton, UIFigure
        function UIFigureCloseRequest(app, event)
            app.CallingApp.(app.outpVarName) = [];
            delete(app)            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 224 285];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create OKButton
            app.OKButton = uibutton(app.UIFigure, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            app.OKButton.Position = [22 16 85 22];
            app.OKButton.Text = 'OK';

            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.CancelButton.Position = [119 16 85 22];
            app.CancelButton.Text = 'Cancel';

            % Create SelectvaluestoexportLabel
            app.SelectvaluestoexportLabel = uilabel(app.UIFigure);
            app.SelectvaluestoexportLabel.Position = [21 254 128 22];
            app.SelectvaluestoexportLabel.Text = 'Select values to export';

            % Create Tree
            app.Tree = uitree(app.UIFigure, 'checkbox');
            app.Tree.Position = [22 55 182 192];

            % Create allNode
            app.allNode = uitreenode(app.Tree);
            app.allNode.Text = 'all';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ExportPropsSelection_m(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end