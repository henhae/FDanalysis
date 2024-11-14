classdef ShowFitStats_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        FitStatisticsUIFigure       matlab.ui.Figure
        ExitmessageTextArea         matlab.ui.control.TextArea
        ExitmessageLabel            matlab.ui.control.Label
        CloseButton                 matlab.ui.control.Button
        TabGroup                    matlab.ui.container.TabGroup
        GoodnessoffitstatisticsTab  matlab.ui.container.Tab
        UITableGoF                  matlab.ui.control.Table
        FitinformationTab           matlab.ui.container.Tab
        UITableOutp                 matlab.ui.control.Table
        ResidualsTab                matlab.ui.container.Tab
        UIAxes                      matlab.ui.control.UIAxes
        JacobianTab                 matlab.ui.container.Tab
        UITableJac                  matlab.ui.control.Table
        FitresultsTab               matlab.ui.container.Tab
        TextAreaFormula             matlab.ui.control.TextArea
        FormularoffitfunctionTextAreaLabel  matlab.ui.control.Label
        UITablePars                 matlab.ui.control.Table
        FitplotTab                  matlab.ui.container.Tab
        UIAxes_2                    matlab.ui.control.UIAxes
    end

    
    properties (Access = public)
        FitStats %Fit output with fields: 
                    %GoF: Goodness of fit statistics
                    %out: fit information output
        thisFigIdx
        MainApp
    end
    
    methods (Access = public)
        
        function actualize_display(app)
            if isempty(app.FitStats) && ~isempty(app.MainApp)
                FitStats_l = app.MainApp.LastFitStats;
            else
                FitStats_l = app.FitStats;
            end
            app.UITableGoF.Data = cell(5,2);
            app.UITableGoF.Data(:,2) = struct2cell(FitStats_l.GoF);
            app.UITableGoF.Data(:,1) = {'Sum of squares due to error';...
                'R-squared (coefficient of determination)';...
                'Degrees of freedom in the error';...
                'Degree-of-freedom adjusted coefficient of determination';...
                'Root mean squared error (standard error)'};
            app.UITableGoF.RowName = [];
            app.UITableGoF.ColumnName = {'Stats', 'Values'};
            
            
            app.UITableOutp.Data = cell(9,2);
            app.UITableOutp.Data(1:5,:) = {...
                'Number of observations (response values)', FitStats_l.out.numobs ; ...
                'Number of unknown parameters (coefficients) to fit', FitStats_l.out.numparam ; ...
                'Exitflag', FitStats_l.out.exitflag ; ...
                'Fitting algorithm', FitStats_l.out.algorithm ;...
                'Number of iterations', FitStats_l.out.iterations};
            
            additFields = {'firstorderopt', 'Measure of first-order optimality (absolute maximum of gradient components)' ;...
                'funcCount', 'Number of function evaluations' ;...
                'pcgterations' , 'PCG Iterations' ; ...    
                'cgiterations' , 'CGI Iterations' ;
                'stepsize', 'Stepsize'};
            
            for ii = 1:size(additFields,1)
                if isfield(FitStats_l.out, additFields{ii,1})
                    app.UITableOutp.Data(end+1,:) = {additFields{ii,2}, FitStats_l.out.(additFields{ii,1})};
                end
            end
                

            outpdata = struct2cell(FitStats_l.out);
            vecs = outpdata(3:4);
            if isfield(FitStats_l.out, 'message')
                app.ExitmessageTextArea.Value = FitStats_l.out.message;
            else
                app.ExitmessageTextArea.Value = '';
            end
            
            plot(app.UIAxes, vecs{1});
            
            app.UITableJac.Data = num2cell(vecs{2});
            app.UITableJac.RowName = arrayfun(@(x) num2str(x), (1:size(vecs{2},1)).', 'UniformOutput',false);
            app.UITableJac.ColumnName = arrayfun(@(x) ['Par ' num2str(x)], (1:size(vecs{2},2)).', 'UniformOutput',false);
            
            exitflaginfo = {...
                1, 'Function converged to a solution x.' ;
                2, 'Change in x was less than the specified tolerance.';
                3, 'Change in the residual was less than the specified tolerance.';
                4, 'Relative magnitude of search direction was smaller than the step tolerance.';
                0, 'Number of iterations exceeded options.MaxIterations or number of function evaluations exceeded options.MaxFunctionEvaluations.';
                -1, 'A plot function or output function stopped the solver.';
                -2, 'Problem is infeasible: the bounds lb and ub are inconsistent.'};
            app.UITableOutp.Tooltip = exitflaginfo{cell2mat(exitflaginfo(:,1)) == FitStats_l.out.exitflag,2};
            
            if isfield(FitStats_l, 'Fit')
                if numel(app.TabGroup.Children) == 4
                    
                    if isfield(FitStats_l, 'Data')    
                        % Create FitplotTab
                        app.FitplotTab = uitab(app.TabGroup);
                        app.FitplotTab.Title = 'Fit plot';
                        
                        % Create UIAxes_2
                        app.UIAxes_2 = uiaxes(app.FitplotTab);
                        title(app.UIAxes_2, '')
                        app.UIAxes_2.PlotBoxAspectRatio = [2.74719101123596 1 1];
                        app.UIAxes_2.Box = 'on';
                        app.UIAxes_2.Position = [12 12 538 222];
                    end
                    
                    % Create FitresultsTab
                    app.FitresultsTab = uitab(app.TabGroup);
                    app.FitresultsTab.Title = 'Fit results';
                    
                    % Create UITablePars
                    app.UITablePars = uitable(app.FitresultsTab, 'Visible', "off");
                    app.UITablePars.Position = [248 12 302 216];
                    
                    % Create FormularoffitfunctionTextAreaLabel
                    app.FormularoffitfunctionTextAreaLabel = uilabel(app.FitresultsTab);
                    app.FormularoffitfunctionTextAreaLabel.Position = [12 196 130 22];
                    app.FormularoffitfunctionTextAreaLabel.Text = 'Formular of fit function:';
        
                    % Create TextAreaFormular
                    app.TextAreaFormula = uitextarea(app.FitresultsTab);
                    app.TextAreaFormula.Position = [12 122 221 75];                    
                end
                %plot fit
                if isfield(FitStats_l, 'Data')
                    if  istable(FitStats_l.Data)
                        plotdata = table2array(FitStats_l.Data);
                        datadescr = FitStats_l.Data.Properties.Description;
                        xname = FitStats_l.Data.Properties.VariableNames{1};
                        yname = FitStats_l.Data.Properties.VariableNames{2};
                    elseif isnumeric(FitStats_l.Data)
                        datadescr = 'exp_data';
                        xname = 'X';
                        yname = 'Y';
                    end
                    xdata = linspace(min(plotdata(:,1)), max(plotdata(:,1)), 1000);
                    plot(app.UIAxes_2, plotdata(:,1), plotdata(:,2), '.b', ...
                        xdata, FitStats_l.Fit(xdata), '-r');
                    legend(app.UIAxes_2, {datadescr, 'Fit'});
                    xlabel(app.UIAxes_2, xname);
                    ylabel(app.UIAxes_2, yname);
                end
                
                
                %show parameters and fit type
                errors = abs(confint(FitStats_l.Fit) - ones(2,1)*coeffvalues(FitStats_l.Fit));
                vals = [coeffvalues(FitStats_l.Fit); errors]';
                app.UITablePars.Data = arrayfun(@(x) sprintf('%e',x), vals, 'UniformOutput',false);
                app.UITablePars.RowName = coeffnames(FitStats_l.Fit);
                app.UITablePars.ColumnName = {'Value', 'Error+', 'Error-'};
                app.UITablePars.Visible = 'on';
                
                app.TextAreaFormula.Value = formula(FitStats_l.Fit);
                
            else 
                if numel(app.TabGroup.Children) > 4
                    delete(app.FitresultsTab);
                    delete(app.FitplotTab);                    
                end                
            end
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, varargin)
            if nargin > 1            
                if ishandle(varargin{1})
                    MainApp_l = varargin{1};
                    
                    app.MainApp = MainApp_l;
                    
                    if isempty(app.MainApp.fhs)
                        app.MainApp.fhs = app.FitStatisticsUIFigure;
                        app.thisFigIdx = 1;
                    else
                        app.MainApp.fhs(end+1) = app.FitStatisticsUIFigure;
                        app.thisFigIdx = length(app.MainApp.fhs);
                    end
                    
                    app.FitStatisticsUIFigure.Position(1:2) = ...
                        MainApp_l.ReflFitUIFigure.Position(1:2) + MainApp_l.ReflFitUIFigure.Position(3:4)/2 ...
                        - app.FitStatisticsUIFigure.Position(3:4) / 2;                    
                elseif isstruct(varargin{1})
                    app.FitStats = varargin{1};
                end
            end
            
            app.actualize_display;
            
        end

        % Callback function: CloseButton, FitStatisticsUIFigure
        function UIFigureCloseRequest(app, event)
            if ~isempty(app.MainApp)
                app.MainApp.fhs(app.thisFigIdx) = [];   
            end
            delete(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create FitStatisticsUIFigure and hide until all components are created
            app.FitStatisticsUIFigure = uifigure('Visible', 'off');
            app.FitStatisticsUIFigure.Position = [100 100 582 367];
            app.FitStatisticsUIFigure.Name = 'Fit Statistics';
            app.FitStatisticsUIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.FitStatisticsUIFigure.Tag = 'FitStats';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.FitStatisticsUIFigure);
            app.TabGroup.Position = [13 80 561 271];

            % Create GoodnessoffitstatisticsTab
            app.GoodnessoffitstatisticsTab = uitab(app.TabGroup);
            app.GoodnessoffitstatisticsTab.Title = 'Goodness of fit statistics';

            % Create UITableGoF
            app.UITableGoF = uitable(app.GoodnessoffitstatisticsTab);
            app.UITableGoF.ColumnName = {'Stats'; 'Value'};
            app.UITableGoF.ColumnWidth = {417, 120};
            app.UITableGoF.RowName = {};
            app.UITableGoF.Tag = 'GoFTable';
            app.UITableGoF.Position = [12 12 538 222];

            % Create FitinformationTab
            app.FitinformationTab = uitab(app.TabGroup);
            app.FitinformationTab.Title = 'Fit information';

            % Create UITableOutp
            app.UITableOutp = uitable(app.FitinformationTab);
            app.UITableOutp.ColumnName = {'Stats'; 'Value'};
            app.UITableOutp.ColumnWidth = {417, 120};
            app.UITableOutp.RowName = {};
            app.UITableOutp.Tag = 'GoFTable';
            app.UITableOutp.Position = [12 12 538 222];

            % Create ResidualsTab
            app.ResidualsTab = uitab(app.TabGroup);
            app.ResidualsTab.Title = 'Residuals';

            % Create UIAxes
            app.UIAxes = uiaxes(app.ResidualsTab);
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            app.UIAxes.PlotBoxAspectRatio = [2.74719101123596 1 1];
            app.UIAxes.XTickLabelRotation = 0;
            app.UIAxes.YTickLabelRotation = 0;
            app.UIAxes.ZTickLabelRotation = 0;
            app.UIAxes.Box = 'on';
            app.UIAxes.Position = [12 12 538 222];

            % Create JacobianTab
            app.JacobianTab = uitab(app.TabGroup);
            app.JacobianTab.Title = 'Jacobian';

            % Create UITableJac
            app.UITableJac = uitable(app.JacobianTab);
            app.UITableJac.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITableJac.RowName = {};
            app.UITableJac.Position = [12 12 383 222];

            % Create FitresultsTab
            app.FitresultsTab = uitab(app.TabGroup);
            app.FitresultsTab.Title = 'Fit results';

            % Create UITablePars
            app.UITablePars = uitable(app.FitresultsTab);
            app.UITablePars.ColumnName = {'Name'; 'Value'; 'Error'};
            app.UITablePars.RowName = {};
            app.UITablePars.Position = [248 12 302 216];

            % Create FormularoffitfunctionTextAreaLabel
            app.FormularoffitfunctionTextAreaLabel = uilabel(app.FitresultsTab);
            app.FormularoffitfunctionTextAreaLabel.Position = [12 196 130 22];
            app.FormularoffitfunctionTextAreaLabel.Text = 'Formular of fit function:';

            % Create TextAreaFormula
            app.TextAreaFormula = uitextarea(app.FitresultsTab);
            app.TextAreaFormula.Position = [12 122 221 75];

            % Create FitplotTab
            app.FitplotTab = uitab(app.TabGroup);
            app.FitplotTab.Title = 'Fit plot';

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.FitplotTab);
            xlabel(app.UIAxes_2, 'X')
            ylabel(app.UIAxes_2, 'Y')
            app.UIAxes_2.PlotBoxAspectRatio = [2.74719101123596 1 1];
            app.UIAxes_2.XTickLabelRotation = 0;
            app.UIAxes_2.YTickLabelRotation = 0;
            app.UIAxes_2.ZTickLabelRotation = 0;
            app.UIAxes_2.Box = 'on';
            app.UIAxes_2.Position = [12 12 538 222];

            % Create CloseButton
            app.CloseButton = uibutton(app.FitStatisticsUIFigure, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.CloseButton.Position = [14 9 100 22];
            app.CloseButton.Text = 'Close';

            % Create ExitmessageLabel
            app.ExitmessageLabel = uilabel(app.FitStatisticsUIFigure);
            app.ExitmessageLabel.BackgroundColor = [0.9412 0.9412 0.9412];
            app.ExitmessageLabel.HorizontalAlignment = 'right';
            app.ExitmessageLabel.Position = [42 47 84 22];
            app.ExitmessageLabel.Text = 'Exit message: ';

            % Create ExitmessageTextArea
            app.ExitmessageTextArea = uitextarea(app.FitStatisticsUIFigure);
            app.ExitmessageTextArea.Editable = 'off';
            app.ExitmessageTextArea.BackgroundColor = [0.9412 0.9412 0.9412];
            app.ExitmessageTextArea.Position = [136 30 437 39];

            % Show the figure after all components are created
            app.FitStatisticsUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ShowFitStats_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.FitStatisticsUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.FitStatisticsUIFigure)
        end
    end
end