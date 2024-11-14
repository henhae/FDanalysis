classdef FD_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        FDUIFigure                      matlab.ui.Figure
        MenuFile                        matlab.ui.container.Menu
        AddDataMenu                     matlab.ui.container.Menu
        AddfolderMenu                   matlab.ui.container.Menu
        ExportDataMenu                  matlab.ui.container.Menu
        ClosedataMenu                   matlab.ui.container.Menu
        OpenMenu                        matlab.ui.container.Menu
        SaveMenu                        matlab.ui.container.Menu
        SaveasMenu                      matlab.ui.container.Menu
        ClosesessionMenu                matlab.ui.container.Menu
        ExitMenu                        matlab.ui.container.Menu
        OptionsMenu                     matlab.ui.container.Menu
        AutocorrectoptionsMenu          matlab.ui.container.Menu
        AutocorrectondataimportMenu     matlab.ui.container.Menu
        StartautocorrectalldataMenu     matlab.ui.container.Menu
        StartautocorrectselecteddataMenu  matlab.ui.container.Menu
        StartautoreviewMenu             matlab.ui.container.Menu
        AutoreviewoptionsMenu           matlab.ui.container.Menu
        AutoevaluateMenu                matlab.ui.container.Menu
        EvaluateselectedcurvesMenu      matlab.ui.container.Menu
        SelectevaluationpropertiesMenu  matlab.ui.container.Menu
        InspectevaluatedvaluesMenu      matlab.ui.container.Menu
        ExportevaluatedvaluesMenu       matlab.ui.container.Menu
        ToolsMenu                       matlab.ui.container.Menu
        FilmIndentationMenu             matlab.ui.container.Menu
        PeakFinderMenu                  matlab.ui.container.Menu
        DatafittingMenu                 matlab.ui.container.Menu
        ExportfitsMenu                  matlab.ui.container.Menu
        MakeSepPlotWindowButton         matlab.ui.control.Button
        SelDataOKButton                 matlab.ui.control.Button
        PlotcontrolPanel                matlab.ui.container.Panel
        coloringButtonGroup             matlab.ui.container.ButtonGroup
        DropDown_colormap               matlab.ui.control.DropDown
        seriescolormapButton            matlab.ui.control.RadioButton
        normalblueredButton             matlab.ui.control.RadioButton
        LegendCheckBox                  matlab.ui.control.CheckBox
        AdditionalmarkingsLabel         matlab.ui.control.Label
        retractCheckBox                 matlab.ui.control.CheckBox
        approachCheckBox                matlab.ui.control.CheckBox
        correctedLabel                  matlab.ui.control.Label
        uncorrectedLabel                matlab.ui.control.Label
        FvsSepButton                    matlab.ui.control.Button
        DeflvsHeightButton              matlab.ui.control.Button
        AxesquickselectLabel            matlab.ui.control.Label
        BaselineCheckBox                matlab.ui.control.CheckBox
        EvaluatedpropsCheckBox          matlab.ui.control.CheckBox
        CB_showCP                       matlab.ui.control.CheckBox
        CB_showBaseline                 matlab.ui.control.CheckBox
        cb_autoplotsel                  matlab.ui.control.CheckBox
        DropDown_yAxisData              matlab.ui.control.DropDown
        YaxisLabel                      matlab.ui.control.Label
        DropDown_xAxisData              matlab.ui.control.DropDown
        XaxisLabel                      matlab.ui.control.Label
        CalibrationcorrectionPanel      matlab.ui.container.Panel
        SpringConstNmEditField          matlab.ui.control.NumericEditField
        SpringConstNmEditFieldLabel     matlab.ui.control.Label
        DeflSensnmVEditField            matlab.ui.control.NumericEditField
        DeflSensnmVEditFieldLabel       matlab.ui.control.Label
        ManualCorrPanel                 matlab.ui.container.Panel
        BaselineLabel                   matlab.ui.control.Label
        ContactpointLabel               matlab.ui.control.Label
        fixCPCheckBox                   matlab.ui.control.CheckBox
        fixendpointsCheckBox            matlab.ui.control.CheckBox
        foundwavelengthnmEditField      matlab.ui.control.NumericEditField
        foundwavelengthnmEditFieldLabel  matlab.ui.control.Label
        oscillationcorrectionSwitch     matlab.ui.control.Switch
        oscillationcorrectionSwitchLabel  matlab.ui.control.Label
        ChoosedirectionLabel            matlab.ui.control.Label
        CB_ManCorChan                   matlab.ui.control.CheckBox
        BG_corrChannel                  matlab.ui.container.ButtonGroup
        TB_corrRet                      matlab.ui.control.ToggleButton
        TB_corrApp                      matlab.ui.control.ToggleButton
        PB_setBaseline                  matlab.ui.control.Button
        PB_setCP                        matlab.ui.control.Button
        pb_rmSeries                     matlab.ui.control.Button
        pb_addSeries                    matlab.ui.control.Button
        pb_remData                      matlab.ui.control.Button
        pb_addData                      matlab.ui.control.Button
        lb_allData                      matlab.ui.control.ListBox
        LoadeddataLabel                 matlab.ui.control.Label
        tree_dataSorted                 matlab.ui.container.Tree
        Series1                         matlab.ui.container.TreeNode
        axes1                           matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        propsToEval = 'all';    %curve properties to determine
        thisFileName            char
        thisFilePath            char
        %autoCorrectPopupValues
    end
    
    properties (Access = public)
        Data                    (:,1) FDdata_ar % Vector of FDdata
        DataNames               (:,1) cell
        DataSorting             (:,1) {mustBeInteger}
        %Images                  (:,1) AFMImage
        %ImagesLinks
        iSelectedData           %indices of currently selected data
        autoCorrectOptions
        subapp
        LastFolder = pwd;
        exportProperties
    end

    methods

        function set.Data(app, inpt)
            app.Data = inpt;
            if ~isempty(app.thisFileName)
                app.FDUIFigure.Name = ['FD - ' app.thisFileName '*'];
            end
        end

    end
    
    methods (Access = private)

        
        function app = actualize_plot(app)
            
            if isempty(app.iSelectedData), return; end
            which_series = app.DataSorting(app.iSelectedData);



            %actualize drop downlists with available channels
            oldXch = app.DropDown_xAxisData.Value;
            oldYch = app.DropDown_yAxisData.Value;
            
            X_chs = {'Time', 'Extension', 'mExtension', 'Height', 'Sep', 'Ind'};
            X_desc = {'Time', 'Piezo extension', 'mod. Extension', 'Height', 'Separation', 'Indentation'};
            X_units = {'s', 'm', 'm', 'm', 'm', 'm'};
            iX_chs = ones(size(X_chs));
            Y_chs = {'DeflV', 'Defl', 'F','DeflVc', 'Deflc', 'Fc'};
            Y_units = {'V', 'm', 'N', 'V', 'm', 'N'};
            Y_desc = {'Deflection (V)', 'Deflection (nm)', 'Force', 'corr. Deflection (V)', 'corr. Deflection (nm)', 'corr. Force'};
            iY_chs = ones(size(Y_chs));
            for iD = app.iSelectedData
                iX_chs = iX_chs & ...
                    cellfun(@(x) any(strcmp(x, app.Data(iD).ap.AvChannels)), X_chs) & ...
                    cellfun(@(x) any(strcmp(x, app.Data(iD).rt.AvChannels)), X_chs);
                iY_chs = iY_chs & ...
                    cellfun(@(x) any(strcmp(x, app.Data(iD).ap.AvChannels)), Y_chs) & ...
                    cellfun(@(x) any(strcmp(x, app.Data(iD).rt.AvChannels)), Y_chs);
            end
            

            X_chs(~iX_chs) = [];
            X_desc(~iX_chs) = [];
            X_units(~iX_chs) = [];
            Y_chs(~iY_chs) = [];
            Y_desc(~iY_chs) = [];
            Y_units(~iY_chs) = [];
            
            app.DropDown_xAxisData.ItemsData = X_chs;
            app.DropDown_xAxisData.Items = X_desc;
            app.DropDown_yAxisData.ItemsData = Y_chs;
            app.DropDown_yAxisData.Items = Y_desc;
            if any(strcmp(oldXch, X_chs))
                app.DropDown_xAxisData.Value = oldXch;
            else
                app.DropDown_xAxisData.Value = X_chs{end-1};
            end
            
            if any(strcmp(oldYch, Y_chs))
                app.DropDown_yAxisData.Value = oldYch;
            else
                app.DropDown_yAxisData.Value = Y_chs{end};
            end
            
            %enable/disable quick channel selection buttons
            if any(strcmp(X_chs, 'Height'))
                app.DeflvsHeightButton.Enable = 'on';
            else
                app.DeflvsHeightButton.Enable = 'off';
            end
            
            if any(contains(Y_desc, 'corr')) && any(strcmp(X_chs, 'Sep'))
                app.FvsSepButton.Enable = 'on';
            else
                app.FvsSepButton.Enable = 'off';
            end
            %enable/disable baseline plot checkbox
            if any(contains(app.DropDown_yAxisData.Value, 'c')) || strcmp(app.DropDown_xAxisData.Value, 'Sep')
                app.BaselineCheckBox.Enable = 'off';
            else
                app.BaselineCheckBox.Enable = 'on';
            end

            %enable/disable evaluated properties plot checkbox
            if strcmp(app.DropDown_yAxisData.Value, 'Fc') && strcmp(app.DropDown_xAxisData.Value, 'Sep')
                app.EvaluatedpropsCheckBox.Enable = 'on';
            else
                app.EvaluatedpropsCheckBox.Enable = 'off';
            end

            
            %individual or series coloring
            if app.seriescolormapButton.Value == 1
                %create a separate colormap array for every Series
                colormaps = cell(numel(app.tree_dataSorted.Children),1);
                cmapName = app.DropDown_colormap.Value;
                for iS = 1:numel(app.tree_dataSorted.Children)
                    colormaps{iS} = app.getColormapArray(cmapName, numel(app.tree_dataSorted.Children(iS).Children));
                end
            end
            
            %get channels from dropdownlists;
            
            X_ch = app.DropDown_xAxisData.Value;
            Y_ch = app.DropDown_yAxisData.Value;
            iX_ch = find(strcmp(X_ch,app.DropDown_xAxisData.ItemsData));
            iY_ch = find(strcmp(Y_ch,app.DropDown_yAxisData.ItemsData));
            
            prefixes = {'G', 'M', 'k', '', 'm', '\mu', 'n', 'p', 'f', 'a'};
            xMax = 0;
            yMax = 0;
            for iD = app.iSelectedData
                xMax = max(abs( [app.Data(iD).ap.(X_ch); app.Data(iD).rt.(X_ch); xMax] ));
                yMax = max(abs( [app.Data(iD).ap.(Y_ch); app.Data(iD).rt.(Y_ch); yMax] ));
            end
            X_exp = max( ceil(-log10(xMax)/3));
            Y_exp = max( ceil(-log10(yMax)/3));
            if X_exp > -4 && X_exp < 7
                X_unit = [prefixes{X_exp+4} X_units{iX_ch}];
            else
                X_unit = X_units{iX_ch};
                X_exp = 0;
            end
            if Y_exp > -4 && Y_exp < 7
                Y_unit = [prefixes{Y_exp+4} Y_units{iY_ch}];
            else
                Y_unit = Y_units{iY_ch};
                Y_exp = 0;
            end

            cla(app.axes1, 'reset');
            app.axes1.NextPlot = 'add';
            xlimits = [NaN NaN];
            ylimits = [NaN NaN];


            for iD = app.iSelectedData
                %get Idx of this Data within its series
                this_seriesID = app.DataSorting(iD);
                iD_in_series = sum(app.DataSorting(1:iD) == this_seriesID);
                %Idx of all data from this series
                thisSeriesDataIDs = find(app.DataSorting == this_seriesID);
                iD_in_series2 = find(ismember(thisSeriesDataIDs,iD));
                %Idx of all selected data from this series
                thisSeriesSelDataIDs = intersect(thisSeriesDataIDs, app.iSelectedData );
                
                if app.seriescolormapButton.Value == 1
                    this_color = colormaps{this_seriesID}(iD_in_series,:);
                end


                %data
                if app.approachCheckBox.Value
                    lh_a = plot(app.axes1, app.Data(iD).ap.(X_ch)*10^(3*X_exp), app.Data(iD).ap.(Y_ch)*10^(3*Y_exp), '.b');
                    if strcmp(X_ch, 'Ind')
                        temp_Xmin = app.Data(iD).ap.(X_ch)(app.Data(iD).ap.iBl(2))*10^(3*X_exp);
                    else
                        temp_Xmin = lh_a.XData;
                    end
                    if app.seriescolormapButton.Value == 1
                        lh_a.Marker = 'o';
                        lh_a.MarkerSize = 3;
                        lh_a.Color = this_color;
                    end
                    xlimits = [min([xlimits(1) temp_Xmin])  max([xlimits(2) lh_a.XData])];
                    ylimits = [min([ylimits(1) lh_a.YData])  max([ylimits(2) lh_a.YData])];
                    lh_a.DisplayName = 'approach';
                end
                if app.retractCheckBox.Value
                    lh_r = plot(app.axes1, app.Data(iD).rt.(X_ch)*10^(3*X_exp), app.Data(iD).rt.(Y_ch)*10^(3*Y_exp), '.r');
                    if strcmp(X_ch, 'Ind')
                        temp_Xmin = app.Data(iD).rt.(X_ch)(app.Data(iD).rt.iBl(2))*10^(3*X_exp);
                    else
                        temp_Xmin = lh_r.XData;
                    end
                    if app.seriescolormapButton.Value == 1
                        lh_r.Marker = 'o';
                        lh_r.MarkerSize = 3;
                        lh_r.Color = this_color;
                        lh_r.MarkerFaceColor= this_color;
                    end
                    xlimits = [min([xlimits(1) temp_Xmin])  max([xlimits(2) lh_r.XData])];
                    ylimits = [min([ylimits(1) lh_r.YData])  max([ylimits(2) lh_r.YData])];
                    lh_r.DisplayName = 'retract';
                end

                %baseline boundaries
                if logical(app.CB_showBaseline.Value)
                    if app.approachCheckBox.Value
                        plot(app.axes1, app.Data(iD).ap.(X_ch)(app.Data(iD).ap.iBl)*10^(3*X_exp), ...
                            app.Data(iD).ap.(Y_ch)(app.Data(iD).ap.iBl)*10^(3*Y_exp), 'db',...
                            'MarkerSize', 8, 'MarkerFaceColor', 'k',...
                            'DisplayName', 'appr. baseline boundary');
                    end
                    if app.retractCheckBox.Value
                        plot(app.axes1, app.Data(iD).rt.(X_ch)(app.Data(iD).rt.iBl)*10^(3*X_exp), ...
                            app.Data(iD).rt.(Y_ch)(app.Data(iD).rt.iBl)*10^(3*Y_exp), 'dr',...
                            'MarkerSize', 8, 'MarkerFaceColor', 'k',...
                            'DisplayName', 'retr. baseline boundary');
                    end
                end

                %contact point
                if logical(app.CB_showCP.Value)
                    if app.approachCheckBox.Value
                        cph_a = plot(app.axes1, app.Data(iD).ap.(X_ch)(app.Data(iD).ap.iCP(1))*10^(3*X_exp), ...
                            app.Data(iD).ap.(Y_ch)(app.Data(iD).ap.iCP(1))*10^(3*Y_exp), 'db',...
                            'MarkerSize', 8, 'MarkerFaceColor', 'g' ,...
                            'DisplayName', 'appr. cont. point');
                        if app.seriescolormapButton.Value == 1
                            cph_a.Color = this_color;
                        end
                    end
                    if app.retractCheckBox.Value
                        cph_r = plot(app.axes1, app.Data(iD).rt.(X_ch)(app.Data(iD).rt.iCP(1))*10^(3*X_exp), ...
                            app.Data(iD).rt.(Y_ch)(app.Data(iD).rt.iCP(1))*10^(3*Y_exp), 'dr',...
                            'MarkerSize', 8, 'MarkerFaceColor', 'g',...
                            'DisplayName', 'retr. cont. point');
                        if app.seriescolormapButton.Value == 1
                            cph_r.Color = this_color;
                        end
                    end
                end
                
                %baseline
                if strcmp(app.BaselineCheckBox.Enable, 'on') && app.BaselineCheckBox.Value && ...
                        any(contains(app.DropDown_yAxisData.Items, 'corr'))
                        
                    if app.approachCheckBox.Value
                        plot(app.axes1, app.Data(iD).ap.(X_ch)*10^(3*X_exp), ...
                          (app.Data(iD).ap.(Y_ch)-app.Data(iD).ap.([Y_ch 'c']) )*10^(3*Y_exp), '-m',...
                            'DisplayName', 'appr. baseline');
                    end
                    if app.retractCheckBox.Value
                        plot(app.axes1, app.Data(iD).rt.(X_ch)*10^(3*X_exp),...
                        (app.Data(iD).rt.(Y_ch)-app.Data(iD).rt.([Y_ch 'c']) )*10^(3*Y_exp), '-g', ...
                            'DisplayName', 'retr. baseline');
                    end
                end

                %%%
                %evaluated properties
                if strcmp(app.EvaluatedpropsCheckBox.Enable, 'on') && app.EvaluatedpropsCheckBox.Value %,strcmp(X_ch, 'Sep') && strcmp(Y_ch, 'Fc')
                    if app.approachCheckBox.Value
                    end
                    
                    if app.retractCheckBox.Value
                        if ~isempty(app.Data(iD).AdhForce) && app.Data(iD).AdhForce > 0
                            iAh = find(abs(abs(app.Data(iD).rt.Fc) - app.Data(iD).AdhForce)<eps(app.Data(iD).AdhForce), 1,'last');
                            plot(app.axes1, app.Data(iD).rt.Sep(iAh)*10^(3*X_exp), app.Data(iD).rt.Fc(iAh)*10^(3*Y_exp),...
                                'p', 'MarkerFaceColor', [0 0.5 0.5], 'MarkerSize', 12, 'MarkerEdgeColor','none',...
                                'DisplayName', ['adhesion force: ' app.num2si_w_p(app.Data(iD).AdhForce, '%.3g') 'N']);
                        end
    
                        if ~isempty(app.Data(iD).AdhSep) && app.Data(iD).AdhSep > 0 && numel(iAh)==1
                            lh = plot(app.axes1, [0, app.Data(iD).rt.Sep(iAh)]*10^(3*X_exp), 1.1*[1 1]*app.Data(iD).rt.Fc(iAh)*10^(3*Y_exp),...
                                '-|', 'Color', [0 0.5 0.5],...
                                'DisplayName', ['adhesion separation: ' app.num2si_w_p(app.Data(iD).AdhSep, '%.3g') 'm']);
                            if app.seriescolormapButton.Value == 1
                                lh.Color = this_color;
                            end
                        end
    
                        if ~isempty(app.Data(iD).AdhEnergy) && app.Data(iD).AdhEnergy > 0
                            pah = area(app.axes1, app.Data(iD).rt.Sep(app.Data(iD).rt.iBl(2):app.Data(iD).rt.iCP(1))*10^(3*X_exp),...
                            app.Data(iD).rt.Fc(app.Data(iD).rt.iBl(2):app.Data(iD).rt.iCP(1))*10^(3*Y_exp), ...
                            'FaceColor', 'g', 'LineStyle', 'none',...
                            'DisplayName', ['adhesion energy: ' app.num2si_w_p(app.Data(iD).AdhEnergy,'%.3g') 'J']);
                            pah.FaceAlpha = 0.5;
                            pah.ShowBaseLine = 'off';
                            if app.seriescolormapButton.Value == 1
                                pah.FaceColor = this_color;
                                pah.FaceAlpha = 0.25;
                            end
                        end
    
                        if ~isempty(app.Data(iD).RuptLength) && app.Data(iD).RuptLength > 0
                            iRl = find(abs(app.Data(iD).RuptLength - app.Data(iD).rt.Sep) < eps(app.Data(iD).RuptLength),1);
                            minF = min(app.Data(iD).rt.Fc);
                            lh = plot(app.axes1, [0, app.Data(iD).rt.Sep(iRl)]*10^(3*X_exp), 1.15*[1 1]*minF*10^(3*Y_exp), '-|g',...
                            'DisplayName', ['rupture length:' app.num2si_w_p(app.Data(iD).RuptLength,'%.3g') 'm']);
                            if app.seriescolormapButton.Value == 1
                                lh.Color = this_color;
                            end
                        end
                    end
                end                    
                %%%
                
            end
            
            app.axes1.NextPlot = 'replace';
            
            xlabel(app.axes1,['\it ' X_desc{iX_ch} ' \rm / ' X_unit]);
            ylabel(app.axes1,['\it ' Y_desc{iY_ch} ' \rm / ' Y_unit]);    
            app.axes1.Box = 'on';
            app.axes1.Title.String = '';

            if strcmp(X_ch, 'Ind') && diff(xlimits) >0
                xlim(app.axes1, xlimits+diff(xlimits)*0.05*[-1 1]);
            end
            if app.LegendCheckBox.Value
                legend(app.axes1, "Location", "best")
            end


        end
        
        function app = actualize_lists(app)
            app.lb_allData.Items = app.DataNames(app.DataSorting == 0);
            app.lb_allData.ItemsData = find(app.DataSorting == 0);
            
            if numel(app.tree_dataSorted.Children) > 0
                SeriesNames = {app.tree_dataSorted.Children.Text};
                for iS = 1:numel(SeriesNames)
                    act_node = app.tree_dataSorted.Children(iS);
                    delete(act_node.Children);
                    iData_iS = find(app.DataSorting == iS);
                    for iN = 1:numel(iData_iS)
                        uitreenode(act_node,'Text', app.DataNames{iData_iS(iN)},'NodeData',iData_iS(iN));
                    end
                end
            end
        end
    
        function app = actualize_objects(app)
            %Enable manual correction only for single curves
            if numel(app.iSelectedData) == 1
                app.PB_setBaseline.Enable = 'on';
                app.PB_setCP.Enable = 'on';
                app.oscillationcorrectionSwitch.Enable = 'on';

                if logical(app.TB_corrApp.Value)
                    app.foundwavelengthnmEditField.Value = app.Data(app.iSelectedData).ap.OscLambda *1e9;
                    whichTrace = 'ap';
                else
                    app.foundwavelengthnmEditField.Value = app.Data(app.iSelectedData).rt.OscLambda *1e9;
                    whichTrace = 'rt';
                end

                if isempty(app.Data(app.iSelectedData).(whichTrace).OscCor)
                    app.oscillationcorrectionSwitch.Value = 'Off';
                    app.foundwavelengthnmEditField.Enable = "off";
                else
                    app.oscillationcorrectionSwitch.Value = 'On';
                    app.foundwavelengthnmEditField.Enable = "on";
                end

            else
                app.PB_setBaseline.Enable = 'off';
                app.PB_setCP.Enable = 'off';
                app.oscillationcorrectionSwitch.Enable = 'off';
            end
            
            %get DeflSens & SprConst for selected data
            DeflSens = [app.Data(app.iSelectedData).DeflSens];
            isSetDefl = true;
            isSameDefl = true;
            if isempty(DeflSens) || all(~logical(DeflSens))
                DeflSens = 0;
                isSetDefl = false;
            elseif all(abs(DeflSens-DeflSens(1))/DeflSens(1) < 0.000001)
                DeflSens = round(DeflSens(1),6,'significant');
            elseif all(abs(DeflSens-DeflSens(1))/DeflSens(1) < 0.01)
                DeflSens = round(mean(DeflSens),3,'significant');
                isSameDefl = false;
            else
                DeflSens = 0;
                isSameDefl = false;
            end
            
            SprConst = [app.Data(app.iSelectedData).SprConst];
            isSetSpr = true;
            isSameSpr = true;
            if isempty(SprConst) || all(isempty(SprConst))
                SprConst = 0;
                isSetSpr = false;
            elseif all(abs(SprConst-SprConst(1))/SprConst(1) < 0.000001)
                SprConst = round(SprConst(1),6,'significant');
            elseif all(abs(SprConst-SprConst(1))/SprConst(1) < 0.01)
                SprConst = round(mean(SprConst),3,'significant');
                isSameSpr = false;
            else
                SprConst = 0;
                isSameSpr = false;
            end
            
            %switch EditField for DeflSens off if not all selected data contain either DeflV or Defl channel
            if ~all(arrayfun(@(x) any(contains({'DeflV', 'Defl'}, [x.ap.AvChannels; x.rt.AvChannels])), app.Data(app.iSelectedData)) )
                app.DeflSensnmVEditField.Editable = 'off';
            else
                app.DeflSensnmVEditField.Editable = 'on';
            end  
            
            app.DeflSensnmVEditField.Value = DeflSens*1e9;
            if isSetDefl
                app.DeflSensnmVEditField.BackgroundColor = [1 1 1];
                app.DeflSensnmVEditField.Tooltip = {''};
            else
                app.DeflSensnmVEditField.BackgroundColor = [1 0.7 0.7];
                app.DeflSensnmVEditField.Tooltip = {'Defl. Sens. not set for selected curve(s).'};
            end
            
            if isSameDefl
                app.DeflSensnmVEditField.FontColor = [0 0 0];
            else
                app.DeflSensnmVEditField.FontColor = [1 0 0];
                app.DeflSensnmVEditField.Tooltip = {'Defl. sens. differs for selected curves.'; 'Mean value is displayed.'; 'Changing is not recommended!'};
            end
            
            %switch EditField for SprConst off if not all selected data contain either Defl or F channel
            if ~all(arrayfun(@(x) any(contains({'Defl', 'F'}, [x.ap.AvChannels; x.rt.AvChannels])), app.Data(app.iSelectedData)) )
                app.SpringConstNmEditField.Editable = 'off';
            else
                app.SpringConstNmEditField.Editable = 'on';
            end
            
            app.SpringConstNmEditField.Value = SprConst;
            if isSetSpr
                app.SpringConstNmEditField.BackgroundColor = [1 1 1];
                app.SpringConstNmEditField.Tooltip = {''};
            else
                app.SpringConstNmEditField.BackgroundColor = [1 0.2 0.2];
                app.SpringConstNmEditField.Tooltip = {'Spr. Const. not set for selected curve(s).'};
            end
            if isSameSpr
                app.SpringConstNmEditField.FontColor = [0 0 0];
            else
                app.SpringConstNmEditField.FontColor = [1 0 0];
                app.SpringConstNmEditField.Tooltip = {'Spring constant differs for selected curves.'; 'Mean value is displayed.';'Changing is not recommended!'};
            end
        end
        
        function setNewBaselineFromBrush(app)
            if logical(app.TB_corrApp.Value)
                selTr = 'ap';
                othTr = 'rt';
            else
                selTr = 'rt';
                othTr = 'ap';
            end

            data = app.Data(app.iSelectedData).(selTr);

            brushDataIdx = logical(app.axes1.Children.BrushData);
            lBIdx = find(brushDataIdx, 1,"first");
            rBIdx = find(brushDataIdx, 1, "last");

            corr_opts = struct();
            %corr_opts.BaselineX = [lB(1), rB(1)];
            corr_opts.BaselineIndex = [lBIdx, rBIdx];
            if ~isempty(data.iCP) && logical(app.fixCPCheckBox.Value)
                corr_opts.ContactPointIndex = data.iCP;
            end
            if strcmp(app.oscillationcorrectionSwitch.Value, 'On')
                corr_opts.CorrectOsc = true;
            end
            data = data.correct(corr_opts);

            app.Data(app.iSelectedData).(selTr) = data;
            
            CP_x2 = app.Data(app.iSelectedData).(selTr).Sep(1) - (data.Sep(1) - 0);
            corr_opts.ContactPointIndex = app.Data(app.iSelectedData).(selTr).chan2i(CP_x2, 'Sep',1);
            app.Data(app.iSelectedData).(selTr) = app.Data(app.iSelectedData).(selTr).correct(corr_opts);
            app.Data(app.iSelectedData) = app.Data(app.iSelectedData).zero_evals(selTr);

            %auch den anderen trace mit diesen baseline endpunkten
            %neu korrigieren!
            if app.CB_ManCorChan.Value
                app.Data(app.iSelectedData).(othTr) = app.Data(app.iSelectedData).(othTr).correct(corr_opts);
                app.Data(app.iSelectedData) = app.Data(app.iSelectedData).zero_evals(othTr);
            end
            
            if strcmp(app.AutoreviewoptionsMenu.Checked, 'on')
                app.Data(app.iSelectedData) = app.Data(app.iSelectedData).evaluate(app.propsToEval);
            end
        end
        
        function setNewCPfromCursor(app)
            if logical(app.TB_corrApp.Value)
                selTr = 'ap';
                othTr = 'rt';
            else
                selTr = 'rt';
                othTr = 'ap';
            end

            CPinfo = getCursorInfo(app.subapp.dcm);
            app.Data(app.iSelectedData).(selTr).iCP = CPinfo.DataIndex;            
            
            if logical(app.CB_ManCorChan.Value)
                app.Data(app.iSelectedData).(othTr).iCP = app.Data(app.iSelectedData).(othTr).chan2i(CPinfo.Position(1), 'Height',2);
            end

            if strcmp(app.AutoreviewoptionsMenu.Checked, 'on')
                app.Data(app.iSelectedData) = app.Data(app.iSelectedData).evaluate(app.propsToEval);
            end
          
        end
        
        function [no_w_pre] = num2si_w_p(app, in, fmt)

            arguments
                app
                in  {mustBeNumeric}
                fmt char {mustBeTextScalar} = ''
            end
            vpw = [ -30; -27; -24; -21; -18; -15; -12;  -9;  -6;  -3;   3;  6;    9;  12;  15;  18;   21;  24;  27;  30]; 
            pfs = { 'q'; 'r'; 'y'; 'z'; 'a'; 'f'; 'p'; 'n'; 'µ';' m'; 'k'; 'M'; 'G'; 'T'; 'P'; 'E'; 'Z' ; 'Y'; 'R'; 'Q'}; 

            exp = floor(log10(in)/3)*3;
            no = in*10^(-exp);
            pre = pfs(vpw==exp);

            if isempty(fmt)
                no_w_pre = [num2str(no) ' ' pre{1}];
            else
                no_w_pre = [num2str(no, fmt) ' ' pre{1}];
            end
        end
        
        function cmap = getColormapArray(app, cmName, n)
            arguments
                app
                cmName  char {mustBeText}
                n       int8 {mustBeNumeric}
            end

            try
                cmap = eval([cmName '(' num2str(n) ')']);
            catch ME
                error(ME.message);
            end

            
        end
        
        function results = add_data(app, fname)
            is_group = false;
            files = {};
            
            if ischar(fname)
                [path, filename, fext] = fileparts(fname);
                if strcmp(fext, '.mca')
                    uialert(app.FDUIFigure, ['While loading ' filename ...
                        ': Loading of point and shoot data not implemented, yet.' '' ...
                        ' Please load force curves individually or select whole folder.'], ...
                        'Loading error', 'Icon','error');
                else
                    if isfile(fname)
                        files = {fname};
                    elseif isfolder(fname)
                        tdir = dir(fname);
                        tdir([tdir.isdir]) = [];
                        validExts = [".spm", ".txt"];
                        tdir(~endsWith({tdir.name}, validExts)) = [];
                        files = fullfile(fname, {tdir.name}');
                        is_group = true;
                        groupname = filename;
                    end
                end
            else
                files = fname';
            end
            
            
            wbh = uiprogressdlg(app.FDUIFigure,'Title','Please wait', ...
                'Message', ['Adding data: 0/' num2str(length(files))],...
                'Cancelable', 'on');
            
            %Import of force data files.
            isLoaded = true(size(files));
            for iFile = 1:length(files)
                
                if exist('wbh', 'var')
                    if wbh.CancelRequested, break; end
                    wbh.Value = iFile/length(files);
                    wbh.Message = ['Adding data: ' num2str(iFile) '/' num2str(length(files))];
                end                
                 %determination of file type is done in FDdata_ar               
                
                try
                    if isempty(app.Data)
                        app.Data = FDdata_ar(files{iFile}, 'warnHandling', 'suppress',...
                            'callingAppWindow', app.FDUIFigure);
                    else
                        app.Data(end+1,1) = FDdata_ar(files{iFile}, 'warnHandling', 'suppress',...
                            'callingAppWindow', app.FDUIFigure);
                    end
                    app.Data(end).errHandling = 'UIDialog';
                catch ME
                    uialert(app.FDUIFigure, ['While loading ' files{iFile} ': ' ME.message], 'Error', 'Icon','error');
                end
                
                if ~isempty(app.Data) && isempty(app.Data(end))
                    app.Data(end) = [];
                    isLoaded(iFile) = false;
                end
                
            end
            if exist('wbh', 'var'), close(wbh); end

            
            [ ~, filenames, ~] = fileparts(files(isLoaded));
            if isempty(app.DataNames)
                app.DataNames = filenames;
            else
                app.DataNames = [app.DataNames; filenames];
            end
            
            if is_group
                %if its a group -> create a new node and put the data directly in the newly prepared
                %treenode
                if ~isempty(app.tree_dataSorted.Children) && isempty(app.tree_dataSorted.Children(end).Children)
                    act_series_node = app.tree_dataSorted.Children(end);
                else
                    act_series_node = uitreenode("Parent", app.tree_dataSorted);
                    act_series_node.ContextMenu = app.ContextMenu_series;
                end
                nodeIdx = length(app.tree_dataSorted.Children);
                act_series_node.Text = groupname;

                app.DataSorting = [app.DataSorting; ones(size(files(isLoaded)))*nodeIdx];
            else
                app.DataSorting = [app.DataSorting; zeros(size(files(isLoaded)))];
            end
            
            app.actualize_lists;
            
            %check if any imported data have different channels in ap and rt
            if ~( all(arrayfun(@(x) length(x.ap.AvChannels) == length(x.rt.AvChannels),  app.Data)) && ...
                    all(arrayfun(@(x) all(strcmp(x.ap.AvChannels, x.rt.AvChannels)), app.Data))  )
                uialert(app.FDUIFigure ,'For some or all imported data the number and/or type of imported channels differs. Unexpected behavior might result.', ...
                    'Icon', 'warning');
            end
            
            if strcmp(app.AutocorrectondataimportMenu.Checked, 'on')
                app.StartautocorrectalldataMenuSelected([]);
            end

            if strcmp(app.AutoevaluateMenu.Checked, 'on')
                app.Data = app.Data.evaluate('all');
            end
        end
        
        function closeAllSubWindows(app)
            if ~isempty(app.subapp) && isstruct(app.subapp)
                fields = fieldnames(app.subapp)';
                for ii = 1:numel(fields)
                    if strcmp(fields{ii}, 'extAxisWindow')
                        app.delExtAxisWindow();
                    else
                        delete(findall(app.subapp.(fields{ii}), 'Type', 'figure'));
                    end
                end
            end                
        end
    end

    methods (Access = public)

        %temp function, copied from indentation app - to be adjusted
        function results = exportFits(app, inpt)
            %ask what to export:
            %TODO: 
            % - which datasets 
            % - which fit models if there are more than one 
            % - datapoints+fitted curve and/or fit values
            %[ex_data, ex_fits] = ask_export_box(fh);

            % einschränkung: es muss ein modell gewählt werden und nur für
            % dieses Modell wird exportiert. Falls mehrere Modelle pro
            % Datensatz existieren, müssen sie nacheinander exportiert
            % werden.

            ex_data = inpt.exportData;
            ex_fits = inpt.exportParams;
            modelID = inpt.modelID;
            iExport = inpt.dataToExp;
            folder = inpt.saveDest;

            prec = '%.7g'; %precision for numeric output
    
    
            if any([ex_data, ex_fits])
                %determine number of existing fits
                getIDofExistingFitsFun = @(x) arrayfun(@(y) y.model.ID, x.DataFits, 'UniformOutput', false);
                checkIfModelExistsFun = @(x, mID) arrayfun(@(y) any(strcmp(mID, getIDofExistingFitsFun((y)))), x);
                
                getModelIdx = @(x, mID) arrayfun(@(y) find(strcmp(mID, getIDofExistingFitsFun((y))),1), x); %(works only if modelID exists in y)
                
                iExport = iExport & checkIfModelExistsFun(app.Data, modelID);
                if ~any(iExport)
                    uialert(app.FDUIFigure,"No selected dataset contains a fit with the '" + modelID+ "' model. No output file produced." ...
                        , "No match","Icon","warning");
                    return
                end


                datanumbers_to_ex = find(iExport);
                %create export variables
                data_to_ex = app.Data(iExport);
                
                %Idxs of fit for respective dataset
                fitIdxs = getModelIdx(data_to_ex, modelID);
                %fits_to_export = fits(iExport);

                datanames_to_exp = app.DataNames(iExport);
    
                for ii = 1:sum(iExport)

                    actTrace = data_to_ex(ii).DataFits(fitIdxs(ii)).trace;
                    actXChan = data_to_ex(ii).DataFits(fitIdxs(ii)).xchannel;
                    actYChan = data_to_ex(ii).DataFits(fitIdxs(ii)).ychannel;
                    actDataIdxs = data_to_ex(ii).DataFits(fitIdxs(ii)).data;
                    if numel(actDataIdxs) == 2
                        actDataIdxs = (actDataIdxs(1):actDataIdxs(2));
                    end
    
                    if ex_data      %compose table with curves
                        
                        %table with exp. x-data, exp. y-data and fitted y-data
                        

                        temp_t = table( data_to_ex(ii).(actTrace).(actXChan)(actDataIdxs),...
                            data_to_ex(ii).(actTrace).(actYChan)(actDataIdxs),...
                            data_to_ex(ii).DataFits(fitIdxs(ii)).funcRes(data_to_ex(ii).(actTrace).(actXChan)(actDataIdxs)) );
    
                        temp_t.Properties.VariableNames = {[actXChan '_' num2str(datanumbers_to_ex(ii))],...
                            [actYChan '_' num2str(datanumbers_to_ex(ii))], [actYChan 'Fit_' num2str(datanumbers_to_ex(ii))]};
                        temp_t.Properties.VariableUnits = {data_to_ex(ii).DataFits(fitIdxs(ii)).model.independentdim,...
                            data_to_ex(ii).DataFits(fitIdxs(ii)).model.dependentdim, ...
                            data_to_ex(ii).DataFits(fitIdxs(ii)).model.dependentdim}; 
                        
                        if ii == 1
                            exTable_data = temp_t;
                        else
                            if height(temp_t) < height(exTable_data) && ii > 1
                                temp_t{height(temp_t)+1:height(exTable_data),:} = NaN;
                            else
                                exTable_data{height(exTable_data)+1:height(temp_t),:} = NaN;
                            end
                            exTable_data = [exTable_data temp_t];
                        end
    
                    end
    
                    if ex_fits  %compose table with fit values and their errors
    
                        no_free_params = length(data_to_ex(ii).DataFits(fitIdxs(ii)).model.varPars); %length(coeffvalues(fits_to_export{ii}.cfits));
                        no_fixed_params = length(data_to_ex(ii).DataFits(fitIdxs(ii)).model.fixedPars); %length(fits_to_export{ii}.coefvals) - no_free_params;
                        no_param_cols = 2*no_free_params + no_fixed_params;
    
    
                        %construct cellstr row array with names of params and
                        %right to each free param an entry with
                        %'param_name'_err. Do similar for units.
                        param_names = data_to_ex(ii).DataFits(fitIdxs(ii)).model.varPars;
                        param_names(2,:) = cellfun(@(x) [x '_err'], param_names, 'UniformOutput', false);
                        param_names = param_names(:)';
                        param_names = [param_names data_to_ex(ii).DataFits(fitIdxs(ii)).model.fixedPars];
                        allunits = data_to_ex(ii).DataFits(fitIdxs(ii)).model.parameterdims;
                        units = allunits(~data_to_ex(ii).DataFits(fitIdxs(ii)).model.parameter_isfixed);
                        units(2,:) = units;
                        units = units(:)';
                        units = [units allunits(data_to_ex(ii).DataFits(fitIdxs(ii)).model.parameter_isfixed)];

    
                        header = [{'dataset number' 'filename' 'fit function'} param_names;...
                                    {'' '' ''} units];
    
                        %include also fit limits
                        xDim = data_to_ex(ii).DataFits(fitIdxs(ii)).model.independentdim;
                        header(:,end+1:end+2) = [{'fit_XMinLimit' 'fit_XMaxLimit'}; {xDim xDim}];
    
    
                        if ii == 1
                            %for direct text file output:
                            exCell_fits = header;
    
                            %fot table/xls export:
                            %eresults = [{'filename'} param_names {'fit function'}];
    
                            eresults = [cellfun(@(x,y) [x '__' y], param_names, ...
                                            strrep(units, '/', '_'), 'UniformOutput', false)... %append dimension to param_name
                                        {'fit_function'}];
                        end
    
                        param_values = data_to_ex(ii).DataFits(fitIdxs(ii)).paramRes;
    
                        %bounds = confint(fits_to_export{ii}.cfits);
                        %errors = mean(abs(bounds - ones(2,1)*param_values));
                        param_values(2,:) = mean(abs(data_to_ex(ii).DataFits(fitIdxs(ii)).errors));
                        param_values = param_values(:)';
                        fixedParamIdxs = data_to_ex(ii).DataFits(fitIdxs(ii)).model.parameter_isfixed;
                        fixed_values = data_to_ex(ii).DataFits(fitIdxs(ii)).model.parametervalues(fixedParamIdxs);
                        param_values = [param_values fixed_values];
 
    
    
    
                        %create cell with fit results
                        %eresults(ii+1,1) = datanames_to_exp(ii);
                        eresults(ii+1,1:length(param_values)) = num2cell(param_values);
                        %function string:
                        eresults{ii+1,length(param_values)+1} = [data_to_ex(ii).DataFits(fitIdxs(ii)).model.dependent ...
                            ' = ' data_to_ex(ii).DataFits(fitIdxs(ii)).model.funcStr];
    
    
                        %this if cond. should never be true (still from old
                        %file). Check and remove!
                        if ii > 1
                            if ~cont && ~strcmp(eresults{ii,end}, eresults{ii+1,end})
                                answ = questdlg('Different fit models were used. Output file will have multiple headers. Continue anyway?',...
                                'Fit type warning', 'Yes', 'No', 'Yes');
                                if ~logical(strcmp(answ, 'Yes'))
                                    return
                                end
                                cont = true;
                            end
                        else cont = false;
                        end
    
                        fitfun = [data_to_ex(ii).DataFits(fitIdxs(ii)).model.dependent ...
                            ' = ' data_to_ex(ii).DataFits(fitIdxs(ii)).model.funcStr];
                        if ii~=1 && ~strcmp(fitfun,exCell_fits{end,3})
                            exCell_fits(end+1:end+size(header,1),1:size(header,2)) = header;
                        end
    
                        exCell_fits(end+1,1:length(param_values)+3) = [num2str(datanumbers_to_ex(ii), prec) datanames_to_exp(ii) fitfun ...
                            cellfun(@(x) num2str(x, prec), num2cell(param_values), 'UniformOutput', false)];
                         %include also fit limits
                        exCell_fits(end,end-1:end) = {num2str(data_to_ex(ii).(actTrace).(actXChan)(actDataIdxs(1)), prec) ...
                            num2str(data_to_ex(ii).(actTrace).(actXChan)(actDataIdxs(end)), prec)};
    

                     end
                end
    
    
                %export

                filename = folder(1:end-4);
    
                if ex_data
                    numericExCell = table2cell(exTable_data);
                    numericExCell(isnan(exTable_data{:,:})) = {''};
                    strData = cellfun(@(x) num2str(x, prec), numericExCell, 'UniformOutput', false);
                    exCell_data = [exTable_data.Properties.VariableNames; exTable_data.Properties.VariableUnits;...
                                    strData];
                
                     dfilename = filename + "_curves.txt";
    
                    if ~isnumeric(dfilename)
                        fID = fopen(dfilename,'w', 'n', 'UTF-8');
                        formatspec = strjoin(cellfun(@(x) '%s', cell(1,size(exCell_data,2)),'UniformOutput', false),'\t');
                        for iex = 1:size(exCell_data,1)
                            fprintf(fID, [formatspec '\n'], exCell_data{iex,:} );
                        end
                        fclose(fID);
                    end
                end
                
                
                if ex_fits
                    ffilename = filename + "_fitpars.txt";
    
                    if ~isnumeric(ffilename)

                        fID = fopen(ffilename,'w', 'n', 'UTF-8');
                        formatspec = strjoin(cellfun(@(x) '%s', cell(1,size(exCell_fits,2)),'UniformOutput', false),'\t');
                        for iex = 1:size(exCell_fits,1)
                            fprintf(fID, [formatspec '\n'], exCell_fits{iex,:} );
                        end
                        fclose(fID);
    
                    end
                end 
            end
        end


        function delExtAxisWindow(app, ~)
            app.axes1.Visible = 'off';
            app.axes1.Parent = app.FDUIFigure;
            app.axes1.Position = [413,218,448,326].*...
                repmat(app.FDUIFigure.Position(3:4)./[860, 571],1,2);
            app.axes1.Visible = 'on';
            delete(app.subapp.extAxisWindow);
            app.subapp.extAxisWindow = [];
            app.MakeSepPlotWindowButton.Enable = 'on';
        end
        

        function startSelectData(app, selMode, dataPart, xChan, yChan, varargin)
            %%% begins data selection process.
            %Inputs:
            % selMode: (char) 'multi'|'single'  multi selection via brush tool or single with datacursor
            % dataPart: FDdata object (appr. or retr. part of FDdata_ar object)
            % xChan/yChan (char) name of respective channel (must be property of FDdata object)
            % varargin: "Name"-value pairs for plotting, allowed: 'LinieProp', 'xLabel', 'yLabel','Title'
    
            [argin1, argin2] = parseparams(varargin);
            if ~isempty(argin1) || mod(numel(argin2),2)>0
                error('Wrong number of input parameters/Name-Value pairs.')
            end
            params = struct();
            for ii=1:numel(argin2)/2
                params.(argin2{1}) = argin2{2};
                argin2(1:2) = [];
            end
            if isfield(params, 'LineProp')
                lineprop = params.LineProp;
            else
                lineprop = '.g';
            end
            if isfield(params, 'selectID')
                app.SelDataOKButton.UserData{1} = params.selectID;
            else
                app.SelDataOKButton.UserData{1} = [];
                warning('No selectID passed. No action will be taken after button click!')
            end
            

            app.SelDataOKButton.Visible = "on";
            app.SelDataOKButton.Enable = "on";

            lh = plot(app.axes1, dataPart.(xChan), dataPart.(yChan), lineprop);

            if isfield(params, 'xLabel')
                xlabel(app.axes1, params.xLabel);
            else
                xlabel([xChan ' / ' data.Unit(xChan)]);
            end
            if isfield(params, 'yLabel')
                ylabel(app.axes1, params.yLabel);
            else
                ylabel([yChan ' / ' data.Unit(yChan)]);
            end
            if isfield(params, 'Title')
                app.axes1.Title.String = params.Title;
            end

            switch selMode
                case 'multi'
                    bh = brush(app.axes1);
                    bh.Enable = "on";
                    bh.Color = lh.Color; %lineprop(end);
                    
                case 'single'
                    app.subapp.dcm = datacursormode(app.axes1.Parent);
                    app.subapp.dcm.Enable = 'On';
            end
            app.axes1.Toolbar.Visible = "off";
            
            
            %disable all other figure parts
            app.MenuFile.Enable = "off";
            app.OptionsMenu.Enable = "off";
            app.ToolsMenu.Enable = "off";
            app.PlotcontrolPanel.Enable = "off";
            app.ManualCorrPanel.Enable = "off";
            app.CalibrationcorrectionPanel.Enable = "off";
            app.lb_allData.Enable = "off";
            app.tree_dataSorted.Enable = "off";
            app.pb_rmSeries.Enable = "off";
            app.pb_addSeries.Enable = "off";
            app.pb_remData.Enable = "off";
            app.pb_addData.Enable = "off";
            

            %selection process will be ended by click on "confirm" button.
            %see: function: app.SelDataOKButtonPushed(app, event)
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.autoCorrectOptions = struct();
            app.autoCorrectOptions.CorrectOsc = false;
            app.autoCorrectOptions.BaselineThres = 3;

            app.DropDown_colormap.Items = {'parula', 'turbo', 'hsv', 'hot',...
                'cool', 'spring', 'summer', 'autumn', 'winter', 'gray', ...
                'bone', 'copper', 'pink', 'sky', 'abyss', 'jet', 'lines', ...
                'colorcube', 'prism', 'flag'};

            app.LastFolder = pwd;
            
            addpath(genpath(fullfile(pwd, "classes")));
            addpath(genpath(fullfile(pwd, "helper functions")));
            addpath(genpath(fullfile(pwd, "icons")));
            addpath(genpath(fullfile(pwd, "models")));
            addpath(genpath(fullfile(pwd, "subapps")));

        end

        % Menu selected function: MenuFile
        function MenuFileSelected(app, event)
            if isempty(app.Data)
                app.ExportDataMenu.Enable = "off";
            else
                app.ExportDataMenu.Enable = "on";
            end

            if isempty(app.lb_allData.Value)
                app.ClosedataMenu.Enable = "off";
            else
                app.ClosedataMenu.Enable = "on";
            end
        end

        % Menu selected function: AddDataMenu
        function MenuAddData(app, event)
            %[file, path]=uigetfile({'*.txt', 'Exported text files (*.txt)'; '*.spm', 'Bruker Nanoscope force files (*.spm, *.000 etc.)'; '*.*', 'other'},'Select files', [app.LastFolder '/'], 'MultiSelect','on');
            [file, path]=uigetfile('*.*','Select files', [app.LastFolder '/'], 'MultiSelect','on');
            app.FDUIFigure;
            if isnumeric(file) && file == 0, return; end   %end execution if user pressed "cancel"
            app.LastFolder = path;

            app.FDUIFigure.Visible = "off";
            app.FDUIFigure.Visible = 'on';

            app.add_data(fullfile(path,file));

        end

        % Menu selected function: AddfolderMenu
        function AddfolderMenuSelected(app, event)
            newpath = uigetdir([app.LastFolder '/']','Select folder with FD data files');
            app.FDUIFigure;
            if isnumeric(newpath) && newpath == 0, return; end   %end execution if user pressed "cancel"
            app.LastFolder = newpath;

            app.FDUIFigure.Visible = "off";
            app.FDUIFigure.Visible = 'on';

            app.add_data(newpath);
        end

        % Menu selected function: ExportDataMenu
        function ExportDataMenuSelected(app, event)
            save_path = uigetdir(app.LastFolder,'Choose folder for export');
            if save_path == 0, return
            else,  save_path = [save_path '/'];
            end
            
            ask = 1;
            overwr = 1;
            for iS = 1:length(app.Data)
                path = [save_path app.DataNames{iS} '_corr.txt' ];
                if logical(ask) && logical(exist(path, 'file'))
                    answ = questdlg(['Some files already exists. Overwrite?'], ...
                        'File exists', 'Yes', 'No, cancel', 'No, cancel');
                    switch answ
                        case 'Yes'
                            overwr = 1;
                            ask = 0;
                        case 'No, cancel'
                            overwr = 0;
                            ask = 0;
                    end
                end
                if logical(overwr)
                    app.Data(iS).writetotxt(path);
                end
            end
        end

        % Menu selected function: ClosedataMenu
        function ClosedataMenuSelected(app, event)
           if isempty(app.lb_allData.Value)
               return
           end
           DataIdx = app.lb_allData.Value;
           app.Data(DataIdx) = [];
           app.DataSorting(DataIdx) = [];
           app.DataNames(DataIdx) = [];
           app.actualize_lists();
        end

        % Menu selected function: OpenMenu
        function OpenMenuSelected(app, event)
            if isempty(app.Data)
                proceed = true;
            else
                selection = uiconfirm(app.FDUIFigure, "This will close your actual session. Proceed?", "Warning",...
                    "Icon","warning");
                if strcmp(selection, 'OK')
                    proceed = true;
                else
                    proceed = false;
                end
            end

            if proceed
                [files, path]=(uigetfile([app.LastFolder,'/.mat'],'MultiSelect','off'));
                if isnumeric(files) && files == 0, return; end   %end execution if user pressed "cancel"

                pbH = uiprogressdlg(app.FDUIFigure,'Title','Please wait', ...
                    'Message', ['Opening file:'],...
                    'Cancelable', 'on');
                
              
                file_cont = whos('-file', fullfile(path, files));
                
                %test for correct variables
                if ~(any(strcmp({file_cont.name},'eData')) && ... % check existence and class of eData
                        strcmp(file_cont(strcmp({file_cont.name},'eData')).class,'FDdata_ar')) || ... 
                    ~(any(strcmp({file_cont.name},'eDataNames')) && ... % check existence and class of eDataNames
                        strcmp(file_cont(strcmp({file_cont.name},'eDataNames')).class,'cell')) || ...
                    ~(any(strcmp({file_cont.name},'eDataSorting')) && ... % check existence and class of eDataSorting
                        strcmp(file_cont(strcmp({file_cont.name},'eDataSorting')).class,'double')) || ...
                        ~(all(file_cont(strcmp({file_cont.name},'eData')).size == ... % check matching of eData and eDataNames sizes
                                file_cont(strcmp({file_cont.name},'eDataNames')).size )) || ...
                        ~(all(file_cont(strcmp({file_cont.name},'eData')).size == ... % check matching of eData and eDataSorting sizes
                                file_cont(strcmp({file_cont.name},'eDataSorting')).size )) || ...
                    ~(any(strcmp({file_cont.name},'eSeriesNames')) && ... % check existence and class of eSeriesNames
                        strcmp(file_cont(strcmp({file_cont.name},'eSeriesNames')).class,'cell'))
                    
                    uialert(app.FDUIFigure ,"Error while opening file.","File error.", ...
                    "Icon","error"); 
                end
                toLoad = {"eData", "eDataNames", "eDataSorting", "eSeriesNames"};


                pbH.Message = 'Loading file';
                pbH.Indeterminate = "on";

                load(fullfile(path, files), toLoad{:});

                pbH.Message = 'Adding data';

                app.ClosedataMenu();
                if isrow(eData)
                    app.Data = eData';
                else
                    app.Data = eData;
                end
                for ii = 1:numel(eData)
                    app.Data(ii).callingAppWindow = app.FDUIFigure;
                    app.Data(ii).warnHandling =  'suppress';
                    app.Data(ii).errHandling = 'UIDialog';
                end
                if isrow(eDataNames)
                    app.DataNames = eDataNames';
                else
                    app.DataNames = eDataNames;
                end
                if isrow(eDataSorting)
                    app.DataSorting = eDataSorting';
                else
                    app.DataSorting = eDataSorting;
                end

                if iscellstr(eSeriesNames)
                    delete(app.tree_dataSorted.Children);
                    for ii=1:length(eSeriesNames)
                        new_node = uitreenode(app.tree_dataSorted,'Text',eSeriesNames{ii});
                        new_node.ContextMenu = app.ContextMenu_series;
                    end
                end

                if wImages
                    pbH.Message = 'Adding images';
                    app.Images = eImages;
                    for ii = 1:length(eImagesLinks)
                        if ii > 0
                            app.tree_dataSorted.Children(ii).NodeData = struct('ImgDataIdx', eImagesLinks(ii), 'FigIdx', '');
                            app.tree_dataSorted.Children(ii).Icon = fullfile(fileparts(mfilename("fullpath")),'icons/icons8-image-48.png');
                        end
                    end
                end

                app.iSelectedData = find(app.DataSorting>0,1,'first');
                pbH.Message = 'finishing';

                app.actualize_lists;
                expand(app.tree_dataSorted, 'all');
                app.actualize_objects;
                app.actualize_plot;

                app.thisFileName = files;
                app.thisFilePath = path;
                app.FDUIFigure.Name = ['FD - ' files];

                close(pbH);
            end


        end

        % Menu selected function: SaveMenu, SaveasMenu
        function SaveMenuSelected(app, event)
            if isempty(app.thisFileName) || event.Source.Text == "Save as..."
                [dfilename, pathname] = uiputfile({'/*.mat'},...
                        'Save current state', [app.LastFolder]);
                if isnumeric(dfilename) && dfilename == 0
                    return
                end
            else
                pathname = app.thisFilePath;
                dfilename = app.thisFileName;
            end

            eData = app.Data;
            for ii = 1:numel(eData)
                eData(ii).callingAppWindow = [];
            end
            eDataNames = app.DataNames;
            eDataSorting = app.DataSorting;
            eSeriesNames = {app.tree_dataSorted.Children.Text};
 
            save([pathname dfilename], "eData", "eDataNames", ...
                "eDataSorting", "eSeriesNames");
 
            app.thisFileName = dfilename;
            app.thisFilePath = pathname;
            app.FDUIFigure.Name = ['FD - ' dfilename];

        end

        % Menu selected function: ClosesessionMenu
        function ClosesessionMenuSelected(app, event)
            answ = 'OK';
            if app.FDUIFigure.Name(end) == '*'
                answ = uiconfirm(app.FDUIFigure, 'Your last changes have not been saved. Do you really want to close this session?',...
                    'Confirm close',"Icon","warning");
            elseif strcmp(app.FDUIFigure.Name, 'FD') && ~isempty(app.Data)
                answ = uiconfirm(app.FDUIFigure, 'This session has not been saved. Do you really want to close it?',...
                    'Confirm close',"Icon","warning");
            end
            if strcmp(answ, 'Cancel')
                return
            end
            
            
            app.Data = [];
            app.DataNames = [];
            app.DataSorting = [];
            app.iSelectedData = [];
            app.lb_allData.Items = {};
            app.lb_allData.ItemsData = {};
            delete(app.tree_dataSorted.Children);
            uitreenode(app.tree_dataSorted,'Text','Series1');
            app.closeAllSubWindows();
         
            cla(app.axes1);
            app.FDUIFigure.Name = 'FD';
        end

        % Menu selected function: AutocorrectondataimportMenu
        function AutocorrectondataimportMenuSelected(app, event)
            if strcmp(app.AutocorrectondataimportMenu.Checked,'on')
                app.AutocorrectondataimportMenu.Checked = 'off';
            else
                app.AutocorrectondataimportMenu.Checked = 'on';
            end
        end

        % Menu selected function: AutocorrectoptionsMenu
        function AutocorrectoptionsMenuSelected(app, event)
%             autoCorrectPopupValues = struct();
%             autoCorrectPopupValues.Bl_osc = app.autoCorrectOptions.CorrectOsc;
%             
%             if isfield(app.autoCorrectOptions, 'BaselinePrio')
%                 autoCorrectPopupValues.Bl_cor = app.autoCorrectOptions.BaselinePrio;
%             end
%             
%             if isfield(app.autoCorrectOptions, 'ContactPointPrio')
%                 switch app.autoCorrectOptions.ContactPointPrio
%                     case 'ap'
%                         autoCorrectPopupValues.CP_det = 1;
%                     case 'rt'
%                         autoCorrectPopupValues.CP_det = 2;
%                     case 'lowest'
%                         autoCorrectPopupValues.CP_det = 3;
%                     otherwise
%                         autoCorrectPopupValues.CP_det = 0;
%                 end
%             else
%                 autoCorrectPopupValues.CP_det = 0;
%             end

            if isempty(app.subapp) || ~isfield(app.subapp, 'AutoCorrectOptions') || isempty(app.subapp.AutoCorrectOptions)
                autocorrect_options(app);
            else
                app.subapp.AutoCorrectOptions.Visible = 'off';
                app.subapp.AutoCorrectOptions.Visible = 'on';
            end
        end

        % Menu selected function: StartautocorrectalldataMenu
        function StartautocorrectalldataMenuSelected(app, event)
            wbh = uiprogressdlg(app.FDUIFigure,'Title','Please wait', ...
                'Message', ['Correcting data: 0/' num2str(length(app.Data))],...
                'Cancelable', 'on');
            
            for iD = 1:length(app.Data)
                if exist('wbh', 'var') && (length(app.Data)>1)
                    if wbh.CancelRequested, break; end
                    wbh.Value = iD/length(app.Data);
                    wbh.Message = ['Correcting data: ' num2str(iD) '/' num2str(length(app.Data))];
                end
                app.Data(iD) = app.Data(iD).auto_correct(app.autoCorrectOptions);
            end
            if exist('wbh', 'var'), close(wbh); end
            app.actualize_plot;
        end

        % Menu selected function: StartautocorrectselecteddataMenu
        function StartautocorrectselecteddataMenuSelected(app, event)
            
            if length(app.Data(app.iSelectedData)) > 1
                wbh = uiprogressdlg(app.FDUIFigure,'Title','Please wait', ...
                'Message', ['Correcting data: 0/' num2str(length(app.Data(app.iSelectedData)))],...
                'Cancelable', 'on');
            end
            
            for iD = 1:length(app.Data(app.iSelectedData))
                if exist('wbh', 'var') && (length(app.Data)>1)
                    if wbh.CancelRequested, break; end
                    wbh.Value = iD/length(app.Data);
                    wbh.Message = ['Correcting data: ' num2str(iD) '/' num2str(length(app.Data(app.iSelectedData)))];
                end
                app.Data(app.iSelectedData(iD)) = app.Data(app.iSelectedData(iD)).auto_correct(app.autoCorrectOptions);
               
                if strcmp(app.AutoreviewoptionsMenu.Checked, 'on')
                    app.Data(app.iSelectedData) = app.Data(app.iSelectedData).evaluate(app.propsToEval);
                end
            end
            if exist('wbh', 'var'), close(wbh); end
            app.actualize_plot;
        end

        % Menu selected function: EvaluateselectedcurvesMenu
        function EvaluateselectedcurvesMenuSelected(app, event)
            num_data = numel(app.iSelectedData);
            
            if num_data > 1
                wbh = uiprogressdlg(app.FDUIFigure,'Title','Please wait', ...
                'Message', ['Evaluating data: 0/' num2str(num_data)],...
                'Cancelable', 'on');
            end
            
            for iD = 1:num_data
                if exist('wbh', 'var') && (length(app.Data)>1)
                    if wbh.CancelRequested, break; end
                    wbh.Value = iD/length(app.Data);
                    wbh.Message = ['Evaluating data: ' num2str(iD) '/' num2str(num_data)];
                end
                app.Data(app.iSelectedData(iD)) = app.Data(app.iSelectedData(iD)).evaluate('all');
            end
            if exist('wbh', 'var'), close(wbh); end
            app.actualize_plot;
        end

        % Menu selected function: AutoevaluateMenu
        function AutoevaluateMenuSelected(app, event)
            if strcmp(app.AutoevaluateMenu.Checked,'on')
                app.AutoevaluateMenu.Checked = 'off';
            else
                app.AutoevaluateMenu.Checked = 'on';
            end
        end

        % Menu selected function: SelectevaluationpropertiesMenu
        function SelectevaluationpropertiesMenuSelected(app, event)
            
        end

        % Menu selected function: ExportevaluatedvaluesMenu
        function ExportevaluatedvaluesMenuSelected(app, event)
            %abfrage: ausgewählte oder alle Daten in rechter Liste (wenn
            %mehr als eine ausgewählt ist.
            if numel(app.iSelectedData) > 1
                answ = uiconfirm(app.FDUIFigure, "Export only from selected or from all files?",...
                    "Data selection","Icon","question" ,"Options", ["Only selected", "All"],...
                    "DefaultOption", "All");
            else
                answ = "All";
            end
            
            if answ == "All"
                dataToExpIdx = find(app.DataSorting>0);
            else
                dataToExpIdx = app.iSelectedData;
            end

            
            %Bestimmung der zu exportierenden Werte (über Auswahl-Fenster)
            %ToDO. Auswahlfenster, solange: alle!
            propsToExp = {'AdhForce', 'AdhSep', 'AdhEnergy', 'RuptLength',...
                        'xPosition', 'yPosition', 'Height', 'CP_Height', ...
                        'maxForce', 'maxInd'};
            propsLongName = {'Adhesion force', 'Adhesion Separation', ...
                'Adhesion energy', 'Rupture length', 'x position', 'y position',...
                'z position (lowest point)', 'z position (contact point)', ...
                'max. Force', 'max. Indentation'};
            unitsToExp = {'N', 'm', 'J', 'm',...
                        'm', 'm', 'm', 'm', ...
                        'N', 'm'};

            optionStruct = cell2struct([propsToExp; propsLongName; unitsToExp; ...
                num2cell((1:length(propsToExp))); num2cell(true(1,length(propsToExp) )) ],...
                {'optionName', 'optionLongName', 'optionUnits', 'option', 'optionIsValid'});

            for ii = 1:length(propsToExp)
                thisProp = optionStruct(ii).optionName;
                switch thisProp
                    case {'xPosition' , 'yPosition'}
                        isValid = ~all(cellfun(@isempty, {app.Data(dataToExpIdx).Position}));
                    case 'Height'
                        %do nothing
                        isValid = true;
                    case 'CP_Height'
                        isValid = ~all(arrayfun(@isempty, arrayfun(@(x) x.ap.CP_Height, app.Data(dataToExpIdx)) ));
                    case 'maxForce'
                        isValid = ~all(arrayfun(@isempty, arrayfun(@(x) max(x.ap.Fc), app.Data(dataToExpIdx)) ));
                    case 'maxInd'
                        isValid = ~all(arrayfun(@isempty, arrayfun(@(x) max(x.ap.Ind), app.Data(dataToExpIdx)) ));
                    otherwise
                        isValid = ~all(cellfun('isempty', {app.Data(dataToExpIdx).(thisProp)}));
                end
                optionStruct(ii).optionIsValid = isValid;
            end
            %optionStruct(~[optionStruct.optionIsValid]) = [];

            %open window for selection
            expWin = ExportPropsSelection(app, optionStruct, 'exportProperties');
            waitfor(expWin);
            %window writes selection into app.exportProperties

            %get selection from app.exportProperties and clear it afterwards
            propsToExp = optionStruct(cell2mat(app.exportProperties));
            app.exportProperties = [];

            if isempty(propsToExp), return, end

            %Formatierung
            expTab = table(app.DataNames(dataToExpIdx), 'VariableNames',{'Filename'});

            for ii = 1:length(propsToExp)
                thisProp = propsToExp(ii).optionName;
                switch thisProp
                    case 'xPosition'
                        thisPropCell = arrayfun(@(a) a.Position.x, app.Data(dataToExpIdx), "UniformOutput", false);
                    case 'yPosition'
                        thisPropCell = arrayfun(@(a) a.Position.y, app.Data(dataToExpIdx), "UniformOutput", false);
                    case 'Height'
                        thisPropCell = arrayfun(@(x) x.ap.Height(end), app.Data(dataToExpIdx), "UniformOutput", false);
                    case 'CP_Height'
                        thisPropCell = arrayfun(@(x) x.ap.CP_Height, app.Data(dataToExpIdx), "UniformOutput", false);
                    case 'maxForce'
                        thisPropCell = arrayfun(@(x) max(x.ap.Fc), app.Data(dataToExpIdx), "UniformOutput", false);
                    case 'maxInd'
                        thisPropCell = arrayfun(@(x) max(x.ap.Ind), app.Data(dataToExpIdx), "UniformOutput", false);
                    otherwise
                        thisPropCell = {app.Data(dataToExpIdx).(thisProp)}';
                end

                hasEntry = ~cellfun('isempty', thisPropCell);
                thisPropCell(~hasEntry) = {NaN};
                expTab.(thisProp) = cell2mat(thisPropCell);

            end
            expTab.Properties.VariableUnits = [{''} {propsToExp.optionUnits}];            

            
            %Speicherziel-Abfrage
            [dfilename, pathname] = uiputfile({'/*.txt'},...
                    'Export evaluated values', [app.LastFolder]);

            if ~logical(dfilename)
                return;
            end
            

            %Export

            writeTableWithUnits(expTab, fullfile(pathname, dfilename), 'Delimiter', '\t');
        end

        % Menu selected function: FilmIndentationMenu
        function FilmIndentationMenuSelected(app, event)
            series_size = numel(app.iSelectedData);
            pass_data = cell(length(series_size),1);
            spr_const = 0;
            last_spr_const = 0;
            for ii = 1:series_size
               pass_data{ii} = table(...
                     app.Data(app.iSelectedData(ii)).ap.Extension / 1e-9 ...
                    ,app.Data(app.iSelectedData(ii)).ap.Sep / 1e-9 ...
                    ,app.Data(app.iSelectedData(ii)).ap.Deflc /1e-9 ...
                    ,app.Data(app.iSelectedData(ii)).ap.Fc /1e-9 ...
                    ,'VariableNames', {'z_pos', 'sep', 'defl', 'F'});
                pass_data{ii}.Properties.VariableDescriptions = {'sensor position','separation', 'deflection', 'Force'};
                pass_data{ii}.Properties.VariableUnits = {'nm', 'nm', 'nm', 'nN'};
                
                if spr_const ~= 0
                    last_spr_const = spr_const;
                end
                spr_const = app.Data(app.iSelectedData(ii)).rt.SprConst;
                
                if (max(spr_const)>min(spr_const))
                    spr_const = mean(spr_const);
                    spr_const_txt = [num2str(spr_const), ' N/m (mean)'];
                else
                    spr_const = spr_const(1);
                    spr_const_txt = [num2str(spr_const), ' N/m'];
                end
                
                if (last_spr_const ~= 0) && ((spr_const-last_spr_const)/spr_const > 1e-3)
                    msgbox(['Series contains data with different sping constants. ',...
                        'Please import data from different experiments as different series'],...
                        'Data error');
                    return
                end
                
                pass_data{ii}.Properties.UserData{1} = ['Cantilever spring constant: ' spr_const_txt];
                
            %     if ischar(handles.curves(seriesno).file)
            %         descr =  handles.curves(seriesno).file; %only one curve per serie
            %     else
            %         descr =  handles.curves(seriesno).file{ii};
            %     end
            %     pass_data{ii}.Properties.Description = descr;
                pass_data{ii}.Properties.Description = app.DataNames{app.iSelectedData(ii)};
            
            end
            
            film_indentation(pass_data);
        end

        % Menu selected function: PeakFinderMenu
        function PeakFinderMenuSelected(app, event)
            series_size = numel(app.iSelectedData);
            pass_data = cell(length(series_size),1);

            for ii = 1:series_size
               pass_data{ii} = table(...
                    app.Data(app.iSelectedData(ii)).rt.Sep / 1e-9, ...
                    app.Data(app.iSelectedData(ii)).rt.Fc / 1e-12 ...
                    ,'VariableNames', {'X', 'Y'});
                pass_data{ii}.Properties.VariableDescriptions = {'Separation', 'Force'};
                pass_data{ii}.Properties.VariableUnits = {'nm', 'pN'};
                pass_data{ii}.Properties.Description = app.DataNames{app.iSelectedData(ii)};
                pass_data{ii}.Y = -pass_data{ii}.Y;
            end
            
            peakfit_gui(pass_data);
            
        end

        % Menu selected function: DatafittingMenu
        function DatafittingMenuSelected(app, event)
            FD_modelfits(app);
            movegui(app.subapp.Fitmodels);
        end

        % Menu selected function: ExportfitsMenu
        function ExportfitsMenuSelected(app, event)
            FitExport(app);
        end

        % Menu selected function: InspectevaluatedvaluesMenu
        function InspectevaluatedvaluesMenuSelected(app, event)
                        
            dataGroups = struct('Idxs', [], 'Name', '');
            if numel(app.iSelectedData) == 1
                isSelected = true(size(app.Data)) & (app.DataSorting > 0);
            else
                isSelected = false(size(app.Data));
                isSelected(app.iSelectedData) = true;
            end
            pass_data = app.Data;
            dataGroupNumbers = app.DataSorting;
            dataGroupNumbers(~isSelected) = 0;
            GroupNumbers = unique(dataGroupNumbers);
            
            GroupNumbers(GroupNumbers == 0) = [];

            groupNames = {app.tree_dataSorted.Children.Text};

            for ii = GroupNumbers'
                dataGroups(ii).Idxs = find(dataGroupNumbers == ii)';
                dataGroups(ii).Name = groupNames{ii};
            end

            ShowFDEvalData(pass_data, dataGroups);

        end

        % Button pushed function: pb_addData
        function pb_addData_cb(app, event)
            selData = app.lb_allData.Value;
            
            %Choice of top-level node where to sort the file in
            if numel(app.tree_dataSorted.SelectedNodes) > 1
                errordlg('Choose only one series where to sort the curves in.', 'Series selection error!');
            elseif isempty(app.tree_dataSorted.SelectedNodes)
                %If no node is selected, put file in first node (and create it if necessary)
                if isempty(app.tree_dataSorted.Children)
                    node = uitreenode(app.tree_dataSorted,'text', 'Series1');
                else
                    node = app.tree_dataSorted.Children(1);
                end
                nodeNum = 1;
            else
                %If top node (Series) or 2nd level node (file) 
                %is selected, choose corresponding top-level node
                node = app.tree_dataSorted.SelectedNodes;
                if node.Parent ~= app.tree_dataSorted
                    node = node.Parent;
                end
                nodeNum = find(node.Parent.Children == node,1);
            end
            
            app.DataSorting(selData) = nodeNum;
%             iListData = [];
%             for iL = selData
%                 %uitreenode(node, 'Text', app.DataNames{iL}, 'NodeData', iL);
%                 app.DataSorting(iL) = nodeNum;
%                 %iListData(end+1) = find(app.lb_allData.ItemsData == iL, 1);
%             end
            %app.lb_allData.Items = app.DataNames(app.DataSorting==0);
            %app.lb_allData.ItemsData(iListData) = find(app.DataSorting == 0);
            app.actualize_lists;
            app.actualize_plot();
        end

        % Button pushed function: pb_remData
        function pb_rmData_cb(app, event)
            if ~isempty(app.tree_dataSorted.SelectedNodes)
                iToDel = [app.tree_dataSorted.SelectedNodes.NodeData];
                app.DataSorting(iToDel) = 0;
                app.tree_dataSorted.SelectedNodes = [];
                app.iSelectedData = [];
                app.actualize_lists();
%                 newlist = sort([app.lb_allData.ItemsData iToDel]);
%                 app.lb_allData.Items = app.DataNames(newlist);
%                 app.lb_allData.ItemsData = newlist;
%                 delete(app.tree_dataSorted.SelectedNodes);
                app.actualize_plot();
            end
        end

        % Selection changed function: tree_dataSorted
        function tree_selCh_cb(app, event)
            %unselect nodes in ListBox
            if ~isempty(app.lb_allData.Items)
                app.lb_allData.Value = [];
            end
            
            selectedNodes = app.tree_dataSorted.SelectedNodes;
%             if selectedNodes(1).Parent == app.tree_dataSorted
%                 selectedNodes = selectedNodes(1).Children;
%             end
            parentNodesId = [];
            for ii = 1:numel(selectedNodes)
                if selectedNodes(ii).Parent == app.tree_dataSorted
                    selectedNodes = [selectedNodes; selectedNodes(ii).Children];
                    parentNodesId = [parentNodesId; ii];
                end
            end
            selectedNodes(parentNodesId) = [];

            if ~isempty(selectedNodes)
                %app.iSelectedData = sort([selectedNodes.NodeData]);
                app.iSelectedData = unique([selectedNodes.NodeData]);
            end
            %plot selected data
            if app.cb_autoplotsel.Value && ~isempty(selectedNodes)
                app.actualize_plot();
            end
            if isfield(app.subapp, 'Fitmodels') && ~isempty(app.subapp.Fitmodels) && isvalid(app.subapp.Fitmodels)
                app.subapp.Fitmodels.RunningAppInstance.dataSelectionChange();
            end
           app.actualize_objects();
        end

        % Button pushed function: pb_addSeries
        function pb_addSeries_cb(app, event)
            noSeries = numel(app.tree_dataSorted.Children);
            new_node = uitreenode(app.tree_dataSorted, 'Text', ['Series' num2str(noSeries+1)], 'NodeData', noSeries);
            %new_node.ContextMenu = app.ContextMenu_series;
        end

        % Button pushed function: pb_rmSeries
        function pb_rmSeries_cb(app, event)
            %find series to remove:
            selectedNodes = app.tree_dataSorted.SelectedNodes;
            if isempty(selectedNodes)
                return
            end
            serToDelIdx = zeros(numel(selectedNodes),1);
            for ii = 1:numel(selectedNodes)
                if selectedNodes(ii).Parent == app.tree_dataSorted
                    serToDelIdx(ii) = find(selectedNodes.Parent.Children == selectedNodes);
                %else
                %    serToDelIdx(ii) = find(selectedNodes.Parent.Children == selectedNodes.Parent);
                end
            end
            serToDelIdx = unique(serToDelIdx);
            serToDelIdx(serToDelIdx == 0) = [];

            selection = "No";
            for ii = serToDelIdx
                if isempty(app.tree_dataSorted.Children(ii).Children)
                    iToDel = [];
                else
                    iToDel = [app.tree_dataSorted.Children(ii).Children.NodeData];
                end
                if ~isempty(iToDel)
                    if ~strcmp(selection, "Yes to all")
                        if isscalar(serToDelIdx)
                            confOptions = ["Yes"; "No"];
                        else
                            confOptions = ["Yes"; "Yes to all"; "No"];
                        end
                        selection = uiconfirm(app.FDUIFigure,['The series "' app.tree_dataSorted.Children(ii).Text ...
                            '" still contains data. Do you really want to remove it?'],...
                            'Confirm series removal', 'Options',confOptions,'CancelOption', "No",...
                            "Icon","question");
                    end
                    if contains(selection, "Yes")
                        app.DataSorting(iToDel) = 0;
                    end
                    
                end
                %if image was loaded for this series
                if ~isempty(app.tree_dataSorted.Children(ii).NodeData)
                    %delete image window
                    if ~isempty(app.tree_dataSorted.Children(ii).NodeData.FigIdx)
                        delete(app.subapp.Image(app.tree_dataSorted.Children(ii).NodeData.FigIdx));
                        app.subapp.Image(app.tree_dataSorted.Children(ii).NodeData.FigIdx) = [];
                    end
                    %delete image data
                    if ~isempty(app.tree_dataSorted.Children(ii).NodeData.ImgDataIdx)
                        app.Images(app.tree_dataSorted.Children(ii).NodeData.ImgDataIdx) = [];
                    end
                end
                delete(app.tree_dataSorted.Children(ii));
                app.DataSorting(app.DataSorting > ii) = app.DataSorting(app.DataSorting > ii) - 1;
            end
            app.actualize_lists;
        end

        % Value changed function: DeflSensnmVEditField
        function DeflSensnmVEditFieldValueChanged(app, event)
            value = app.DeflSensnmVEditField.Value * 1e-9;
            %check if all data have DeflV set as raw data
            if all(strcmp('DeflV', {app.Data(app.iSelectedData).OrigChannel} ) )
                proceed_change = true;
            else
                %TODO: !! This is not possible if only F is loaded. Check first if Defl is set.
                answ = uiconfirm(app.FDUIFigure, sprintf(['Some (or all) of the selected curves do not contain the raw data channel DeflV (Deflection in V).\n'...
                            'For these curves, DeflV will now be calculated from Defl. in nm and afterwards set as raw data channel.\n'...
                            '(Hint: For curves containing DeflV, the new Defl.Sens. value will be used to recalculate Defl. in nm and/or Force.)']),...
                            'Raw data recalc',...
                            'Options', {'OK, Proceed', 'No, cancel!'},...
                            'DefaultOption', 1,...
                            'Icon', 'warning');
                if strcmp(answ, 'OK, Proceed')
                    proceed_change = true;
                else
                    proceed_change = false;
                end
            end
            
            if proceed_change
                for iS = app.iSelectedData
                    if strcmp(app.Data(iS).OrigChannel, 'DeflV')
                        app.Data(iS).DeflSens = value;
                    elseif strcmp(app.Data(iS).OrigChannel, 'var') 
                        %if ap and rt part have different raw data channels (How ever this should happen...)
                        OChannels = {app.Data(iS).ap.OrigChannel app.Data(iS).rt.OrigChannel};
                        
                    else
                        app.Data(iS).DeflSens = value;
                        app.Data(iS).OrigChannel = 'DeflV';
                    end
                end
            else
                %app.DeflSensnmVEditField.Value = event.PreviousValue;
            end
            app.actualize_objects;
            app.actualize_plot;
        end

        % Value changed function: SpringConstNmEditField
        function SpringConstNmEditFieldValueChanged(app, event)
            value = app.SpringConstNmEditField.Value;
            %check if all data have DeflV set as raw data
            if all(strcmp('DeflV', {app.Data(app.iSelectedData).OrigChannel} ) )
                proceed_change = true;
            else
                %TODO: insert stuff that happens when DeflV not set as raw data or not available.
                answ = uiconfirm(app.FDUIFigure, sprintf(['Some (or all) of the selected curves do not contain the raw data channel DeflV (Deflection in V).\n'...
                            'For these curves, Please choose which channel shall be recalculated.\n'...
                            '(Hint: For curves containing DeflV, the new Spr.Const. value will be used to recalculate F from Defl in nm.\n'...
                            'For curves without Defl in nm or F, this channel will be calculated.)']),...
                            'Change Spring Constant Warning',...
                            'Options', {'Recalc F (N)', 'Recalc Defl (nm)', 'Cancel'},...
                            'DefaultOption', 1,...
                            'Icon', 'warning');
               if strcmp(answ, 'Cancel')
                   proceed_change = false;
               else
                   proceed_change = true;
               end         
            end
            
            if proceed_change
                for iS = app.iSelectedData
                    if strcmp(app.Data(iS).OrigChannel, 'DeflV') || (islogical(app.Data(iS).SprConst) && ~app.Data(iS).SprConst) || isempty(app.Data(iS).SprConst)
                        %DeflV is set or SprConst is not set(i.e. Defl or F are missing)
                        app.Data(iS).SprConst = value;
                    elseif strcmp(answ, 'Recalc F (N)')
                        app.Data(iS).ap.F = app.Data(iS).ap.Defl * value;
                        app.Data(iS).rt.F = app.Data(iS).rt.Defl * value;
                    elseif strcmp(answ, 'Recalc Defl (nm)')
                        app.Data(iS).ap.Defl = app.Data(iS).ap.F / value;
                        app.Data(iS).rt.Defl = app.Data(iS).rt.F / value;
                    end
                end
            end
            app.actualize_objects;
            app.actualize_plot;
        end

        % Button pushed function: PB_setBaseline
        function PB_setBaselinePushed(app, event)
            if logical(app.TB_corrApp.Value)
                selTr = 'ap';                
                lineprop = '.b';
            else
                selTr = 'rt';
                lineprop = '.r';
            end

            data = app.Data(app.iSelectedData).(selTr);
            
            app.startSelectData('multi', data, 'Height', 'F',...
                'LineProp', lineprop,...
                'Title', "Select baseline data points", ...
                'xLabel', 'Height / m',...
                'yLabel', 'Force / N',...
                'selectID', 'Baseline');

        end

        % Value changed function: oscillationcorrectionSwitch
        function oscillationcorrectionSwitchValueChanged(app, event)
            value = app.oscillationcorrectionSwitch.Value;
            args_ap = struct();
            args_ap.CorrectOsc = strcmp(value, 'On');
            args_ap.BaselineThres = app.autoCorrectOptions.BaselineThres;
            args_rt = args_ap;

            if logical(app.fixendpointsCheckBox.Value)
                args_ap.BaselineIndex = app.Data(app.iSelectedData).ap.iBl;
                args_rt.BaselineIndex = app.Data(app.iSelectedData).rt.iBl;
            end

            if logical(app.fixCPCheckBox.Value)
                args_ap.ContactPointIndex = app.Data(app.iSelectedData).ap.iCP;
                args_rt.ContactPointIndex = app.Data(app.iSelectedData).rt.iCP;
            end


            if logical(app.TB_corrApp.Value) || logical(app.CB_ManCorChan.Value)
                app.Data(app.iSelectedData).ap = ...
                    app.Data(app.iSelectedData).ap.correct(args_ap);
            end

            if logical(app.TB_corrRet.Value) || logical(app.CB_ManCorChan.Value)
                app.Data(app.iSelectedData).rt = ...
                    app.Data(app.iSelectedData).rt.correct(args_rt);
            end

            if strcmp(app.AutoreviewoptionsMenu.Checked, 'on')
                app.Data(app.iSelectedData) = app.Data(app.iSelectedData).evaluate(app.propsToEval);
            end
            
            app.actualize_objects();
            app.actualize_plot();
        end

        % Value changed function: foundwavelengthnmEditField
        function foundwavelengthnmEditFieldValueChanged(app, event)
            value = app.foundwavelengthnmEditField.Value;
            if logical(app.TB_corrApp.Value)
                app.Data(app.iSelectedData).ap.OscLambda = value * 1e-9;
            else
                app.Data(app.iSelectedData).rt.OscLambda = value * 1e-9;
            end
            app.oscillationcorrectionSwitchValueChanged();
        end

        % Button pushed function: PB_setCP
        function PB_setCPButtonPushed(app, event)
            if logical(app.TB_corrApp.Value)  % 1 = correct approach, 0 = correct retract
                data = app.Data(app.iSelectedData).ap;
                lineprop = '.b';
            else
                data = app.Data(app.iSelectedData).rt;
                lineprop = '.r';
            end

            if logical(app.TB_corrApp.Value) % 1 = correct approach, 0 = correct retract
                selTr = 'ap';                
                lineprop = '.b';
            else
                selTr = 'rt';
                lineprop = '.r';
            end

            data = app.Data(app.iSelectedData).(selTr);

            app.startSelectData('single', data, ...
                'Height', 'Fc',...
                'LineProp', lineprop,...
                'Title', "Select contact point", ...
                'xLabel', 'Height / m',...
                'yLabel', 'corr. Force / N',...
                'selectID', 'CP');

        end

        % Value changed function: DropDown_xAxisData
        function DropDown_xAxisDataValueChanged(app, event)
            app.actualize_plot;
        end

        % Value changed function: DropDown_yAxisData
        function DropDown_yAxisDataValueChanged(app, event)
            app.actualize_plot;            
        end

        % Selection changed function: coloringButtonGroup
        function coloringButtonGroupSelectionChanged(app, event)
            %selectedButton = app.coloringButtonGroup.SelectedObject;
            app.actualize_plot;    
        end

        % Value changed function: DropDown_colormap
        function DropDown_colormapValueChanged(app, event)
            %value = app.DropDown_colormap.Value;
            app.actualize_plot;    
        end

        % Button pushed function: DeflvsHeightButton
        function DeflvsHeightButtonPushed(app, event)
            app.DropDown_xAxisData.Value = 'Height';
            if any(strcmp(app.DropDown_xAxisData.ItemsData, 'DeflV'))
                app.DropDown_yAxisData.Value = 'DeflV';
            elseif any(strcmp(app.DropDown_xAxisData.ItemsData, 'Defl'))
                app.DropDown_yAxisData.Value = 'DeflV';
            else
                app.DropDown_yAxisData.Value = 'F';
            end
            app.actualize_plot();
        end

        % Button pushed function: FvsSepButton
        function FvsSepButtonPushed(app, event)
            app.DropDown_xAxisData.Value = 'Sep';
            app.DropDown_yAxisData.Value = 'Fc';
            app.actualize_plot();
        end

        % Selection changed function: BG_corrChannel
        function BG_corrChannelSelectionChanged(app, event)
            selectedButton = app.BG_corrChannel.SelectedObject;
            app.actualize_objects();
        end

        % Value changed function: BaselineCheckBox, CB_showBaseline, 
        % ...and 5 other components
        function plotControlCheckBoxValueChanged(app, event)
            app.actualize_plot();            
        end

        % Button pushed function: SelDataOKButton
        function SelDataOKButtonPushed(app, event)
            switch app.SelDataOKButton.UserData{1}
                case 'Baseline'
                    if sum(logical(app.axes1.Children.BrushData)) == 0
                        answer = uiconfirm(app.FDUIFigure, "No data selected. Are you sure?", "Confirm abort",...
                            "Options", {'Yes', 'No'});
                        if strcmp(answer, 'No')
                            return;
                        end
                    end
                    
                    app.setNewBaselineFromBrush();
                    brush(app.FDUIFigure, 'off');
                    
                case 'CP'
                    app.setNewCPfromCursor();

                    app.subapp.dcm.Enable = 'off';
                    app.subapp.dcm = [];  
                case 'modelFit'
                    if sum(logical(app.axes1.Children.BrushData)) == 0
                        answer = uiconfirm(app.FDUIFigure, "No data selected. Are you sure?", "Confirm abort",...
                            "Options", {'Yes', 'No'});
                        if strcmp(answer, 'No')
                            return;
                        end
                    end
                    
                    brushDataIdx = logical(app.axes1.Children.BrushData);
                    app.subapp.Fitmodels.RunningAppInstance.dataPointsSelection = brushDataIdx;
                    brush(app.FDUIFigure, 'off');
            end
            app.actualize_plot();
            
            app.axes1.Toolbar.Visible = "on";
            app.SelDataOKButton.Visible = "off";
            app.SelDataOKButton.Enable = "off";
            app.axes1.Title.String = "";

            %enable all other figure parts again
            app.MenuFile.Enable = "on";
            app.OptionsMenu.Enable = "on";
            app.ToolsMenu.Enable = "on";
            app.PlotcontrolPanel.Enable = "on";
            app.ManualCorrPanel.Enable = "on";
            app.CalibrationcorrectionPanel.Enable = "on";
            app.lb_allData.Enable = "on";
            app.tree_dataSorted.Enable = "on";
            app.pb_rmSeries.Enable = "on";
            app.pb_addSeries.Enable = "on";
            app.pb_remData.Enable = "on";
            app.pb_addData.Enable = "on";

            app.SelDataOKButton.UserData = [];
        end

        % Button pushed function: MakeSepPlotWindowButton
        function MakeSepPlotWindowButtonPushed(app, event)
            if isfield(app.subapp, 'extAxisWindow') && ~isempty(app.subapp.extAxisWindow)
            else
                app.subapp.extAxisWindow = uifigure();
                app.subapp.extAxisWindow.UserData = app.axes1.Position;
                app.axes1.Parent = app.subapp.extAxisWindow;
                app.axes1.Position = [1 1 app.subapp.extAxisWindow.Position(3:4)];
                app.subapp.extAxisWindow.CloseRequestFcn = @(src,ev)app.delExtAxisWindow();
                app.MakeSepPlotWindowButton.Enable = 'off';
            end

        end

        % Callback function: ExitMenu, FDUIFigure
        function FDUIFigureCloseRequest(app, event)
            answ = 'OK';
            if app.FDUIFigure.Name(end) == '*'
                answ = uiconfirm(app.FDUIFigure, 'Your last changes have not been saved. Do you really want to close the app?',...
                    'Confirm close',"Icon","warning");
            elseif strcmp(app.FDUIFigure.Name, 'FD') && ~isempty(app.Data)
                answ = uiconfirm(app.FDUIFigure, 'This session has not been saved. Do you really want to close the app?',...
                    'Confirm close',"Icon","warning");
            end
            if strcmp(answ, 'Cancel')
                return
            end
            
            if ~isempty(app.subapp)
                try
                    app.closeAllSubWindows();
                catch
                end
            end
            delete(app)            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create FDUIFigure and hide until all components are created
            app.FDUIFigure = uifigure('Visible', 'off');
            app.FDUIFigure.Position = [100 100 860 571];
            app.FDUIFigure.Name = 'FD';
            app.FDUIFigure.CloseRequestFcn = createCallbackFcn(app, @FDUIFigureCloseRequest, true);

            % Create MenuFile
            app.MenuFile = uimenu(app.FDUIFigure);
            app.MenuFile.MenuSelectedFcn = createCallbackFcn(app, @MenuFileSelected, true);
            app.MenuFile.Text = 'File';

            % Create AddDataMenu
            app.AddDataMenu = uimenu(app.MenuFile);
            app.AddDataMenu.MenuSelectedFcn = createCallbackFcn(app, @MenuAddData, true);
            app.AddDataMenu.Text = 'Add data';
            app.AddDataMenu.Interruptible = 'off';

            % Create AddfolderMenu
            app.AddfolderMenu = uimenu(app.MenuFile);
            app.AddfolderMenu.MenuSelectedFcn = createCallbackFcn(app, @AddfolderMenuSelected, true);
            app.AddfolderMenu.Text = 'Add folder';

            % Create ExportDataMenu
            app.ExportDataMenu = uimenu(app.MenuFile);
            app.ExportDataMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportDataMenuSelected, true);
            app.ExportDataMenu.Text = 'Export data';

            % Create ClosedataMenu
            app.ClosedataMenu = uimenu(app.MenuFile);
            app.ClosedataMenu.MenuSelectedFcn = createCallbackFcn(app, @ClosedataMenuSelected, true);
            app.ClosedataMenu.Text = 'Close data';

            % Create OpenMenu
            app.OpenMenu = uimenu(app.MenuFile);
            app.OpenMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenMenuSelected, true);
            app.OpenMenu.Separator = 'on';
            app.OpenMenu.Text = 'Open';

            % Create SaveMenu
            app.SaveMenu = uimenu(app.MenuFile);
            app.SaveMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveMenuSelected, true);
            app.SaveMenu.Accelerator = 's';
            app.SaveMenu.Text = 'Save';

            % Create SaveasMenu
            app.SaveasMenu = uimenu(app.MenuFile);
            app.SaveasMenu.MenuSelectedFcn = createCallbackFcn(app, @SaveMenuSelected, true);
            app.SaveasMenu.Text = 'Save as...';

            % Create ClosesessionMenu
            app.ClosesessionMenu = uimenu(app.MenuFile);
            app.ClosesessionMenu.MenuSelectedFcn = createCallbackFcn(app, @ClosesessionMenuSelected, true);
            app.ClosesessionMenu.Text = 'Close session';

            % Create ExitMenu
            app.ExitMenu = uimenu(app.MenuFile);
            app.ExitMenu.MenuSelectedFcn = createCallbackFcn(app, @FDUIFigureCloseRequest, true);
            app.ExitMenu.Separator = 'on';
            app.ExitMenu.Text = 'Exit';

            % Create OptionsMenu
            app.OptionsMenu = uimenu(app.FDUIFigure);
            app.OptionsMenu.Text = 'Options';

            % Create AutocorrectoptionsMenu
            app.AutocorrectoptionsMenu = uimenu(app.OptionsMenu);
            app.AutocorrectoptionsMenu.MenuSelectedFcn = createCallbackFcn(app, @AutocorrectoptionsMenuSelected, true);
            app.AutocorrectoptionsMenu.Separator = 'on';
            app.AutocorrectoptionsMenu.Text = 'Auto correct options';

            % Create AutocorrectondataimportMenu
            app.AutocorrectondataimportMenu = uimenu(app.OptionsMenu);
            app.AutocorrectondataimportMenu.MenuSelectedFcn = createCallbackFcn(app, @AutocorrectondataimportMenuSelected, true);
            app.AutocorrectondataimportMenu.Separator = 'on';
            app.AutocorrectondataimportMenu.Checked = 'on';
            app.AutocorrectondataimportMenu.Text = 'Auto correct on data import';

            % Create StartautocorrectalldataMenu
            app.StartautocorrectalldataMenu = uimenu(app.OptionsMenu);
            app.StartautocorrectalldataMenu.MenuSelectedFcn = createCallbackFcn(app, @StartautocorrectalldataMenuSelected, true);
            app.StartautocorrectalldataMenu.Text = 'Start auto correct all data';

            % Create StartautocorrectselecteddataMenu
            app.StartautocorrectselecteddataMenu = uimenu(app.OptionsMenu);
            app.StartautocorrectselecteddataMenu.MenuSelectedFcn = createCallbackFcn(app, @StartautocorrectselecteddataMenuSelected, true);
            app.StartautocorrectselecteddataMenu.Text = 'Start auto correct selected data';

            % Create StartautoreviewMenu
            app.StartautoreviewMenu = uimenu(app.OptionsMenu);
            app.StartautoreviewMenu.Visible = 'off';
            app.StartautoreviewMenu.Enable = 'off';
            app.StartautoreviewMenu.Separator = 'on';
            app.StartautoreviewMenu.Text = 'Start auto review';

            % Create AutoreviewoptionsMenu
            app.AutoreviewoptionsMenu = uimenu(app.OptionsMenu);
            app.AutoreviewoptionsMenu.Visible = 'off';
            app.AutoreviewoptionsMenu.Enable = 'off';
            app.AutoreviewoptionsMenu.Text = 'Auto review options';

            % Create AutoevaluateMenu
            app.AutoevaluateMenu = uimenu(app.OptionsMenu);
            app.AutoevaluateMenu.MenuSelectedFcn = createCallbackFcn(app, @AutoevaluateMenuSelected, true);
            app.AutoevaluateMenu.Separator = 'on';
            app.AutoevaluateMenu.Checked = 'on';
            app.AutoevaluateMenu.Text = 'Auto evaluate';

            % Create EvaluateselectedcurvesMenu
            app.EvaluateselectedcurvesMenu = uimenu(app.OptionsMenu);
            app.EvaluateselectedcurvesMenu.MenuSelectedFcn = createCallbackFcn(app, @EvaluateselectedcurvesMenuSelected, true);
            app.EvaluateselectedcurvesMenu.Text = 'Evaluate selected curves';

            % Create SelectevaluationpropertiesMenu
            app.SelectevaluationpropertiesMenu = uimenu(app.OptionsMenu);
            app.SelectevaluationpropertiesMenu.MenuSelectedFcn = createCallbackFcn(app, @SelectevaluationpropertiesMenuSelected, true);
            app.SelectevaluationpropertiesMenu.Enable = 'off';
            app.SelectevaluationpropertiesMenu.Text = 'Select evaluation properties';

            % Create InspectevaluatedvaluesMenu
            app.InspectevaluatedvaluesMenu = uimenu(app.OptionsMenu);
            app.InspectevaluatedvaluesMenu.MenuSelectedFcn = createCallbackFcn(app, @InspectevaluatedvaluesMenuSelected, true);
            app.InspectevaluatedvaluesMenu.Text = 'Inspect evaluated values';

            % Create ExportevaluatedvaluesMenu
            app.ExportevaluatedvaluesMenu = uimenu(app.OptionsMenu);
            app.ExportevaluatedvaluesMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportevaluatedvaluesMenuSelected, true);
            app.ExportevaluatedvaluesMenu.Text = 'Export evaluated values';

            % Create ToolsMenu
            app.ToolsMenu = uimenu(app.FDUIFigure);
            app.ToolsMenu.Text = 'Tools';

            % Create FilmIndentationMenu
            app.FilmIndentationMenu = uimenu(app.ToolsMenu);
            app.FilmIndentationMenu.MenuSelectedFcn = createCallbackFcn(app, @FilmIndentationMenuSelected, true);
            app.FilmIndentationMenu.Text = 'Film Indentation';

            % Create PeakFinderMenu
            app.PeakFinderMenu = uimenu(app.ToolsMenu);
            app.PeakFinderMenu.MenuSelectedFcn = createCallbackFcn(app, @PeakFinderMenuSelected, true);
            app.PeakFinderMenu.Visible = 'off';
            app.PeakFinderMenu.Enable = 'off';
            app.PeakFinderMenu.Text = 'PeakFinder';

            % Create DatafittingMenu
            app.DatafittingMenu = uimenu(app.ToolsMenu);
            app.DatafittingMenu.MenuSelectedFcn = createCallbackFcn(app, @DatafittingMenuSelected, true);
            app.DatafittingMenu.Separator = 'on';
            app.DatafittingMenu.Text = 'Data fitting';

            % Create ExportfitsMenu
            app.ExportfitsMenu = uimenu(app.ToolsMenu);
            app.ExportfitsMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportfitsMenuSelected, true);
            app.ExportfitsMenu.Text = 'Export fits';

            % Create axes1
            app.axes1 = uiaxes(app.FDUIFigure);
            title(app.axes1, 'Title')
            xlabel(app.axes1, 'X')
            ylabel(app.axes1, 'Y')
            app.axes1.PlotBoxAspectRatio = [1.47777777777778 1 1];
            app.axes1.XTickLabelRotation = 0;
            app.axes1.YTickLabelRotation = 0;
            app.axes1.ZTickLabelRotation = 0;
            app.axes1.Position = [413 218 448 326];

            % Create tree_dataSorted
            app.tree_dataSorted = uitree(app.FDUIFigure);
            app.tree_dataSorted.Multiselect = 'on';
            app.tree_dataSorted.SelectionChangedFcn = createCallbackFcn(app, @tree_selCh_cb, true);
            app.tree_dataSorted.Editable = 'on';
            app.tree_dataSorted.Position = [244 289 150 241];

            % Create Series1
            app.Series1 = uitreenode(app.tree_dataSorted);
            app.Series1.Text = 'Series1';

            % Create LoadeddataLabel
            app.LoadeddataLabel = uilabel(app.FDUIFigure);
            app.LoadeddataLabel.HorizontalAlignment = 'right';
            app.LoadeddataLabel.Position = [18 540 73 22];
            app.LoadeddataLabel.Text = 'Loaded data';

            % Create lb_allData
            app.lb_allData = uilistbox(app.FDUIFigure);
            app.lb_allData.Items = {};
            app.lb_allData.Multiselect = 'on';
            app.lb_allData.Position = [17 289 163 241];
            app.lb_allData.Value = {};

            % Create pb_addData
            app.pb_addData = uibutton(app.FDUIFigure, 'push');
            app.pb_addData.ButtonPushedFcn = createCallbackFcn(app, @pb_addData_cb, true);
            app.pb_addData.Position = [189 405 36 22];
            app.pb_addData.Text = '→';

            % Create pb_remData
            app.pb_remData = uibutton(app.FDUIFigure, 'push');
            app.pb_remData.ButtonPushedFcn = createCallbackFcn(app, @pb_rmData_cb, true);
            app.pb_remData.Position = [189 374 36 22];
            app.pb_remData.Text = '←';

            % Create pb_addSeries
            app.pb_addSeries = uibutton(app.FDUIFigure, 'push');
            app.pb_addSeries.ButtonPushedFcn = createCallbackFcn(app, @pb_addSeries_cb, true);
            app.pb_addSeries.Position = [243 247 64 22];
            app.pb_addSeries.Text = 'Add series';

            % Create pb_rmSeries
            app.pb_rmSeries = uibutton(app.FDUIFigure, 'push');
            app.pb_rmSeries.ButtonPushedFcn = createCallbackFcn(app, @pb_rmSeries_cb, true);
            app.pb_rmSeries.Position = [313.5 247 95 22];
            app.pb_rmSeries.Text = 'Remove series';

            % Create ManualCorrPanel
            app.ManualCorrPanel = uipanel(app.FDUIFigure);
            app.ManualCorrPanel.Title = 'Manual corrections';
            app.ManualCorrPanel.Position = [16 10 418 154];

            % Create PB_setCP
            app.PB_setCP = uibutton(app.ManualCorrPanel, 'push');
            app.PB_setCP.ButtonPushedFcn = createCallbackFcn(app, @PB_setCPButtonPushed, true);
            app.PB_setCP.Position = [111 4 74 22];
            app.PB_setCP.Text = 'Set CP';

            % Create PB_setBaseline
            app.PB_setBaseline = uibutton(app.ManualCorrPanel, 'push');
            app.PB_setBaseline.ButtonPushedFcn = createCallbackFcn(app, @PB_setBaselinePushed, true);
            app.PB_setBaseline.Tooltip = {'Set new boundaries and recalculate baseline'};
            app.PB_setBaseline.Position = [111 66 74 22];
            app.PB_setBaseline.Text = 'Select';

            % Create BG_corrChannel
            app.BG_corrChannel = uibuttongroup(app.ManualCorrPanel);
            app.BG_corrChannel.SelectionChangedFcn = createCallbackFcn(app, @BG_corrChannelSelectionChanged, true);
            app.BG_corrChannel.Position = [110 102 170 30];

            % Create TB_corrApp
            app.TB_corrApp = uitogglebutton(app.BG_corrChannel);
            app.TB_corrApp.Text = 'approach';
            app.TB_corrApp.Position = [13 4 67 22];
            app.TB_corrApp.Value = true;

            % Create TB_corrRet
            app.TB_corrRet = uitogglebutton(app.BG_corrChannel);
            app.TB_corrRet.Text = 'retract';
            app.TB_corrRet.Position = [91 4 67 22];

            % Create CB_ManCorChan
            app.CB_ManCorChan = uicheckbox(app.ManualCorrPanel);
            app.CB_ManCorChan.Text = 'use for both';
            app.CB_ManCorChan.Position = [293 106 94 22];

            % Create ChoosedirectionLabel
            app.ChoosedirectionLabel = uilabel(app.ManualCorrPanel);
            app.ChoosedirectionLabel.FontWeight = 'bold';
            app.ChoosedirectionLabel.Position = [4 106 107 22];
            app.ChoosedirectionLabel.Text = 'Choose direction:';

            % Create oscillationcorrectionSwitchLabel
            app.oscillationcorrectionSwitchLabel = uilabel(app.ManualCorrPanel);
            app.oscillationcorrectionSwitchLabel.HorizontalAlignment = 'center';
            app.oscillationcorrectionSwitchLabel.Position = [27 39 117 22];
            app.oscillationcorrectionSwitchLabel.Text = 'oscillation correction';

            % Create oscillationcorrectionSwitch
            app.oscillationcorrectionSwitch = uiswitch(app.ManualCorrPanel, 'slider');
            app.oscillationcorrectionSwitch.ValueChangedFcn = createCallbackFcn(app, @oscillationcorrectionSwitchValueChanged, true);
            app.oscillationcorrectionSwitch.Position = [174 42 34 15];

            % Create foundwavelengthnmEditFieldLabel
            app.foundwavelengthnmEditFieldLabel = uilabel(app.ManualCorrPanel);
            app.foundwavelengthnmEditFieldLabel.HorizontalAlignment = 'right';
            app.foundwavelengthnmEditFieldLabel.Position = [240 39 128 22];
            app.foundwavelengthnmEditFieldLabel.Text = 'found wavelength / nm';

            % Create foundwavelengthnmEditField
            app.foundwavelengthnmEditField = uieditfield(app.ManualCorrPanel, 'numeric');
            app.foundwavelengthnmEditField.ValueChangedFcn = createCallbackFcn(app, @foundwavelengthnmEditFieldValueChanged, true);
            app.foundwavelengthnmEditField.Editable = 'off';
            app.foundwavelengthnmEditField.Position = [373 39 42 22];

            % Create fixendpointsCheckBox
            app.fixendpointsCheckBox = uicheckbox(app.ManualCorrPanel);
            app.fixendpointsCheckBox.Text = 'fix end points';
            app.fixendpointsCheckBox.Position = [199 66 94 22];

            % Create fixCPCheckBox
            app.fixCPCheckBox = uicheckbox(app.ManualCorrPanel);
            app.fixCPCheckBox.Text = 'fix CP';
            app.fixCPCheckBox.Position = [200 3 54 22];

            % Create ContactpointLabel
            app.ContactpointLabel = uilabel(app.ManualCorrPanel);
            app.ContactpointLabel.FontWeight = 'bold';
            app.ContactpointLabel.Position = [6 4 87 22];
            app.ContactpointLabel.Text = 'Contact point:';

            % Create BaselineLabel
            app.BaselineLabel = uilabel(app.ManualCorrPanel);
            app.BaselineLabel.FontWeight = 'bold';
            app.BaselineLabel.Position = [5 66 58 22];
            app.BaselineLabel.Text = 'Baseline:';

            % Create CalibrationcorrectionPanel
            app.CalibrationcorrectionPanel = uipanel(app.FDUIFigure);
            app.CalibrationcorrectionPanel.Title = 'Calibration correction';
            app.CalibrationcorrectionPanel.Position = [17 176 418 60];

            % Create DeflSensnmVEditFieldLabel
            app.DeflSensnmVEditFieldLabel = uilabel(app.CalibrationcorrectionPanel);
            app.DeflSensnmVEditFieldLabel.HorizontalAlignment = 'right';
            app.DeflSensnmVEditFieldLabel.Position = [9 8 101 22];
            app.DeflSensnmVEditFieldLabel.Text = 'Defl. Sens. (nm/V)';

            % Create DeflSensnmVEditField
            app.DeflSensnmVEditField = uieditfield(app.CalibrationcorrectionPanel, 'numeric');
            app.DeflSensnmVEditField.Limits = [0 Inf];
            app.DeflSensnmVEditField.ValueChangedFcn = createCallbackFcn(app, @DeflSensnmVEditFieldValueChanged, true);
            app.DeflSensnmVEditField.Position = [125 8 65 22];

            % Create SpringConstNmEditFieldLabel
            app.SpringConstNmEditFieldLabel = uilabel(app.CalibrationcorrectionPanel);
            app.SpringConstNmEditFieldLabel.HorizontalAlignment = 'right';
            app.SpringConstNmEditFieldLabel.Position = [224 7 112 22];
            app.SpringConstNmEditFieldLabel.Text = 'Spring Const. (N/m)';

            % Create SpringConstNmEditField
            app.SpringConstNmEditField = uieditfield(app.CalibrationcorrectionPanel, 'numeric');
            app.SpringConstNmEditField.Limits = [0 Inf];
            app.SpringConstNmEditField.ValueDisplayFormat = '%.3f';
            app.SpringConstNmEditField.ValueChangedFcn = createCallbackFcn(app, @SpringConstNmEditFieldValueChanged, true);
            app.SpringConstNmEditField.Position = [343 7 67 22];

            % Create PlotcontrolPanel
            app.PlotcontrolPanel = uipanel(app.FDUIFigure);
            app.PlotcontrolPanel.Title = 'Plot control';
            app.PlotcontrolPanel.Position = [451 10 400 195];

            % Create XaxisLabel
            app.XaxisLabel = uilabel(app.PlotcontrolPanel);
            app.XaxisLabel.HorizontalAlignment = 'right';
            app.XaxisLabel.Position = [8 116 41 22];
            app.XaxisLabel.Text = 'X axis:';

            % Create DropDown_xAxisData
            app.DropDown_xAxisData = uidropdown(app.PlotcontrolPanel);
            app.DropDown_xAxisData.Items = {'---'};
            app.DropDown_xAxisData.ValueChangedFcn = createCallbackFcn(app, @DropDown_xAxisDataValueChanged, true);
            app.DropDown_xAxisData.Position = [64 116 100 22];
            app.DropDown_xAxisData.Value = '---';

            % Create YaxisLabel
            app.YaxisLabel = uilabel(app.PlotcontrolPanel);
            app.YaxisLabel.HorizontalAlignment = 'right';
            app.YaxisLabel.Position = [8 87 41 22];
            app.YaxisLabel.Text = 'Y axis:';

            % Create DropDown_yAxisData
            app.DropDown_yAxisData = uidropdown(app.PlotcontrolPanel);
            app.DropDown_yAxisData.Items = {'---'};
            app.DropDown_yAxisData.ValueChangedFcn = createCallbackFcn(app, @DropDown_yAxisDataValueChanged, true);
            app.DropDown_yAxisData.Position = [64 87 100 22];
            app.DropDown_yAxisData.Value = '---';

            % Create cb_autoplotsel
            app.cb_autoplotsel = uicheckbox(app.PlotcontrolPanel);
            app.cb_autoplotsel.Enable = 'off';
            app.cb_autoplotsel.Visible = 'off';
            app.cb_autoplotsel.Text = 'auto plot selected curves';
            app.cb_autoplotsel.Position = [208 152 157 22];
            app.cb_autoplotsel.Value = true;

            % Create CB_showBaseline
            app.CB_showBaseline = uicheckbox(app.PlotcontrolPanel);
            app.CB_showBaseline.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.CB_showBaseline.Text = 'Baseline limits';
            app.CB_showBaseline.Position = [190 110 99 22];

            % Create CB_showCP
            app.CB_showCP = uicheckbox(app.PlotcontrolPanel);
            app.CB_showCP.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.CB_showCP.Text = 'Contact point';
            app.CB_showCP.Position = [288 110 95 22];

            % Create EvaluatedpropsCheckBox
            app.EvaluatedpropsCheckBox = uicheckbox(app.PlotcontrolPanel);
            app.EvaluatedpropsCheckBox.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.EvaluatedpropsCheckBox.Text = 'Evaluated props.';
            app.EvaluatedpropsCheckBox.Position = [288 131 112 22];

            % Create BaselineCheckBox
            app.BaselineCheckBox = uicheckbox(app.PlotcontrolPanel);
            app.BaselineCheckBox.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.BaselineCheckBox.Text = 'Baseline';
            app.BaselineCheckBox.Position = [190 131 68 22];

            % Create AxesquickselectLabel
            app.AxesquickselectLabel = uilabel(app.PlotcontrolPanel);
            app.AxesquickselectLabel.Position = [8 56 103 22];
            app.AxesquickselectLabel.Text = 'Axes quick select:';

            % Create DeflvsHeightButton
            app.DeflvsHeightButton = uibutton(app.PlotcontrolPanel, 'push');
            app.DeflvsHeightButton.ButtonPushedFcn = createCallbackFcn(app, @DeflvsHeightButtonPushed, true);
            app.DeflvsHeightButton.Position = [80 31 97 22];
            app.DeflvsHeightButton.Text = 'Defl. vs. Height';

            % Create FvsSepButton
            app.FvsSepButton = uibutton(app.PlotcontrolPanel, 'push');
            app.FvsSepButton.ButtonPushedFcn = createCallbackFcn(app, @FvsSepButtonPushed, true);
            app.FvsSepButton.Position = [80 4 97 22];
            app.FvsSepButton.Text = 'F_corr vs. Sep.';

            % Create uncorrectedLabel
            app.uncorrectedLabel = uilabel(app.PlotcontrolPanel);
            app.uncorrectedLabel.Position = [7 31 74 22];
            app.uncorrectedLabel.Text = 'uncorrected:';

            % Create correctedLabel
            app.correctedLabel = uilabel(app.PlotcontrolPanel);
            app.correctedLabel.Position = [7 3 60 22];
            app.correctedLabel.Text = 'corrected:';

            % Create approachCheckBox
            app.approachCheckBox = uicheckbox(app.PlotcontrolPanel);
            app.approachCheckBox.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.approachCheckBox.Text = 'approach';
            app.approachCheckBox.Position = [7 145 73 22];
            app.approachCheckBox.Value = true;

            % Create retractCheckBox
            app.retractCheckBox = uicheckbox(app.PlotcontrolPanel);
            app.retractCheckBox.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.retractCheckBox.Text = 'retract';
            app.retractCheckBox.Position = [90 145 57 22];
            app.retractCheckBox.Value = true;

            % Create AdditionalmarkingsLabel
            app.AdditionalmarkingsLabel = uilabel(app.PlotcontrolPanel);
            app.AdditionalmarkingsLabel.Position = [231 153 112 22];
            app.AdditionalmarkingsLabel.Text = 'Additional markings';

            % Create LegendCheckBox
            app.LegendCheckBox = uicheckbox(app.PlotcontrolPanel);
            app.LegendCheckBox.ValueChangedFcn = createCallbackFcn(app, @plotControlCheckBoxValueChanged, true);
            app.LegendCheckBox.Text = 'Legend';
            app.LegendCheckBox.Position = [190 66 62 22];

            % Create coloringButtonGroup
            app.coloringButtonGroup = uibuttongroup(app.PlotcontrolPanel);
            app.coloringButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @coloringButtonGroupSelectionChanged, true);
            app.coloringButtonGroup.Title = 'coloring';
            app.coloringButtonGroup.Position = [274 3 123 106];

            % Create normalblueredButton
            app.normalblueredButton = uiradiobutton(app.coloringButtonGroup);
            app.normalblueredButton.Text = 'normal (blue-red)';
            app.normalblueredButton.Position = [11 60 113 22];
            app.normalblueredButton.Value = true;

            % Create seriescolormapButton
            app.seriescolormapButton = uiradiobutton(app.coloringButtonGroup);
            app.seriescolormapButton.Text = 'series colormap';
            app.seriescolormapButton.Position = [11 38 108 22];

            % Create DropDown_colormap
            app.DropDown_colormap = uidropdown(app.coloringButtonGroup);
            app.DropDown_colormap.ValueChangedFcn = createCallbackFcn(app, @DropDown_colormapValueChanged, true);
            app.DropDown_colormap.Position = [17 9 101 22];

            % Create SelDataOKButton
            app.SelDataOKButton = uibutton(app.FDUIFigure, 'push');
            app.SelDataOKButton.ButtonPushedFcn = createCallbackFcn(app, @SelDataOKButtonPushed, true);
            app.SelDataOKButton.Enable = 'off';
            app.SelDataOKButton.Visible = 'off';
            app.SelDataOKButton.Position = [413 547 100 22];
            app.SelDataOKButton.Text = 'Confirm';

            % Create MakeSepPlotWindowButton
            app.MakeSepPlotWindowButton = uibutton(app.FDUIFigure, 'push');
            app.MakeSepPlotWindowButton.ButtonPushedFcn = createCallbackFcn(app, @MakeSepPlotWindowButtonPushed, true);
            app.MakeSepPlotWindowButton.Icon = fullfile(pathToMLAPP, 'icons', 'share-from-square-regular.svg');
            app.MakeSepPlotWindowButton.Position = [823 210 28 22];
            app.MakeSepPlotWindowButton.Text = '';

            % Show the figure after all components are created
            app.FDUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FD_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.FDUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.FDUIFigure)
        end
    end
end