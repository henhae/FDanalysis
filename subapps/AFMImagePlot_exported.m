classdef AFMImagePlot_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        FileMenu                 matlab.ui.container.Menu
        OpenMenu                 matlab.ui.container.Menu
        QuitMenu                 matlab.ui.container.Menu
        ExtraMenu                matlab.ui.container.Menu
        TipReconMenu             matlab.ui.container.Menu
        AddmodificationsPanel    matlab.ui.container.Panel
        MaskPanel                matlab.ui.container.Panel
        ThresMaxEditField        matlab.ui.control.NumericEditField
        ThresIntSlider           matlab.ui.control.RangeSlider
        bychannelDropDown        matlab.ui.control.DropDown
        bychannelDropDownLabel   matlab.ui.control.Label
        ThresSwitch              matlab.ui.control.Switch
        ThresEditField           matlab.ui.control.NumericEditField
        ThresSlider              matlab.ui.control.Slider
        maskbylineCheckBox       matlab.ui.control.CheckBox
        MaskDropDown             matlab.ui.control.DropDown
        usemaskingCheckBox       matlab.ui.control.CheckBox
        AddButton                matlab.ui.control.Button
        TabGroup                 matlab.ui.container.TabGroup
        planefitTab              matlab.ui.container.Tab
        ydirorderEditField       matlab.ui.control.NumericEditField
        ydirorderEditFieldLabel  matlab.ui.control.Label
        xdirorderEditField       matlab.ui.control.NumericEditField
        xdirorderEditFieldLabel  matlab.ui.control.Label
        flattenTab               matlab.ui.container.Tab
        orderEditField           matlab.ui.control.NumericEditField
        orderEditFieldLabel      matlab.ui.control.Label
        filterTab                matlab.ui.container.Tab
        sigmaEditField           matlab.ui.control.NumericEditField
        sigmaEditFieldLabel      matlab.ui.control.Label
        sizeEditField            matlab.ui.control.NumericEditField
        sizenxnEditFieldLabel    matlab.ui.control.Label
        FilterTypeDropDown       matlab.ui.control.DropDown
        TypeDropDownLabel        matlab.ui.control.Label
        ModifcationhistoryPanel  matlab.ui.container.Panel
        RemoveButton             matlab.ui.control.Button
        UITable_exMods           matlab.ui.control.Table
        ModificationsListBox     matlab.ui.control.ListBox
        Panel                    matlab.ui.container.Panel
        ShowmaskCheckBox         matlab.ui.control.CheckBox
        LockaxesSwitch           matlab.ui.control.Switch
        LockaxesSwitchLabel      matlab.ui.control.Label
        ChannelsListBox          matlab.ui.control.ListBox
        ChannelsListBoxLabel     matlab.ui.control.Label
        colormapDropDown         matlab.ui.control.DropDown
        colormapDropDownLabel    matlab.ui.control.Label
        Button                   matlab.ui.control.StateButton
        UIAxes                   matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        CallingApp
        CallingAppPropName              %property of calling app where images are stored
        CallingAppDataIdx               %index of image to plot
        CallingFigure
        ImageChanged    = false
        ImagePlotHandle
        file            char
        path            char = pwd;
    end

    properties (Access = public)
        Img AFMImage % Description
        AddData struct
    end
    
    methods (Access = public)
        
        function actualize_plot(app)
            im_no = app.ChannelsListBox.Value;
            ah = app.UIAxes;
            xLims = ah.XLim;
            yLims = ah.YLim;
            app.ImagePlotHandle = app.Img.plot(ah, im_no);

            colormap(ah, app.colormapDropDown.Value);
            ah.NextPlot = "add";

            if app.ShowmaskCheckBox.Value && app.usemaskingCheckBox.Value
                options = app.get_mask_options();
                options_cell = namedargs2cell(options);
                mask = AFMImageChannel.get_mask(app.Img.Channel(app.bychannelDropDown.Value).ImageDataMod, options_cell{:});
                %maskImg = ones(size(mask));
                colr = [1 0 0; 0 1 0; 0 0 1];
                mh = copyobj(app.ImagePlotHandle, app.UIAxes);
                mh.CData = ind2rgb(ones(size(mask)),colr);
                %mh = image(ah, ind2rgb(maskImg,colr));
                mh.AlphaData = mask*0.5;
            end
            ah.NextPlot = "replace";
            if app.LockaxesSwitch.Value == "On"
                ah.XLim = xLims;
                ah.YLim = yLims;
            end
            app.actualize_addData();

            % im = app.Img.Channel(im_no).ImageDataMod;
            % z_min = min(im, [], "all");
            % z_max = max(im, [], "all");
            % app.ThresSlider.Limits = [z_min z_max];
            % app.ThresEditField.Limits = app.ThresSlider.Limits;
            % if app.ThresSlider.Value < z_min || app.ThresSlider.Value > z_max
            %     app.ThresSlider.Value = (z_min+z_max)/2;
            %     app.ThresEditField.Value = app.ThresSlider.Value;
            % end
           
            
        end

        function actualize_addData(app)

            if ~isempty(app.AddData)
                app.UIAxes.NextPlot = "add";
                ImCenter = [app.Img.params.Position.X, app.Img.params.Position.Y];

                switch app.AddData.type
                    case 'scatter'
                        scatterplots = findobj(app.UIAxes.Children, "Type", "scatter");
                        delete(scatterplots);
                        %determine prefix of plot (x-axis) -> copied from AFMImage class
                        [xsize, ~] = AFMImage.num2si_w_p(app.Img.params.XSize);
                        scalefac = xsize / app.Img.params.XSize;

                        scatter(app.UIAxes, (ImCenter(1) - app.AddData.data.x + 0.5*app.Img.params.XSize)*scalefac, ...
                     (-app.AddData.data.y + ImCenter(2) + 0.5*app.Img.params.YSize)*scalefac,...
                     app.AddData.PlotOptions{:});
                end

                app.UIAxes.NextPlot = "replace";
            end
        end
        
        function image_changed(app)
            if app.ImageChanged
                
                %check if calling figure window (still) exists
                if isobject(app.CallingApp) && isvalid(app.CallingApp)
                    if isprop(app.CallingApp, app.CallingAppPropName{1})
                        %actualize data in calling app
                        app.CallingApp = setfield(app.CallingApp, app.CallingAppPropName{:},...
                            {app.CallingAppDataIdx},app.Img);
                    end
                else
                    %  ask if variable should be saved (TODO)
                end
                app.ImageChanged = false;
            end            
        end
    end
    
    methods (Access = private)
        
        function mask_options = get_mask_options(app)

            mask_options = struct();
            %mask_options.auto_bg = false;            
            %mask_options.auto_thres = false;
            %mask_options.thres_val = [];
            %mask_options.thres_intv = [];
            %mask_options.mask_by_line = false;
            %mask_options.inv_mask = false;
            %mask_options.use_mask = app.usemaskingCheckBox.Value;

            if app.usemaskingCheckBox.Value
                mask_options.mask_type = app.MaskDropDown.Value;
                switch app.MaskDropDown.Value
                    case "auto_bg"
                        %mask_options.auto_bg = true;
                    case "auto_thres"
                        if app.ThresSwitch.Value == "hi" 
                            mask_options.inv_mask = true;
                        end
                    case "thres_val"
                        lims = app.ThresSlider.Limits;
                        mask_options.thres_val = (app.ThresEditField.Value-lims(1))./diff(lims);
                        if app.ThresSwitch.Value == "hi" 
                            mask_options.inv_mask = true;
                        end
                    case "thres_intv"
                        lims = app.ThresIntSlider.Limits;
                        mask_options.thres_intv = (app.ThresIntSlider.Value-lims(1))./diff(lims);
                        if app.ThresSwitch.Value == "out" 
                            mask_options.inv_mask = true;
                        end
                end
                
            end

            switch app.TabGroup.SelectedTab 
                case app.planefitTab
                    if true
                    end
                    
                case app.flattenTab                    
                    if app.maskbylineCheckBox.Value
                        mask_options.mask_by_line = true;
                    end                    
            end
            
        end
        
        function load_image(app)
            if ~isempty(app.Img)
                app.ChannelsListBox.Items = app.Img.AvChannels';
                app.ChannelsListBox.ItemsData = (1:numel(app.Img.AvChannels));

                app.bychannelDropDown.Items = app.Img.AvChannels';
                app.bychannelDropDown.ItemsData = (1:numel(app.Img.AvChannels));  

                app.actualize_plot();
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, Img, options)
            arguments
                app AFMImagePlot
                Img (1,1) AFMImage = []
                options.CallingFigure = []
                options.CallingApp {mustBeA(options.CallingApp, 'matlab.apps.AppBase')} 
                options.CallingAppImgDataPropertyName {mustBeTextScalar} = ''   %property of calling app where images are stored
                options.CallingAppImgDataIdx {mustBeInteger, mustBePositive} = []   %index of image to plot
                options.CallingAppSubWinPropertyName {mustBeTextScalar} = ''  %property of the calling app in which the handles of subfigures are stored
                options.AddData struct 
            end
            
            app.FileMenu.Visible = "off";

            if ~isempty(Img)
                app.Img = Img;
            elseif isfield(options, 'CallingApp') && isobject(options.CallingApp) && isvalid(options.CallingApp)
                app.CallingApp = options.CallingApp;
                
                %get figure of calling app
                app_props = properties(app.CallingApp);
                propIdx = find(contains(cellfun(@(x) class(app.CallingApp.(x)), app_props, 'UniformOutput', false),'Figure'),1);
                if ~isempty(propIdx)
                    app.CallingFigure = app.CallingApp.(app_props{propIdx});
                else
                    error('Calling app has no figure.')
                end
                
                %enable also reading of substructures
                propname = strsplit(options.CallingAppImgDataPropertyName, '.');
                if isprop(app.CallingApp, propname{1})
                    app.CallingAppPropName = propname;
                else
                    error('Error while opening image: Invalid property name of calling app.')
                end
                if isempty(options.CallingAppImgDataIdx)
                    app.CallingAppDataIdx = 1;
                else
                    if length(getfield(app.CallingApp, app.CallingAppPropName{:})) < options.CallingAppImgDataIdx
                        error('Error while opening image: Invalid index value for image data.')
                    end
                    app.CallingAppDataIdx = options.CallingAppImgDataIdx;
                end
                app.Img = getfield(app.CallingApp, app.CallingAppPropName{:}, {app.CallingAppDataIdx});
                if ~isempty(options.AddData)
                    app.AddData = options.AddData;
                    if any(abs(app.Img.params.Position.X - app.AddData.data.x)>0.5*app.Img.params.XSize) || ...
                        any(abs(app.Img.params.Position.Y - app.AddData.data.y)>0.5*app.Img.params.YSize)
                        uialert(app.UIFigure, "Some (or all) data points are outside of the image frame.",...
                            "Warning","Icon","warning","Modal",true);
                    end                    
                end
            else %if isempty(Img) && ~isfield(options.CallingApp)
                app.FileMenu.Visible = "on";
            end

            

            app.colormapDropDown.Items = {'parula', 'turbo', 'hsv', 'hot',...
                'cool', 'spring', 'summer', 'autumn', 'winter', 'gray', ...
                'bone', 'copper', 'pink', 'sky', 'abyss', 'jet', 'lines', ...
                'colorcube', 'prism', 'flag'};
            app.Button.Value = 0;
            app.ButtonValueChanged();
            
            app.load_image();


        end

        % Menu selected function: OpenMenu
        function OpenMenuSelected(app, event)
            % if ~isempty(app.Image)
            %     sel = uiconfirm(app.UIFigure, "Opening a new file will delete all current data. Do you want to proceed?",...
            %         "Warning", "Icon","question","Options",["Yes", "No"],"CancelOption",2);
            %     if sel == "No"
            %         return
            %     end
            % end

            [newfile, newpath]=uigetfile('*.*','Select files', [app.path '/'], 'MultiSelect','off');
            app.UIFigure;
            if isnumeric(newfile) && newfile == 0, return; end   %end execution if user pressed "cancel"
            app.path = newpath;

            app.UIFigure.Visible = "off";
            app.UIFigure.Visible = 'on';

            try
                app.Img = AFMImage(fullfile(newpath,newfile));
                app.file = newfile;
                app.load_image();
            catch ME
                answ = uiconfirm(app.UIFigure, "Error while loading the file: " + ME.message, 'Error','Icon','error',...
                    "Options", ["OK" ; "Show full error trace"] ,"DefaultOption", "OK");
                if answ ~= "OK"
                    text = {['Error while loading the file: '  ME.message]};
                    for ii = 1:numel(ME.stack)
                        text{end+1} = ['Error in line (' num2str(ME.stack(ii).line) ...
                            ') in file ' ME.stack(ii).file];
                    end
                    uialert(app.UIFigure, text, 'Error','Icon','error');
                end
                return
                           
            end
        end

        % Menu selected function: TipReconMenu
        function TipReconMenuSelected(app, event)
            BlindTipReconstruction(app.Img.reduceChanNoTo(app.ChannelsListBox.Value));
        end

        % Value changed function: colormapDropDown
        function colormapDropDownValueChanged(app, event)
            value = app.colormapDropDown.Value;
            app.actualize_plot();
        end

        % Value changed function: ModificationsListBox
        function ModificationsListBoxValueChanged(app, event)
            if ~isempty(app.ModificationsListBox.Items)
                modTableItems = app.ModificationsListBox.Value;
                app.UITable_exMods.Data = [];
                tmpC = fieldnames(modTableItems.params);
                for ii = 1:numel(fieldnames(modTableItems.params))
                        tmpC{ii,2} = modTableItems.params.(tmpC{ii,1});
                end
                app.UITable_exMods.Data = cell2table(tmpC);
                
                app.UITable_exMods.ColumnEditable(2) = modTableItems.vals_editable;
            else
                app.UITable_exMods.Data = [];
            end

            
        end

        % Value changed function: ChannelsListBox
        function ChannelsListBoxValueChanged(app, event)
            im_no = app.ChannelsListBox.Value;

            app.bychannelDropDown.Value = im_no;

            
            if ~isempty(app.Img.Channel(im_no).ModificationHistory)
                app.ModificationsListBox.Items = cellfun( ...
                    @(x) x.name, app.Img.Channel(im_no).ModificationHistory, ...
                    "UniformOutput",false)';
            else
                app.ModificationsListBox.Items = {};
            end

            entr = {};
            for ii=1:numel(app.Img.Channel(im_no).ModificationHistory)
                entr = struct();
                switch app.Img.Channel(im_no).ModificationHistory{ii}.name
                    case 'flatten'
                        entr.vals_editable = false;
                        entr.params = app.Img.Channel(im_no).ModificationHistory{ii}.params;
                        
                    case 'plane fit'
                        entr.vals_editable = true;
                        entr.params = app.Img.Channel(im_no).ModificationHistory{ii}.params;
                    case 'filter'
                        entr.vals_editable = true;
                        entr.params = app.Img.Channel(im_no).ModificationHistory{ii}.params;
                end
                %entr.params = rmfield(entr.params, 'auto_thres');
                app.ModificationsListBox.ItemsData{ii} = entr;
            end
            app.ModificationsListBox.Value = entr;
            app.ModificationsListBoxValueChanged();

            app.bychannelDropDownValueChanged();

            app.actualize_plot;

            if app.ImageChanged
                app.image_changed();
            end


        end

        % Button pushed function: AddButton
        function AddButtonPushed(app, event)
            im_no = app.ChannelsListBox.ValueIndex;

            mask_pars = app.get_mask_options();
            %if ImData for calculating the mask is not the actual
            %ImChannel, calculate the mask directly and save it in the
            %Mod-options
            if app.bychannelDropDown.Value ~= app.ChannelsListBox.Value
                mask_pars = namedargs2cell(mask_pars);
                mask = AFMImageChannel.get_mask(app.Img.Channel(app.bychannelDropDown.Value).ImageDataMod, mask_pars{:});
                mask_pars = struct('mask_type', "direct", 'Mask', mask);
            end            
            
            
            switch app.TabGroup.SelectedTab.Title
                case 'plane fit'
                    app.Img.Channel(im_no) = ...
                        app.Img.Channel(im_no).planeFit(app.xdirorderEditField.Value, app.ydirorderEditField.Value ...
                        ,use_mask=app.usemaskingCheckBox.Value...
                        ,maskparams=mask_pars);
                case 'flatten'
                    app.Img.Channel(im_no) = ...
                        app.Img.Channel(im_no).flatten(app.orderEditField.Value ...
                        ,use_mask=app.usemaskingCheckBox.Value...
                        ,maskparams=mask_pars);
                case 'filter'
                    size = app.sizeEditField.Value;
                    sigma = app.sigmaEditField.Value;
                    alpha = 0;
                    if app.FilterTypeDropDown.Value == "laplacian"
                        sigma = 0;
                        alpha = app.sigmaEditField.Value;
                    end
                    app.Img.Channel(im_no) = ...
                        app.Img.Channel(im_no).filter(app.FilterTypeDropDown.Value ...
                        ,size...
                        ,sigma=sigma...
                        ,alpha=alpha...
                        ,use_mask=app.usemaskingCheckBox.Value...
                        ,maskparams=mask_pars);
            end
            app.ImageChanged = true;
            app.ChannelsListBoxValueChanged();
        end

        % Button pushed function: RemoveButton
        function RemoveButtonPushed(app, event)
            im_no = app.ChannelsListBox.ValueIndex;
            mod_no = app.ModificationsListBox.ValueIndex;
            app.Img.Channel(im_no).ModificationHistory(mod_no) = [];
            
            app.ImageChanged = true;
            app.ChannelsListBoxValueChanged();
        end

        % Value changed function: Button
        function ButtonValueChanged(app, event)
            value = app.Button.Value;
            % app.UIFigure.SizeChangedFcn = [];
            % app.UIFigure.AutoResizeChildren = "off";
            % app.UIFigure.Resize = "off";
            app.UIAxes.Visible = "off";
            if value                
                app.UIFigure.Position(3) = 939;
                app.Panel.Visible = "on";
                app.ModifcationhistoryPanel.Visible = "on";
                app.AddmodificationsPanel.Visible = "on";
                app.Button.Text = '<<';

            else
                app.UIFigure.Position(3) = 420;
                app.Panel.Visible = "off";
                app.ModifcationhistoryPanel.Visible = "off";
                app.AddmodificationsPanel.Visible = "off";
                app.Button.Text = '>>';
            end
            app.UIAxes.Visible = "on";
        end

        % Cell edit callback: UITable_exMods
        function UITable_exModsCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            im_no = app.ChannelsListBox.ValueIndex;
            mod_no = app.ModificationsListBox.ValueIndex;
            param_name = app.UITable_exMods.Data{indices(1), indices(2)-1};

            app.Img.Channel(im_no).ModificationHistory{mod_no}.params.(param_name{1}) = ...
                newData;
            
            app.ImageChanged = true;
            app.ChannelsListBoxValueChanged();
        end

        % Value changed function: ShowmaskCheckBox
        function ShowmaskCheckBoxValueChanged(app, event)

            app.actualize_plot();
            
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            selectedTab = app.TabGroup.SelectedTab;
            switch selectedTab.Title
                case "plane fit"
                    app.maskbylineCheckBox.Visible = "off";
                case "flatten"
                    app.maskbylineCheckBox.Visible = "on";
                case "filter"
                    app.maskbylineCheckBox.Visible = "off";
            end

        end

        % Value changed function: FilterTypeDropDown
        function FilterTypeDropDownValueChanged(app, event)
            value = app.FilterTypeDropDown.Value;
            switch value
                case 'average'
                    app.sizeEditField.Visible = "on";
                    app.sizenxnEditFieldLabel.Visible = "on";
                    app.sigmaEditField.Visible = "off";
                    app.sigmaEditFieldLabel.Visible = "off";
                case 'median'
                    app.sizeEditField.Visible = "on";
                    app.sizenxnEditFieldLabel.Visible = "on";
                    app.sigmaEditField.Visible = "off";
                    app.sigmaEditFieldLabel.Visible = "off";
                case 'gauss'
                    app.sizeEditField.Visible = "off";
                    app.sizenxnEditFieldLabel.Visible = "off";
                    app.sigmaEditField.Visible = "on";
                    app.sigmaEditFieldLabel.Text = 'sigma';
                    app.sigmaEditFieldLabel.Visible = "on";
                case 'LoG'
                    app.sizeEditField.Visible = "on";
                    app.sizenxnEditFieldLabel.Visible = "on";
                    app.sigmaEditField.Visible = "on";
                    app.sigmaEditFieldLabel.Text = 'sigma';
                    app.sigmaEditFieldLabel.Visible = "on";
                case 'laplacian'
                    app.sizeEditField.Visible = "off";
                    app.sizenxnEditFieldLabel.Visible = "off";
                    app.sigmaEditField.Visible = "on";
                    app.sigmaEditFieldLabel.Text = 'alpha';
                    app.sigmaEditFieldLabel.Visible = "on";
            end
        end

        % Value changed function: usemaskingCheckBox
        function usemaskingCheckBoxValueChanged(app, event)
            value = app.usemaskingCheckBox.Value;
            if value
                app.MaskDropDown.Visible = "on";
                app.MaskDropDown.Enable = "on";
                app.MaskDropDownValueChanged();
            else
                app.MaskDropDown.Visible = "off";
                app.ThresEditField.Visible = "off";
                app.ThresMaxEditField.Visible = "off";
                app.ThresSlider.Visible = "off";
                app.ThresIntSlider.Visible = "off";
                app.ThresSwitch.Visible = "off";
                app.bychannelDropDown.Visible = "off";
                app.bychannelDropDownLabel.Visible = "off";
                app.maskbylineCheckBox.Visible = "off";
            end
            if app.ShowmaskCheckBox.Value
                app.actualize_plot();
            end
        end

        % Value changed function: MaskDropDown
        function MaskDropDownValueChanged(app, event)
            value = app.MaskDropDown.Value;

            app.ThresEditField.Enable = "on";
            app.ThresMaxEditField.Enable = "on";
            app.ThresSlider.Enable = "on";
            app.ThresIntSlider.Enable = "on";
            app.ThresSwitch.Enable = "on";
            app.bychannelDropDown.Enable = "on";
            app.bychannelDropDownLabel.Enable = "on";
            app.maskbylineCheckBox.Enable = "on";
            if app.TabGroup.SelectedTab == app.flattenTab
                app.maskbylineCheckBox.Visible = "on";
            else
                app.maskbylineCheckBox.Visible = "off";
            end

            switch value
                case "auto_bg"
                    app.ThresEditField.Visible = "off";
                    app.ThresMaxEditField.Visible = "off";
                    app.ThresSlider.Visible = "off";
                    app.ThresIntSlider.Visible = "off";
                    app.ThresSwitch.Visible = "off";
                    app.bychannelDropDown.Visible = "on";
                    app.bychannelDropDownLabel.Visible = "on";
                    app.actualize_plot();
                case "auto_thres"
                    app.ThresEditField.Visible = "off";
                    app.ThresMaxEditField.Visible = "off";
                    app.ThresSlider.Visible = "off";
                    app.ThresIntSlider.Visible = "off";
                    app.ThresSwitch.Visible = "on";                    
                    app.ThresSwitch.Items = ["low"; "hi"];
                    app.bychannelDropDown.Visible = "on";
                    app.bychannelDropDownLabel.Visible = "on";
                    app.actualize_plot();
                case "thres_val"
                    app.ThresEditField.Visible = "on";
                    app.ThresMaxEditField.Visible = "off";
                    app.ThresSlider.Visible = "on";
                    app.ThresIntSlider.Visible = "off";
                    app.ThresSwitch.Visible = "on";                    
                    app.ThresSwitch.Items = ["low"; "hi"];
                    app.bychannelDropDown.Visible = "on";
                    app.bychannelDropDownLabel.Visible = "on";
                    app.bychannelDropDownValueChanged();
                case "thres_intv"
                    app.ThresEditField.Visible = "on";
                    app.ThresMaxEditField.Visible = "on";
                    app.ThresSlider.Visible = "off";
                    app.ThresIntSlider.Visible = "on";
                    app.ThresSwitch.Visible = "on";
                    app.ThresSwitch.Items = ["out"; "in"];
                    app.bychannelDropDown.Visible = "on";
                    app.bychannelDropDownLabel.Visible = "on";
                    app.bychannelDropDownValueChanged();
            end            
        end

        % Value changed function: bychannelDropDown
        function bychannelDropDownValueChanged(app, event)
            value = app.bychannelDropDown.Value;
            Im = app.Img.Channel(value).ImageDataMod;
            im_min = min(min(Im));
            im_max = max(max(Im));

            if app.MaskDropDown.Value == "thres_val"
                app.ThresSlider.Limits = [im_min im_max];
                app.ThresEditField.Limits = [im_min im_max];
                if app.ThresSlider.Value < im_min || app.ThresSlider.Value > im_max 
                    app.ThresSlider.Value = (im_min + im_max)/2;
                    app.ThresSliderValueChanged();
                end
            elseif app.MaskDropDown.Value == "thres_intv"
                app.ThresIntSlider.Limits = [im_min im_max];
                app.ThresEditField.Limits = [im_min im_max];
                app.ThresMaxEditField.Limits = [im_min im_max];
                if any(app.ThresIntSlider.Value < im_min) || any(app.ThresIntSlider.Value > im_max) 
                    app.ThresIntSlider.Value(1) = im_min + (im_max-im_min)/3;
                    app.ThresIntSlider.Value(2) = im_min + (im_max-im_min)/3*2;
                    app.ThresIntSliderValueChanging();
                end
                app.ThresIntSlider.StepMode = "manual";
                app.ThresIntSlider.Step = (im_max - im_min)/10;
            end
            if app.ShowmaskCheckBox.Value
                app.actualize_plot();
            end
        end

        % Value changing function: ThresSlider
        function ThresSliderValueChanging(app, event)
            changingValue = event.Value;
            app.ThresEditField.Value = changingValue;
        end

        % Value changed function: ThresSlider
        function ThresSliderValueChanged(app, event)
            value = app.ThresSlider.Value;
            if app.ShowmaskCheckBox.Value
                app.actualize_plot();
            end
        end

        % Value changed function: ThresEditField
        function ThresEditFieldValueChanged(app, event)
            value = app.ThresEditField.Value;
            if app.MaskDropDown.Value == "thres_val"
                app.ThresSlider.Value = value;
                app.ThresSliderValueChanged();
            elseif app.MaskDropDown.Value == "thres_intv"
                app.ThresIntSlider.Value(1) = value;
                app.ThresIntSliderValueChanged();
            end            
        end

        % Value changing function: ThresIntSlider
        function ThresIntSliderValueChanging(app, event)
            changingValue = event.Value;
            app.ThresEditField.Value = changingValue(1);
            app.ThresMaxEditField.Value = changingValue(2);
        end

        % Value changed function: ThresIntSlider, ThresSwitch, 
        % ...and 1 other component
        function ThresIntSliderValueChanged(app, event)
            value = app.ThresIntSlider.Value;
            if app.ShowmaskCheckBox.Value
                app.actualize_plot();
            end
        end

        % Value changed function: ThresMaxEditField
        function ThresMaxEditFieldValueChanged(app, event)
            value = app.ThresMaxEditField.Value;
            app.ThresIntSlider.Value(2) = value;
            app.ThresIntSliderValueChanged();            
        end

        % Callback function: QuitMenu, UIFigure
        function UIFigureCloseRequest(app, event)
            app.image_changed();
            
            delete(app)
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 939 380];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Resize = 'off';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create OpenMenu
            app.OpenMenu = uimenu(app.FileMenu);
            app.OpenMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenMenuSelected, true);
            app.OpenMenu.Text = 'Open';

            % Create QuitMenu
            app.QuitMenu = uimenu(app.FileMenu);
            app.QuitMenu.MenuSelectedFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.QuitMenu.Text = 'Quit';

            % Create ExtraMenu
            app.ExtraMenu = uimenu(app.UIFigure);
            app.ExtraMenu.Text = 'Extra';

            % Create TipReconMenu
            app.TipReconMenu = uimenu(app.ExtraMenu);
            app.TipReconMenu.MenuSelectedFcn = createCallbackFcn(app, @TipReconMenuSelected, true);
            app.TipReconMenu.Text = 'TipRecon';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.PlotBoxAspectRatio = [1.12704918032787 1.12704918032787 1];
            app.UIAxes.ColorOrder = [1 0 0;1 0 1;0 1 0;0 1 1;0 0 1;0 0 0];
            app.UIAxes.Position = [1 1 414 371];

            % Create Button
            app.Button = uibutton(app.UIFigure, 'state');
            app.Button.ValueChangedFcn = createCallbackFcn(app, @ButtonValueChanged, true);
            app.Button.Text = '<<';
            app.Button.Position = [379 12 36 23];
            app.Button.Value = true;

            % Create Panel
            app.Panel = uipanel(app.UIFigure);
            app.Panel.AutoResizeChildren = 'off';
            app.Panel.Title = 'Panel';
            app.Panel.Position = [425 13 152 359];

            % Create colormapDropDownLabel
            app.colormapDropDownLabel = uilabel(app.Panel);
            app.colormapDropDownLabel.HorizontalAlignment = 'right';
            app.colormapDropDownLabel.Position = [16 128 56 22];
            app.colormapDropDownLabel.Text = 'colormap';

            % Create colormapDropDown
            app.colormapDropDown = uidropdown(app.Panel);
            app.colormapDropDown.ValueChangedFcn = createCallbackFcn(app, @colormapDropDownValueChanged, true);
            app.colormapDropDown.Position = [15 99 100 22];

            % Create ChannelsListBoxLabel
            app.ChannelsListBoxLabel = uilabel(app.Panel);
            app.ChannelsListBoxLabel.HorizontalAlignment = 'right';
            app.ChannelsListBoxLabel.Position = [14 308 55 22];
            app.ChannelsListBoxLabel.Text = 'Channels';

            % Create ChannelsListBox
            app.ChannelsListBox = uilistbox(app.Panel);
            app.ChannelsListBox.ValueChangedFcn = createCallbackFcn(app, @ChannelsListBoxValueChanged, true);
            app.ChannelsListBox.Position = [15 160 117 145];

            % Create LockaxesSwitchLabel
            app.LockaxesSwitchLabel = uilabel(app.Panel);
            app.LockaxesSwitchLabel.HorizontalAlignment = 'center';
            app.LockaxesSwitchLabel.Position = [4 40 60 22];
            app.LockaxesSwitchLabel.Text = 'Lock axes';

            % Create LockaxesSwitch
            app.LockaxesSwitch = uiswitch(app.Panel, 'slider');
            app.LockaxesSwitch.Position = [92 42 34 15];

            % Create ShowmaskCheckBox
            app.ShowmaskCheckBox = uicheckbox(app.Panel);
            app.ShowmaskCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowmaskCheckBoxValueChanged, true);
            app.ShowmaskCheckBox.Text = 'Show mask';
            app.ShowmaskCheckBox.Position = [16 70 85 22];

            % Create ModifcationhistoryPanel
            app.ModifcationhistoryPanel = uipanel(app.UIFigure);
            app.ModifcationhistoryPanel.AutoResizeChildren = 'off';
            app.ModifcationhistoryPanel.Title = 'Modifcation history';
            app.ModifcationhistoryPanel.Position = [589 13 149 359];

            % Create ModificationsListBox
            app.ModificationsListBox = uilistbox(app.ModifcationhistoryPanel);
            app.ModificationsListBox.Items = {};
            app.ModificationsListBox.ValueChangedFcn = createCallbackFcn(app, @ModificationsListBoxValueChanged, true);
            app.ModificationsListBox.Position = [9 189 133 137];
            app.ModificationsListBox.Value = {};

            % Create UITable_exMods
            app.UITable_exMods = uitable(app.ModifcationhistoryPanel);
            app.UITable_exMods.ColumnName = {'parameter'; 'value'};
            app.UITable_exMods.ColumnWidth = {85, 48};
            app.UITable_exMods.RowName = {};
            app.UITable_exMods.ColumnEditable = [false true];
            app.UITable_exMods.CellEditCallback = createCallbackFcn(app, @UITable_exModsCellEdit, true);
            app.UITable_exMods.Position = [7 45 135 135];

            % Create RemoveButton
            app.RemoveButton = uibutton(app.ModifcationhistoryPanel, 'push');
            app.RemoveButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveButtonPushed, true);
            app.RemoveButton.Position = [25 10 100 23];
            app.RemoveButton.Text = 'Remove';

            % Create AddmodificationsPanel
            app.AddmodificationsPanel = uipanel(app.UIFigure);
            app.AddmodificationsPanel.AutoResizeChildren = 'off';
            app.AddmodificationsPanel.Title = 'Add modifications';
            app.AddmodificationsPanel.Position = [749 12 182 359];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.AddmodificationsPanel);
            app.TabGroup.AutoResizeChildren = 'off';
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Position = [9 211 164 120];

            % Create planefitTab
            app.planefitTab = uitab(app.TabGroup);
            app.planefitTab.AutoResizeChildren = 'off';
            app.planefitTab.Title = 'plane fit';

            % Create xdirorderEditFieldLabel
            app.xdirorderEditFieldLabel = uilabel(app.planefitTab);
            app.xdirorderEditFieldLabel.HorizontalAlignment = 'right';
            app.xdirorderEditFieldLabel.Position = [1 64 61 22];
            app.xdirorderEditFieldLabel.Text = 'x-dir order';

            % Create xdirorderEditField
            app.xdirorderEditField = uieditfield(app.planefitTab, 'numeric');
            app.xdirorderEditField.Limits = [0 7];
            app.xdirorderEditField.RoundFractionalValues = 'on';
            app.xdirorderEditField.Position = [97 64 59 22];
            app.xdirorderEditField.Value = 1;

            % Create ydirorderEditFieldLabel
            app.ydirorderEditFieldLabel = uilabel(app.planefitTab);
            app.ydirorderEditFieldLabel.HorizontalAlignment = 'right';
            app.ydirorderEditFieldLabel.Position = [3 36 61 22];
            app.ydirorderEditFieldLabel.Text = 'y-dir order';

            % Create ydirorderEditField
            app.ydirorderEditField = uieditfield(app.planefitTab, 'numeric');
            app.ydirorderEditField.Limits = [0 7];
            app.ydirorderEditField.RoundFractionalValues = 'on';
            app.ydirorderEditField.Position = [97 36 59 22];
            app.ydirorderEditField.Value = 1;

            % Create flattenTab
            app.flattenTab = uitab(app.TabGroup);
            app.flattenTab.AutoResizeChildren = 'off';
            app.flattenTab.Title = 'flatten';

            % Create orderEditFieldLabel
            app.orderEditFieldLabel = uilabel(app.flattenTab);
            app.orderEditFieldLabel.HorizontalAlignment = 'right';
            app.orderEditFieldLabel.Position = [7 57 33 22];
            app.orderEditFieldLabel.Text = 'order';

            % Create orderEditField
            app.orderEditField = uieditfield(app.flattenTab, 'numeric');
            app.orderEditField.Limits = [0 3];
            app.orderEditField.RoundFractionalValues = 'on';
            app.orderEditField.Editable = 'off';
            app.orderEditField.Position = [96 57 59 22];

            % Create filterTab
            app.filterTab = uitab(app.TabGroup);
            app.filterTab.Title = 'filter';

            % Create TypeDropDownLabel
            app.TypeDropDownLabel = uilabel(app.filterTab);
            app.TypeDropDownLabel.HorizontalAlignment = 'right';
            app.TypeDropDownLabel.Position = [7 64 30 22];
            app.TypeDropDownLabel.Text = 'Type';

            % Create FilterTypeDropDown
            app.FilterTypeDropDown = uidropdown(app.filterTab);
            app.FilterTypeDropDown.Items = {'average', 'median', 'gauss', 'highpass', 'laplacian'};
            app.FilterTypeDropDown.ItemsData = {'average', 'median', 'gauss', 'LoG', 'laplacian'};
            app.FilterTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @FilterTypeDropDownValueChanged, true);
            app.FilterTypeDropDown.Position = [52 64 103 22];
            app.FilterTypeDropDown.Value = 'average';

            % Create sizenxnEditFieldLabel
            app.sizenxnEditFieldLabel = uilabel(app.filterTab);
            app.sizenxnEditFieldLabel.HorizontalAlignment = 'right';
            app.sizenxnEditFieldLabel.Position = [4 34 62 22];
            app.sizenxnEditFieldLabel.Text = 'size (n x n)';

            % Create sizeEditField
            app.sizeEditField = uieditfield(app.filterTab, 'numeric');
            app.sizeEditField.Position = [106 34 51 22];

            % Create sigmaEditFieldLabel
            app.sigmaEditFieldLabel = uilabel(app.filterTab);
            app.sigmaEditFieldLabel.HorizontalAlignment = 'right';
            app.sigmaEditFieldLabel.Position = [28 8 37 22];
            app.sigmaEditFieldLabel.Text = 'sigma';

            % Create sigmaEditField
            app.sigmaEditField = uieditfield(app.filterTab, 'numeric');
            app.sigmaEditField.Position = [105 8 51 22];

            % Create AddButton
            app.AddButton = uibutton(app.AddmodificationsPanel, 'push');
            app.AddButton.ButtonPushedFcn = createCallbackFcn(app, @AddButtonPushed, true);
            app.AddButton.Position = [41 10 100 23];
            app.AddButton.Text = 'Add';

            % Create MaskPanel
            app.MaskPanel = uipanel(app.AddmodificationsPanel);
            app.MaskPanel.AutoResizeChildren = 'off';
            app.MaskPanel.Position = [9 46 164 157];

            % Create usemaskingCheckBox
            app.usemaskingCheckBox = uicheckbox(app.MaskPanel);
            app.usemaskingCheckBox.ValueChangedFcn = createCallbackFcn(app, @usemaskingCheckBoxValueChanged, true);
            app.usemaskingCheckBox.Text = 'use masking';
            app.usemaskingCheckBox.Position = [5 132 90 22];

            % Create MaskDropDown
            app.MaskDropDown = uidropdown(app.MaskPanel);
            app.MaskDropDown.Items = {'auto background', 'autho threshold', 'threshold', 'interval'};
            app.MaskDropDown.ItemsData = {'auto_bg', 'auto_thres', 'thres_val', 'thres_intv'};
            app.MaskDropDown.ValueChangedFcn = createCallbackFcn(app, @MaskDropDownValueChanged, true);
            app.MaskDropDown.Enable = 'off';
            app.MaskDropDown.Visible = 'off';
            app.MaskDropDown.Position = [19 113 112 22];
            app.MaskDropDown.Value = 'auto_bg';

            % Create maskbylineCheckBox
            app.maskbylineCheckBox = uicheckbox(app.MaskPanel);
            app.maskbylineCheckBox.ValueChangedFcn = createCallbackFcn(app, @ThresIntSliderValueChanged, true);
            app.maskbylineCheckBox.Enable = 'off';
            app.maskbylineCheckBox.Visible = 'off';
            app.maskbylineCheckBox.Text = 'mask by line';
            app.maskbylineCheckBox.Position = [17 4 89 22];

            % Create ThresSlider
            app.ThresSlider = uislider(app.MaskPanel);
            app.ThresSlider.ValueChangedFcn = createCallbackFcn(app, @ThresSliderValueChanged, true);
            app.ThresSlider.ValueChangingFcn = createCallbackFcn(app, @ThresSliderValueChanging, true);
            app.ThresSlider.FontSize = 8;
            app.ThresSlider.Enable = 'off';
            app.ThresSlider.Visible = 'off';
            app.ThresSlider.Position = [12 78 99 3];

            % Create ThresEditField
            app.ThresEditField = uieditfield(app.MaskPanel, 'numeric');
            app.ThresEditField.ValueChangedFcn = createCallbackFcn(app, @ThresEditFieldValueChanged, true);
            app.ThresEditField.FontSize = 10;
            app.ThresEditField.Enable = 'off';
            app.ThresEditField.Visible = 'off';
            app.ThresEditField.Position = [126 70 34 18];

            % Create ThresSwitch
            app.ThresSwitch = uiswitch(app.MaskPanel, 'slider');
            app.ThresSwitch.Items = {'low', 'hi'};
            app.ThresSwitch.ValueChangedFcn = createCallbackFcn(app, @ThresIntSliderValueChanged, true);
            app.ThresSwitch.Enable = 'off';
            app.ThresSwitch.Visible = 'off';
            app.ThresSwitch.Position = [126 32 20 9];
            app.ThresSwitch.Value = 'low';

            % Create bychannelDropDownLabel
            app.bychannelDropDownLabel = uilabel(app.MaskPanel);
            app.bychannelDropDownLabel.HorizontalAlignment = 'right';
            app.bychannelDropDownLabel.Enable = 'off';
            app.bychannelDropDownLabel.Visible = 'off';
            app.bychannelDropDownLabel.Position = [11 92 67 22];
            app.bychannelDropDownLabel.Text = 'by channel:';

            % Create bychannelDropDown
            app.bychannelDropDown = uidropdown(app.MaskPanel);
            app.bychannelDropDown.ValueChangedFcn = createCallbackFcn(app, @bychannelDropDownValueChanged, true);
            app.bychannelDropDown.Enable = 'off';
            app.bychannelDropDown.Visible = 'off';
            app.bychannelDropDown.Position = [79 94 82 18];

            % Create ThresIntSlider
            app.ThresIntSlider = uislider(app.MaskPanel, 'range');
            app.ThresIntSlider.ValueChangedFcn = createCallbackFcn(app, @ThresIntSliderValueChanged, true);
            app.ThresIntSlider.ValueChangingFcn = createCallbackFcn(app, @ThresIntSliderValueChanging, true);
            app.ThresIntSlider.Enable = 'off';
            app.ThresIntSlider.Visible = 'off';
            app.ThresIntSlider.Position = [12 78 99 3];

            % Create ThresMaxEditField
            app.ThresMaxEditField = uieditfield(app.MaskPanel, 'numeric');
            app.ThresMaxEditField.ValueChangedFcn = createCallbackFcn(app, @ThresMaxEditFieldValueChanged, true);
            app.ThresMaxEditField.Enable = 'off';
            app.ThresMaxEditField.Visible = 'off';
            app.ThresMaxEditField.Position = [126 50 34 18];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AFMImagePlot_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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