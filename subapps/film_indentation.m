function varargout = film_indentation(varargin)
% requires cell array with data as table with two columns: X (in nm) and Y (in nN),
% including VariableUnits, VariableDescription and Description (as descr.
% of Dataset)



% Auftr?ge:
% - import ascii files (inkl. Korrektur wird durch hauptprogramm ?bernommen)
% -->input: approach part (multi curves)
% - Input variablen: max. und min. force fit boundary, tip radius, film thickness etc..?
% - damit: fit versch. modelle? erstmal s. paper.
% - simultan-fit f?r >10-100 datens?tze
% - plot
% - output F, z_piezo oder indentation depth (Z_piezo - deflection)

if nargin == 1
    odata = varargin{1};
else
    odata = cell(0);
    [thisfile_path , ~, ~] = fileparts(mfilename("fullpath"));
    disp(genpath(fullfile(thisfile_path, "..", "models")));
    %addpath(genpath(fullfile(thisfile_path, "..", "models")));
end



%%% global variables
        
data = cell(0);
fit_constraints = struct('enable', false, 'min', [], 'max', []);
fits = cell(length(data),1);
selectedFit = ones(length(fits),1);
current_folder = pwd;
curr_curve = [];
dataGroups = struct('Idxs', [], 'Name', '');           %cell containing arrays of indices of grouped data, where entry 1 contains the ungrouped data

kBT=4.14;  %zJ = pN*nm

expParams = struct;
expParams.f_thick = struct('Value', 1, 'Name', 'Film thickness', 'Unit', 'nm');    %Film thickness in nm;
expParams.f_radius = struct('Value', 1, 'Name', 'Film radius', 'Unit', 'µm');     %film radius in mu m;
expParams.poisson = struct('Value', 1/3, 'Name', 'Poisson ratio', 'Unit', '');    %Poisson ratio
expParams.tip_radius = struct('Value', 5, 'Name', 'Tip radius', 'Unit', 'nm');   %Tip radius in nm
expParams.tip_angle = struct('Value', 20, 'Name', 'Tip cone half angle', 'Unit', 'deg');   %tip cone half angle
expParams.young = struct('Value', 1, 'Name', 'Young''s modulus', 'Unit', 'GPa');        %Young's modulus in GPa
expParams.prestress = struct('Value', 1e-3, 'Name', 'Pre-stress', 'Unit', 'N/m'); %Pre-stress in N/m
expParams.cl_spr_const = struct('Value', 5, 'Name', 'Cantilever spring constant', 'Unit', 'N/m'); %Cantilever spring constant in N/m
if numel(data) > 0 && ~isempty(data{1}.Properties.UserData)
    expParams.cl_spr_const.Value = sscanf(data{1}.Properties.UserData{1}, 'Cantilever spring constant:  %f');
end

paramDefValues = structfun(@(x) x.Value, expParams, "UniformOutput", false);


fit_models = struct('ID', [], 'name', [], 'modelFunc',[],'Description', []);

fit_models(1).ID = 'linear';
fit_models(1).name = 'linear';
fit_models(1).Description = ['k = ' char(8706) 'F/' char(8706) char(948)];

fit_models(end+1).ID = 'cubic';
fit_models(end).name = 'cubic';
fit_models(end).Description = 'Cubic fit. (approximation for membranes with pre-stress)';

fit_models(end+1).ID = 'cubic_w_corr';
fit_models(end).name = 'cubic with correction';
fit_models(end).Description = 'Cubic fit with log correction factor and Poission number (approximation for membranes with pre-stress)';

fit_models(end+1).ID = 'SolMem_PointIndent_A';
fit_models(end).name = 'Solid Membrane Point-like indenter (a)';
fit_models(end).Description = 'Solid Membrane with pre-tension, point-like indenter, const. stress bound. cond.';

fit_models(end+1).ID = 'SolMem_PointIndent_B';
fit_models(end).name = 'Solid Membrane Point-like indenter (b)';
fit_models(end).Description = 'Solid Membrane with pre-tension, point-like indenter, const. strain bound. cond.';

fit_models(end+1).ID = 'SolMem_SpheIndent_A';
fit_models(end).name = 'Solid Membrane spherical indenter';
fit_models(end).Description = 'Solid Membrane with pre-tension, spherical indenter, const. stress bound. cond.';

fit_models(end+1).ID = 'FluidMem_SpheIndent';
fit_models(end).name = 'Fluid membrane spherical indenter';
fit_models(end).Description = 'Fluid membrane without elasticity, spherical indenter';

fit_models(end+1).ID = 'FluidElasMem_SpheIndent';
fit_models(end).name = 'Fluid elastic membrane spherical indenter';
fit_models(end).Description = 'Fluid membrane with tension and elasticity, spherical indenter';

fit_models(end+1).ID = 'FluidMem_CylIndent';
fit_models(end).name = 'Fluid membrane cylindrical indenter';
fit_models(end).Description = 'Fluid membrane without elasticity, cylindrical indenter';

fit_models(end+1).ID = 'FluidElasMem_CylIndent';
fit_models(end).name = 'Fluid elastic membrane cylindrical indenter';
fit_models(end).Description = 'Fluid membrane with tension and elasticity, cylindrical indenter';

fit_models(end+1).ID = 'FluidMem_ConicIndent';
fit_models(end).name = 'Fluid membrane conical indenter';
fit_models(end).Description = 'Fluid membrane without elasticity, conical indenter';

fit_models(end+1).ID = 'FluidElasMem_ConicIndent';
fit_models(end).name = 'Fluid elastic membrane conical indenter';
fit_models(end).Description = 'Fluid membrane with tension and elasticity, conical indenter';



%%% create figure %%%%

if ispc
    FontSize = 10;
elseif isunix
    FontSize = 12;
end

FigPos    = get(0,'DefaultFigurePosition');
FigPos(3:4) = [680 480];
FigPos    = getnicedialoglocation(FigPos, get(0,'DefaultFigureUnits'));

unittransf = @(x) (reshape(reshape(x, 2,2)'.*[640 480], 1 ,4));
transfUnit = @(relPos, Parent) (reshape((reshape(relPos, 2,2)'.* Parent.Position(3:4))', 1 ,4));

fh = uifigure(...
        'Visible','on' ...
        ,'Position',FigPos... %[360,500,450,285]);
        ...,'ToolBar', 'figure'...
        );
fh.Name = 'Indentation analysis';


dataMenu = uimenu(fh, 'Text', 'Data');
    importMenu = uimenu(dataMenu ...
        ,'Text', '&Open files' ...
        ,'MenuSelectedFcn', @importmenu_callback ...
        );
    groupSortData = uimenu(dataMenu ...
        ,'Text', 'Group and sort data' ...
        ,'MenuSelectedFcn', @groupSortData_callback...
        );

    closeMenu = uimenu(dataMenu ...
        ,'Text', '&Close actual file' ...
        ,'MenuSelectedFcn', @closemenu_callback ...
        );
    closeAllMenu = uimenu(dataMenu ...
        ,'Text', '&Close all' ...
        ,'MenuSelectedFcn', @closeAllmenu_callback ...
        );

viewMenu =  uimenu(fh, 'Text', 'View');
    showLegendMenu = uimenu(viewMenu ...
        ,'Text', 'Show Plot Legend' ...
        ,'MenuSelectedFcn', @showLegendMenu_callback ...
        ,'Enable', 'on'...
        ,'Checked','on'...
        );

    fitplotMenu = uimenu(viewMenu ...
       ...%,'Position',transfUnit([0.02 0.5 0.22 0.05], fh)...
       ...%,'FontSize', 10 ...
       ...%,'Value', 0 ...
       ,'Checked', 'off' ...
       ,'Text', 'Restrict fit plot to fitted data'...
       ,'MenuSelectedFcn', @fitplotMenu_Callback...
       );



fitsMenu =  uimenu(fh, 'Text', 'Fits');
    evalMenu = uimenu(fitsMenu ...
        ,'Text', '&Show fit results' ...
        ,'MenuSelectedFcn', @evalmenu_Callback ...
        ,'Enable', 'off'...
        );
    setConstantsMenu = uimenu(fitsMenu ...
        ,'Text', 'Set Constants' ...
        ,'MenuSelectedFcn', @setConstantsMenu_Callback ...
        ,'Enable', 'on'...
        );
    extendfitsMenu = uimenu(fitsMenu ...
        ,'Text', '&Enable extended fitting' ...
        ,'MenuSelectedFcn', @extendfitsmenu_Callback ...
        ,'Enable', 'off'...
        ,'Checked','off'...
        );


exportMenu = uimenu(fh, 'Text', 'Export');
    expMenu = uimenu(exportMenu ...
        ,'Text', '&Export data & fits' ...
        ,'MenuSelectedFcn', @exportmenu_Callback ...
        ,'Enable', 'off'...
        );



% if isempty(data)
%     menudata = {'-----'};
% else
%     menudata = cellfun(@(x) x.Properties.Description, data,'UniformOutput', false);
% end

filepmenu = uidropdown(fh ...
       ,'Items', {'-----'} ... %menudata...
       ,'ItemsData', [] ... %(1:length(data))...
       ,'Position', transfUnit([0.1, 0.93, 0.4, 0.05],fh)...
       ,'ValueChangedFcn', @filemenu_Callback ...
       );

axes1 = uiaxes('Parent', fh ...
       ,'Position', transfUnit([0.28, 0.4, 0.7, 0.5], fh)...
       ,'Box', 'on'...
       ,'FontSize', 12 ...,
       ,'Tag', 'plotaxes'...
       );

actualize_plotview();
axes1PlotallLimits = struct('X', [0 1], 'Y', [0 1]);

pb_plotall = uibutton(fh ...
       ,'Position',transfUnit([0.02, 0.835, 0.1, 0.065], fh)...
       ,'Text', 'Plot all'...
       ,'FontSize', 12 ...
       ,'ButtonPushedFcn', @pb_plotall_Callback ...
       );

bg_plottype = uibuttongroup(fh ...'Visible', 'off'...
        ,'Position', transfUnit([0.02 0.62 0.19 0.2], fh)...
        ,'SelectionChangedFcn', @bg_fittype_SelChange ...
        );

    rb_ft1 = uiradiobutton(bg_plottype...
            ,'Position', transfUnit([0.05 0.76 0.9 0.23], bg_plottype)...
            ,'Text', ['F vs. ' char(948)]...
            ,'Enable', 'on'...
            ,'UserData', '1'...
            );
    rb_ft2 = uiradiobutton(bg_plottype...
            ,'Position', transfUnit([0.05 0.52 0.9 0.23], bg_plottype)...
            ,'Text', ['F/EhR vs. ' char(948) '/R']...
            ,'Enable', 'on'...
            ,'UserData', '2'...
            );

    cb_asymptote = uicheckbox(bg_plottype...
       ,'Position', transfUnit([0.12 0.28 0.85 0.22], bg_plottype)...
       ,'FontSize', 9 ...
       ,'Value', 0 ...
       ,'Text', 'show asymptote' ...
       ,'Tooltip', ['Asymptote: F = ' char(960) 'Eh/(3 R^2) * (' char(948) '^3)'] ...
       ,'ValueChangedFcn', @cb_asymptote_Callback ...
       );

     cb_use_fitted_vals = uicheckbox(bg_plottype...
       ,'Position', transfUnit([0.12 0.05 0.85 0.22], bg_plottype)...
       ,'FontSize', 9 ...
       ,'Value', 0 ...
       ,'Text', 'use fitted E values' ...
       ,'Tooltip', ['If available use E from fit to normalize data.'] ...
       );
%     txt_asymp = uicontrol(bg_plottype,...
%         'Units','normalized'...
%        ,'Style','text'...
%        ,'Position',[0.2 0.05 0.8 0.22]...
%        ,'String', 'show asymptote' ...
%        ,'FontSize', 10 ...
%        ,'HorizontalAlignment', 'left' ...
%        ,'TooltipString', ['Asymptote: F = ' char(960) 'Eh/(3 R^2) * (' char(948) '^3)'] ...
%        );


pb_first = uibutton(fh ...
       ,'Position',transfUnit([0.505, 0.93, 0.038, 0.05], fh)...
       ,'Text', char(8676)...
       ,'FontSize', 14 ...
       ,'ButtonPushedFcn', @pb_first_Callback ...
       );  

pb_prev = uibutton(fh...
       ,'Position',transfUnit([0.545, 0.93, 0.038, 0.05], fh)...
       ,'Text', char(8592)...
       ,'FontSize', 14 ...
       ,'ButtonPushedFcn', @pb_prev_Callback ...
       );
   
pb_next = uibutton(fh...
       ,'Position',transfUnit([0.585, 0.93, 0.038, 0.05], fh)...
       ,'Text', char(8594)...
       ,'FontSize', 14 ...
       ,'ButtonPushedFcn', @pb_next_Callback ...
       );

pb_last = uibutton(fh ...
       ,'Position',transfUnit([0.625, 0.93, 0.038, 0.05], fh)...
       ,'Text', cellstr(char(8677))...
       ,'VerticalAlignment', 'top'...
       ,'FontSize', 14 ...
       ,'ButtonPushedFcn', @pb_last_Callback ...
       );

text_actplotno = uilabel(fh ...
       ,'Position', transfUnit([0.67, 0.93, 0.1, 0.05], fh)...
       ,'Text', '/' ...['1/' num2str(length(data))]...
       ,'FontSize', 15 ...
       ,'HorizontalAlignment', 'center' ...
       );



pb_fit = uibutton(fh ...
       ,'Position', transfUnit([0.02, 0.43, 0.1, 0.065], fh)...
       ,'Text', 'Fit curve'...
       ,'FontSize', 12 ...
       ,'ButtonPushedFcn', @pb_fit_Callback...
       );

pb_fitall = uibutton(fh ...
       ,'Position', transfUnit([0.13, 0.43, 0.1, 0.065], fh)...
       ,'Text', 'Fit all'...
       ,'FontSize', 12 ...
       ,'ButtonPushedFcn', @pb_fitall_Callback...
       );

text_fitrun = uilabel(fh ...
       ,'Position', transfUnit([0.24, 0.27, 0.1, 0.04], fh)...
       ,'Text', ''...
       ,'FontSize', 12 ...
       );

tb_setFitConstr_label = uilabel(fh ...
       ,'Position', transfUnit([0.3, 0.30, 0.15, 0.04], fh)...
       ,'Text', 'Fit constraints:'...
       ,'FontSize', 12 ...
       );   
   
tb_setFitConstr = uiswitch(fh ...
       ,'Position', transfUnit([0.5, 0.3, 0.05, 0.05], fh)...
       ,'FontSize', 12 ...
       ,'ValueChangedFcn', @tb_set_FitConstr_Callback...
       ,'ItemsData', {false, true} ...
       ,'Value', false ...
       );

edit_minFitConstr = uieditfield(fh, 'numeric' ...
       ,'Position', transfUnit([0.6 0.29 0.1 0.05], fh)...
       ,'Value', 0 ... num2str(fit_constraints(curr_curve).min*1e9)...
       ,'FontSize', 10 ...
       ,'Enable', 'off'...
       ,'ValueChangedFcn', @edit_minFitConstr_Callback...
       );

edit_maxFitConstr = uieditfield(fh, 'numeric' ...
       ,'Position', transfUnit([0.72 0.29 0.1 0.05], fh)...
       ,'Value', 50 ... num2str(fit_constraints(curr_curve).max*1e9)...
       ,'FontSize', 10 ...
...%       ,'TooltipString', ['Force the fit to cross F = 0, ' char(948) ' = 0'] ...
       ,'Enable', 'off'...
       ,'ValueChangedFcn', @edit_maxFitConstr_Callback...
       );

% pb_setparams = uibutton(fh ...
%        ,'Position', transfUnit([0.83, 0.93, 0.15, 0.065], fh)...
%        ,'Text', 'Set constants'...
%        ,'FontSize', 12 ...
%        ,'ButtonPushedFcn', @pb_set_params_Callback...
%        ,'Tooltip', 'These constants are only used for the normalized plot and to calculate E after a cubic fit.' ...
%        );

panel_res = uipanel('Parent', fh ...
       ,'Title', 'Fit results'...
       ,'Position',transfUnit([0.27, 0.01, 0.71, 0.26], fh) ...
       );

axes2 = uiaxes('Parent', panel_res ...
       ,'Position', transfUnit([0.01, 0.01, 0.98, 0.8], panel_res)...
       ,'FontSize', 12 ...
       ,'Visible','off'...
       ,'Interactions', []...
       );
    axes2.Toolbar.Visible = 'off';

    resultstxt = text(axes2, 0, 0.99 , '','interpreter','tex' ...
        ,'horiz','left','vert','top','FontSize', 10, 'SelectionHighlight', 'on');

    evalstxt = text(axes2, 0.5, 0.99 , '','interpreter','tex' ...
        ,'horiz','left','vert','top','FontSize', 10, 'SelectionHighlight', 'on');


bg_fittype = uipanel(fh ...'Visible', 'off'...
        ,'Position', transfUnit([0.02 0.01 0.24 0.26], fh)...
        ,'Title', 'Choose fit type' ...
        );

% bg_fittype = uibuttongroup(fh ...'Visible', 'off'...
%         ,'Position', transfUnit([0.02 0.01 0.24 0.35], fh)...
%         ,'SelectionChangedFcn', @bg_fittype_SelChange ...
%         ,'Title', 'Choose fit type' ...
%         );

%     rb_ft1 = uiradiobutton(bg_fittype ...
%             ,'Position', transfUnit([0.05 0.7 0.9 0.18], bg_fittype)...
%             ,'Text', 'Point-like indenter (a)'...
%             ,'Enable', 'on'...
%             ,'UserData', 'membranePointIndenterA'...
%             ,'Tooltip', ['With const. N BC'] ...
%             );
%     rb_ft2 = uiradiobutton(bg_fittype ...
%             ,'Position', transfUnit([0.05 0.525 0.9 0.18], bg_fittype)...
%             ,'Text', 'Point-like indenter (b)'...
%             ,'Enable', 'on'...
%             ,'UserData', 'membranePointIndenterB'...
%             ,'Tooltip', ['With const. u BC (nu needed)'] ...
%             );
%     rb_ft3 = uiradiobutton(bg_fittype ...
%             ,'Position', transfUnit([0.05 0.35 0.9 0.18], bg_fittype)...
%             ,'Text', 'circ. indenter'...
%             ,'Enable', 'on'...
%             ,'UserData', 'membraneCircIndenter'...
%             );
%     rb_ft4 = uiradiobutton(bg_fittype...
%             ,'Position', transfUnit([0.05 0.175 0.9 0.18], bg_fittype)...
%             ,'Text', 'cubic' ...
%             ,'Enable', 'on'...
%             ,'UserData', 'cubic'...
%             );
% 
% 	rb_ft5 = uiradiobutton(bg_fittype...
%             ,'Position', transfUnit([0.05 0 0.9 0.18], bg_fittype)...
%             ,'Text', ['k = ' char(8706) 'F/' char(8706) char(948)] ...
%             ,'Enable', 'on'...
%             ,'UserData', 'linear'...
%             );

    cb_ft3 = uicheckbox(bg_fittype ...
       ,'Position', transfUnit([0.5 0.0 0.43 0.18], bg_fittype)...
       ,'FontSize', 10 ...
       ,'Value', 0 ...
       ,'Text', 'fix F0' ...
       ,'Tooltip', ['Force the fit to cross F = 0, ' char(948) ' = 0'] ...
       );
   
%     txt_ft3 = uilabel(bg_fittype ...
%        ,'Position', transfUnit([0.64 0.06 0.3 0.09], bg_fittype)...
%        ,'Text', 'fix F0' ...
%        ,'FontSize', 10 ...
%        ,'HorizontalAlignment', 'left' ...
%        ,'Tooltip', ['Force the fit to cross F = 0, ' char(948) ' = 0'] ...
%        );

    edit_ft3 = uieditfield(bg_fittype, 'numeric' ...
       ,'Position', transfUnit([0.84 0.035 0.15 0.12], bg_fittype)...
       ,'Value', 0 ...
       ,'FontSize', 10 ...
       ,'Tooltip', ['Force the fit to cross F = 0, ' char(948) ' = 0'] ...
       );

    pmenu_fittype = uidropdown(bg_fittype ...
       ,'Items', {fit_models.name}...
       ,'ItemsData', {fit_models.ID}...
       ,'Position', transfUnit([0.01 0.15 0.22 0.05],fh)...
       ,'ValueChangedFcn', @bg_fittype_SelChange ...
       );



%bg_fittype.SelectedObject = rb_ft4;


% pb_export = uicontrol('Units','normalized'...
%        ,'Style','pushbutton'...
%        ,'Position',[0.85, 0.27, 0.13, 0.08]...
%        ,'String', 'Export'...
%        ,'FontSize', 12 ...
%        ,'Callback', @pb_export_Callback...
%        ,'Enable', 'off'...
%        );
   
pb_showFitStats= uibutton(fh ...
       ,'Position', transfUnit([0.83, 0.01, 0.15, 0.065], fh)...
       ,'Text', 'Show FitStats'...
       ,'FontSize', 12 ...
       ,'ButtonPushedFcn', @pb_show_FitStats...
       ,'Enable', 'off'...
       );

%populate with data


if numel(odata) > 0       
    add_data(odata);
end




fh.Visible = 'on';

% toolbarh = findall(fh, 'Type', 'uitoolbar');
% toolsh = findall(toolbarh);
% %delete(toolsh([2, 3, 5, 6, 9, 16, 17]));
% %delete(toolsh([2, 4, 5, 6, 7,8,9]));
% toolsh(~isvalid(toolsh)) = [];
% 
% [img,map] = imread('tool_double_arrow.gif');  %fullfile(matlabroot,...
%             %'toolbox','matlab','icons','tool_double_arrow.gif'));
% % Convert image from indexed to truecolor
% icon = ind2rgb(img,map);
% 
% pt = uipushtool(toolbarh,'TooltipString','Reset zoom',...
%                  'ClickedCallback',@pt_Callback);
% pt.CData = icon;
% 
% 
% for iit=1:length(toolsh)
%     toolsh(iit).HandleVisibility = 'on';
% end
% toolbarh.Children = toolbarh.Children([2 3 4 5 1 6 7 8 9 10]);
% for iit = 1:length(toolbarh.Children)
%     if any( iit == [3 7])
%         toolbarh.Children(1).Separator = 'on';
%     end
%     toolbarh.Children(1).HandleVisibility = 'off';
% end



%%%%%%%%  Callback functions %%%%%%%%%
    function importmenu_callback(hObject, eventdata)
        [files, path]=(uigetfile([current_folder,'/.txt'],'MultiSelect','on'));
        
        if isnumeric(files) && files == 0, return; end   %end execution if user pressed "cancel"
        current_folder = path;
        ol = length(data);

        if ischar(files)==1    %Checks if handles.curves(i).file is a char, which means there's only one file in it
            numFiles = 1;
            files = {files};
        else
            numFiles = length(files);
        end
        
        for ii = 1:numFiles
            fileNo = fopen([path, files{ii}]);
            act_line = fgetl(fileNo);
            if act_line(1) == '#'
                fileType = 'JPK';
            elseif contains(act_line, 'indentation')
                fileType = 'expFits';
            elseif contains(act_line, '_corr')
                fileType = 'Bruker_corr';
            elseif contains(act_line, 'Defl_')
                fileType = 'Bruker';
            end
            fclose(fileNo);

            switch fileType
                case 'Bruker_corr'
                    try
                        M = readtable([path, files{ii}],'Delimiter','\t');
                        
                        new_data = table(M.Height_Sensor_nm_Ex ...
                                    ,M.Separation_nm_Ex ...
                                    ,M.Defl_nm_Ex_corr ...
                                    ,M.Defl_pN_Ex_corr/1000 ...
                                    ,'VariableNames', {'z_pos', 'sep', 'defl', 'F'});
                        new_data.Properties.VariableDescriptions = {'sensor position','separation', 'deflection', 'Force'};
                        new_data.Properties.VariableUnits = {'nm', 'nm', 'nm', 'nN'};                        
                        new_data.Properties.Description = files{ii};                
                    catch
                        errordlg(['Unsupported file type or uncorrected raw data in file: ' files{ii}]); 
                    end
                case 'expFits'
                    topts = detectImportOptions([path files{ii}], 'FileType', 'text');
                    if topts.DataLines(1) > 2
                        topts.VariableUnitsLine = 2;
                        topts.Delimiter = {'\t'};
                    end
                    M = readtable([path, files{ii}], topts);
                    
                    numDatasets = sum(contains(M.Properties.VariableNames, 'indentation'));
                    if numDatasets == 1
                        new_data = table(M.indentation_1, M.force_1, 'VariableNames', {'ind', 'F'});
                        new_data.Properties.VariableUnits = {'nm', 'nN'};
                        new_data.Properties.VariableDescriptions = {'indentation', 'Force'};
                        new_data.Properties.Description = files{ii};
                    elseif numDatasets > 1
                        new_data = cell(numDatasets,1);
                        warndlg('You selected a file with multiple datasets exported from this program. Please specify now the file containing the fit results in order to load the original filenames for the datasets. (Click Cancel if you don''t want that.)');
                        [dbfile, dbpath]=(uigetfile([path,'/.txt'],'MultiSelect','off'));
                        topts = detectImportOptions([dbpath dbfile], 'FileType', 'text');
                        if topts.DataLines(1) > 2
                            topts.VariableNamesLine = 1;
                            topts.VariableUnitsLine = 2;
                            topts.Delimiter = {'\t'};
                        end
                        M_db = readtable([dbpath, dbfile], topts);                        
                        
                        for iii=1:numDatasets
                            new_data{iii} = table(M.(['indentation_' num2str(iii)]), M.(['force_' num2str(iii)]), 'VariableNames', {'ind', 'F'});
                            new_data{iii}.Properties.VariableUnits = {'nm', 'nN'};
                            new_data{iii}.Properties.VariableDescriptions = {'indentation', 'Force'};
                            new_data{iii}.Properties.Description = M_db.filename{iii};
                            new_data{iii}(isnan(new_data{iii}{:,1}) | isnan(new_data{iii}{:,2}) ,:) = [];
                        end
                        
                    else
                        errordlg(['Unsupported file type or uncorrected raw data in file: ' files{ii}]); 
                    end
                    %TODO: Verteile eingelesene Daten (können mehrere sein)
                    %falls nur ein Datensatz: übernimm dateinamen
                    %ansonsten: Warnhinweis und Frage nach "DB"-Datei um
                    %Dateinamen zu Datensätzen zu erhalten.
                    
                otherwise
                  errordlg(['Unsupported file type or uncorrected raw data in file: ' files{ii}]); 
            end
            
            add_data(new_data);
            
        end
        current_folder = path;

        curr_curve = ol + 1;
        actualize_plotview();
    end

    function groupSortData_callback(~, ~)
        groupIdxs = ones(size(data));
        groupName = cell(size(data));
        for ii = 2:length(dataGroups)
            groupIdxs(dataGroups(ii).Idxs) = ii;
            groupName(dataGroups(ii).Idxs) = arrayfun(@(x) dataGroups(ii).Name, (1:numel(dataGroups(ii).Idxs)), "UniformOutput",false);
        end

        dataTable = table(cellfun(@(x) x.Properties.Description, data,'UniformOutput', false), groupIdxs, groupName, ...
            'VariableNames',{'Name', 'Group', 'GroupName'});
        subAppH = GroupAndSortData(dataTable, fh, 'UserData');
        waitfor(subAppH);

        
        if ~isempty(fh.UserData) &&  ~isempty(fh.UserData{1})
            newIdxs = fh.UserData{1};
            data = data(newIdxs);
            filepmenu.Items = filepmenu.Items(newIdxs);
    
            fit_constraints = fit_constraints(newIdxs,:);
            fits = fits(newIdxs,:);
            selectedFit = selectedFit(newIdxs);

            dataGroups(numel(fh.UserData{2}),1).Name = '';
            [dataGroups(:).Idxs] = fh.UserData{2}{:};
            [dataGroups(:).Name] = fh.UserData{3}{:};
            if isrow(dataGroups)
                dataGroups = dataGroups';
            end

            actualize_plotview();
        end
    end

    function closemenu_callback(hObject, eventdata)
        if length(data) == 1
            closeAllmenu_callback();
        else
            data(curr_curve) = [];
            fits(curr_curve,:) = [];
            fit_constraints(curr_curve,:) = [];
            %filepmenu.String = char(cellfun(@(x) x.Properties.Description, data,...
            %    'UniformOutput', false));
            filepmenu.Items = cellfun(@(x) x.Properties.Description, data,'UniformOutput', false);
            filepmenu.ItemsData = (1:length(data));
            %delete from groups:
            isInGroup = cellfun(@(x) any(x == curr_curve), {dataGroups.Idxs});
            dataGroups(isInGroup).Idxs(dataGroups(isInGroup).Idxs == curr_curve) = [];
            
            curr_curve = curr_curve-1;
            actualize_plotview();
        end
    end


    function closeAllmenu_callback(hObject, eventdata)
        data = cell(0);
        fit_constraints = struct('enable', false, 'min', [], 'max', []);
        filepmenu.Items = {'-----'};
        filepmenu.ItemsData = 1;
        fits = cell(0);
        curr_curve = [];
        dataGroups = struct('Idxs', [], 'Name', ''); 
        actualize_plotview();
    end


    function showLegendMenu_callback(~,~)
        if showLegendMenu.Checked == "off"
            showLegendMenu.Checked = "on";
        else
            showLegendMenu.Checked = "off";
        end

        if ~isempty(data)
            actualize_plotview();
        end
    end

    function fitplotMenu_Callback(~,~)
        if fitplotMenu.Checked == "off"
            fitplotMenu.Checked = "on";
        else
            fitplotMenu.Checked = "off";
        end

        if ~isempty(data)
            actualize_plotview();
        end
    end

    function setConstantsMenu_Callback(~, ~)
        newParamValues = paramBox(fh, expParams);
        if ~isempty(newParamValues)
            expParams = newParamValues;
        end
    end



    function exportmenu_Callback(hObject, eventdata)
        %ask what to export
        [ex_data, ex_fits] = ask_export_box(fh);


        if any([ex_data, ex_fits])
            %determine number of existing fits
            iExport = cellfun(@(x) ~isempty(x), fits);
            datanumbers_to_ex= find(iExport);
            %create export variables
            fits_to_export = fits(iExport);
            datanames = cellfun(@(x) x.Properties.Description, data,...
                'UniformOutput', false);
            datanames_to_exp = datanames(iExport);

            for ii = 1:sum(iExport)

                if ex_data      %compose table with curves
                    
                    temp_t = table(fits_to_export{ii}.fitdata.X,fits_to_export{ii}.fitdata.Y,...
                        fits_to_export{ii}.cfits(fits_to_export{ii}.fitdata.X));

                    temp_t.Properties.VariableNames = {['indentation_' num2str(datanumbers_to_ex(ii))],...
                        ['force_' num2str(datanumbers_to_ex(ii))], ['forceFit_' num2str(datanumbers_to_ex(ii))]};
                    temp_t.Properties.VariableUnits = {'nm', 'nN' 'nN'}; 
                    
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

                    no_free_params = length(coeffvalues(fits_to_export{ii}.cfits));
                    no_fixed_params = length(fits_to_export{ii}.coefvals) - no_free_params;
                    no_eval_params = length(fits_to_export{ii}.evalvals);
                    no_param_cols = 2*no_free_params + no_fixed_params + 2*no_eval_params;


                    %construct cellstr row array with names of params and
                    %right to each free param an entry with
                    %'param_name'_err. Do similar for units.
                    param_names = [fits_to_export{ii}.coefs' fits_to_export{ii}.evals'];
                    param_names(2,:) = cellfun(@(x) [x '_err'], param_names, 'UniformOutput', false);
                    param_names = param_names(:)';
                    units = [fits_to_export{ii}.coefdims' fits_to_export{ii}.evaldims'];
                    units(2,:) = units;
                    units = units(:)';
                    cols_to_del = cellfun('isempty', param_names);
                    param_names(cols_to_del) = [];
                    units(cols_to_del) = [];

                    header = [{'dataset number' 'filename' 'fit function'} param_names;...
                                {'' '' ''} units];

                    %include also fit limits
                    header(:,end+1:end+2) = [{'fit_XMinLimit' 'fit_XMaxLimit'}; {'nm' 'nm'}];


                    if ii == 1
                        %for direct text file output:
                        exCell_fits = header;

                        %fot table/xls export:
                        %eresults = [{'filename'} param_names {'fit function'}];

                        eresults = [cellfun(@(x,y) [x '__' y], param_names, ...
                                        strrep(units, '/', '_'), 'UniformOutput', false)... %append dimension to param_name
                                    {'fit_function'}];
                    end

                    param_values = [fits_to_export{ii}.coefvals' fits_to_export{ii}.evalvals'];

                    %bounds = confint(fits_to_export{ii}.cfits);
                    %errors = mean(abs(bounds - ones(2,1)*param_values));
                    param_values(2,:) = [fits_to_export{ii}.coeferrs' fits_to_export{ii}.evalerrs'];
                    param_values = param_values(:)';
                    %{
                    if no_fixed_params > 0
                        param_values = [param_values(:)' fits_to_export{ii}.coefvals(no_free_params+1,end)'];
                    else
                        param_values = param_values(:)';
                    end
                    %}




                    %create cell with fit results
                    %eresults(ii+1,1) = datanames_to_exp(ii);
                    eresults(ii+1,1:length(param_values)) = num2cell(param_values);
                    eresults{ii+1,length(param_values)+1} = ['y = ' formula(fits_to_export{ii}.cfits)];


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

                    fitfun = ['y = ' formula(fits_to_export{ii}.cfits)];
                    if ii~=1 && ~strcmp(fitfun,exCell_fits{end,3})
                        exCell_fits(end+1:end+size(header,1),1:size(header,2)) = header;
                    end

                    exCell_fits(end+1,1:length(param_values)+3) = [num2str(datanumbers_to_ex(ii)) datanames_to_exp(ii) fitfun ...
                        cellfun(@(x) num2str(x), num2cell(param_values), 'UniformOutput', false)];
                     %include also fit limits
                    exCell_fits(end,end-1:end) = {num2str(fit_constraints(ii).min) num2str(fit_constraints(ii).max)};



%                     if ii==sum(iExport)
%                         eresults = cell2table(eresults);
%                         eresults.Properties.VariableNames = {'peak_no',...
%                             'peak_pos', 'peak_height'...
%                             'KuhnLength', 'L_K_error',...
%                             'ContourLength','L_C_error',...
%                             'Segment_k','k_error','FitType'};
%                         eresults.Properties.VariableUnits = ...
%                             {'','nm', 'pN', 'nm', 'nm', 'nm', 'nm', 'N/m', 'N/m', ''};
%                         if strcmp(eresults{ii,10},'WLC-fit')
%                             eresults.Properties.VariableNames(7:8) = ...
%                                 {'AdhesionEnergy', 'E_error'};
%                             eresults.Properties.VariableUnits (7:8) = ...
%                                 {'zJ', 'zJ'};
%                         end
%                     end
                 end
            end
            
%            outp_tab = cell2table(eresults(2:end,:), 'VariableNames', eresults(1,:),...
%                'RowNames', datanames_to_exp);


            %export
            filename = strsplit(data{1}.Properties.Description,'.');
            filename = filename{1};

            if ex_data
                exCell_data = [exTable_data.Properties.VariableNames; exTable_data.Properties.VariableUnits;...
                cellfun(@num2str, table2cell(exTable_data), 'UniformOutput', false)];
            
                [dfilename, pathname] = uiputfile({'/*.txt'},...
                    'Save fits', [current_folder filename '_curves']);
                current_folder = pathname;

                if ~isnumeric(dfilename)
                    fID = fopen([pathname '/' dfilename],'w', 'n', 'UTF-8');
                    formatspec = strjoin(cellfun(@(x) '%s', cell(1,size(exCell_data,2)),'UniformOutput', false),'\t');
                    for iex = 1:size(exCell_data,1)
                        fprintf(fID, [formatspec '\n'], exCell_data{iex,:} );
                    end
                    fclose(fID);
                end
            end
            
            
            if ex_fits
                [ffilename, pathname] = uiputfile({'/*.txt'},...
                    'Save fits', [current_folder filename '_fitsres']);
                current_folder = pathname;

                if ~isnumeric(ffilename)
                    %writetable(outp_tab, [pathname '/' filename]);
                    %status = xlswrite([pathname '/' filename], eresults);
    %                 if isnumeric(status) && status == 0
    %                     msgbox('Error while writing file.','Error');
    %                 end
                    fID = fopen([pathname '/' ffilename],'w', 'n', 'UTF-8');
                    formatspec = strjoin(cellfun(@(x) '%s', cell(1,size(exCell_fits,2)),'UniformOutput', false),'\t');
                    for iex = 1:size(exCell_fits,1)
                        fprintf(fID, [formatspec '\n'], exCell_fits{iex,:} );
                    end
                    fclose(fID);

                end
            end 
        end
    end

    function evalmenu_Callback(hobject, eventdata)
        ShowIndEvalData(fits, dataGroups);
    end

    function extendfitsmenu_Callback(hObject, eventdata)
        newFit_constraints = struct('enable', false, 'min', [], 'max', []);
        if extendfitsMenu.Checked == "off"
            %switch from single stored fit to multiple stored fits (and contraints)
            newFitsVar = cell(length(fits), length(fit_models) );            
            selectedFit = zeros(length(fits),1);

            for ii = 1:length(fits)
                for iiM = 1:numel(pmenu_fittype.ItemsData)
                    newFit_constraints(ii,iiM) = struct('enable', false,...
                        'min', min(data{ii}.ind)*1e-9, ...
                        'max', max(data{ii}.ind)*1e-9);
                end
                if ~isempty(fits{ii})
                    thisFitIdx = find(strcmp(fits{ii}.fitmodel, {fit_models.ID}));
                    newFitsVar{ii,thisFitIdx} = fits{ii};
                    newFit_constraints(ii,thisFitIdx) = fit_constraints(ii);
                    selectedFit(ii) = thisFitIdx;
                end
            end
            extendfitsMenu.Checked = "on";
        else
            %switch to single stored fit and keep only selected fit (and contraints)
            newFitsVar = cell(size(fits,1), 1);
            for ii = 1:length(fits)
                if selectedFit(ii) > 0
                    newFitsVar{ii} = fits{ii, selectedFit(ii)};
                    newFit_constraints(ii,1) = fit_constraints(ii, selectedFit(ii));
                else
                    newFit_constraints(ii,1) = struct('enable', false,...
                        'min', min(data{ii}.ind)*1e-9, ...
                        'max', max(data{ii}.ind)*1e-9);
                end
            end
            selectedFit = ones(size(newFitsVar));
            extendfitsMenu.Checked = "off";
        end
        fits = newFitsVar;
        fit_constraints = newFit_constraints;        
    end

    %buttons etc.

    function filemenu_Callback(hObject, eventdata)
        curr_curve = hObject.Value;
        actualize_plotview();
    end


    function bg_fittype_SelChange(hObject, eventdata)
        if extendfitsMenu.Checked == "on"
            fitTypeIdx = find(strcmp(pmenu_fittype.Value, pmenu_fittype.ItemsData));
            selectedFit(curr_curve) = fitTypeIdx;
            actualize_plotview();
        end
    end

    function pb_prev_Callback(hObject, eventdata)
        curr_curve = max(1, curr_curve-1);
        actualize_plotview();
    end

    function pb_next_Callback(hObject, eventdata)
        curr_curve = min(numel(data), curr_curve+1);
        actualize_plotview();
    end

    function pb_first_Callback(hObject, eventdata)
        curr_curve = 1;
        actualize_plotview();
    end

    function pb_last_Callback(hObject, eventdata)
        curr_curve = numel(data);
        actualize_plotview();
    end

    function pb_set_params_Callback(hObject, eventdata)
        options.Interpreter = 'tex';
        answers = inputdlg({'Film radius \it R \rm / \mu m', 'Film thickness \it h \rm / nm', 'Tip radius / nm', 'Tip cone half angle / deg',... 
             'Poisson ration \nu', '\bf Young''s modulus \it E \rm/ GPa (\rm fit paramter)', '\bf Pre tension \it N_0 \rm / N/m (fit parameter)'},...
            'Set film parameters', [1 60],...
            {num2str(expParams.f_radius.Value),...
            num2str(expParams.f_thick.Value),...
            num2str(expParams.tip_radius.Value),...
            num2str(expParams.tip_angle.Value),...
            num2str(expParams.poisson.Value)...
            num2str(expParams.young.Value)...
            num2str(expParams.prestress.Value)},...
            options);
        if  ~isempty(answers)
            answers = cellfun(@str2double, answers, 'UniformOutput', false);
            [expParams.f_radius.Value, expParams.f_thick.Value, ...
                expParams.tip_radius.Value, expParams.tip_angle.Value, ...
                expParams.poisson.Value, expParams.young.Value, ...
                expParams.prestress.Value] = answers{:};
        end

        if str2double(bg_plottype.SelectedObject.UserData) == 2 && strcmp(axes1.XScale,'log')
            pb_plotall_Callback(pb_plotall, []);
        end
    end

    function pb_plotall_Callback(hObject, eventdata)


        %spr_const_text = data{curr_curve}.Properties.UserData{1};

        selection = bg_plottype.SelectedObject;
        plotselect = str2double(selection.UserData);
        %axes(axes1);
        axes1.Box = 'on';
        cla(axes1);
        axes1.NextPlot = 'add';
        legendstr = '';
        axes1.XLimMode = 'auto';
        axes1.YLimMode = 'auto';
        for ii = 1:length(data)
            plotdata = data{ii};
            switch plotselect
                case 1
                    actX = plotdata.ind;
                    actY = plotdata.F;
                    xlab = 'indentation / nm';
                    ylab = 'Force / nN';
                    scale = 'linear';

                case 2
                    actX = plotdata.ind./(expParams.f_radius.Value*1000);
                    if logical(cb_use_fitted_vals.Value) && ~isempty(fits{ii})  && any(cellfun(@(x) strcmp(x, 'E'), [fits{ii}.evals; fits{ii}.coefs])) %&& ~isempty(fits{ii}.evals) 
                        if ~isempty(fits{ii}.evals) && strcmp(fits{ii}.evals{2}, 'E')
                            E_value = fits{ii}.evalvals(2);
                        else
                            E_value = fits{ii}.cfits.E;
                        end
                        actY = plotdata.F./(E_value*expParams.f_thick.Value*expParams.f_radius.Value*1000); % nN / (GPa * nm * nm)
                    else
                        actY = plotdata.F./(expParams.young.Value*expParams.f_thick.Value*expParams.f_radius.Value*1000); % nN / (GPa * nm * nm)
                    end
                    xlab = 'norm. indentation';
                    ylab = 'norm. force';
                    scale = 'log';
            end
            scatter(axes1, actX, actY ,'.');
            xlabel(axes1, xlab);
            ylabel(axes1, ylab);
            axes1.XScale = scale;
            axes1.YScale = scale;

            if strcmp(legendstr, '')
                legendstr = {plotdata.Properties.Description};
            else legendstr = [legendstr, {plotdata.Properties.Description}];
            end
        end

        axes1PlotallLimits.X = axes1.XLim;
        axes1PlotallLimits.Y = axes1.YLim;
        axes1.XLimMode = 'manual';
        axes1.YLimMode = 'manual';

        if strcmp(scale, 'log')
            asymptote = @(x) pi/3.*x.^3;
            asymp = exp(linspace(log(axes1PlotallLimits.X(1))-1,log(axes1PlotallLimits.X(2))+1));
            asymp(2,:) = asymptote(asymp);
            asymp(:, asymp(2,:) < axes1PlotallLimits.Y(1)/100) = [];
            asymp(:, asymp(2,:) > axes1PlotallLimits.Y(2)*100) = [];
            lh_asym = plot(axes1, asymp(1,:),asymp(2,:), 'r-');
        end
        if ~logical(cb_asymptote.Value)
            lh_asym.Visible = 'off';
        end


        axes1.NextPlot = 'replace';

        lh = legend(axes1, legendstr, 'Visible', 'off');
        lh.Interpreter = 'none';
        lh.Location = 'NorthWest';
        lh.Visible = 'off';
    end

    function cb_asymptote_Callback(hObject, eventdata)
        if strcmp(axes1.XScale, 'log')
            lh_asym = axes1.Children(1);
            if logical(hObject.Value)
                lh_asym.Visible = 'on';
            else
                lh_asym.Visible = 'off';
            end

        end
    end


    function pb_fit_Callback(hObject, eventdata)
        if isempty(data)
            return
        end

        if ~strcmp(eventdata.Source.Text, 'Fit all') && compareParamValuesToDefault
            answ = uiconfirm(fh ...
                , 'The default parameter values for fitting have not been changed. Continue anyway?'...
                , 'Parameter warning' ...
                , 'Icon', 'warning'...
                , 'Options', {'Yes', 'No', 'Change now'});
            switch answ
                case 'Yes'
                case 'No'
                    return
                case 'Change now'
                    setConstantsMenu_Callback([],[]);
                    return
            end
        end

        %selection = bg_fittype.SelectedObject;
        %fitselect = selection.UserData;
        fitselect = pmenu_fittype.Value;
        if extendfitsMenu.Checked == "off"
            fitselectIdx = 1;
        else
            fitselectIdx = find(strcmp(pmenu_fittype.Value, pmenu_fittype.ItemsData),1);
        end
        
        act_data = data{curr_curve};

       fixedcoeffnames = cell(0);
       fixedcoeffdims = cell(0);
       fixedcoeffvals = [];

       paramVals = structfun(@(x) x.Value, expParams, "UniformOutput",false);


        switch fitselect
            case 'linear'  %elastic circular film, small indentations
% 
%                if logical(cb_ft3.Value)
% 
%                    coeffdims = {'N/m'};
%                    fixedcoeffnames = {'F0'};
%                    fixedcoeffdims = {'N'};
%                    %if isstr(edit_ft3.String)
%                    %    fixedcoeffvals = str2double(edit_ft3.String);
%                    %elseif isnumeric(edit_ft3.String)
%                        fixedcoeffvals = edit_ft3.Value;
%                    %end
% 
%                    if fixedcoeffvals == 0
%                        ft = fittype({'x'}, 'coefficients', {'k'});
%                    else
%                        ft = fittype(@(k,x) k.*x + fixedcoeffvals);
%                    end
% 
%                else
%                    ft = fittype({'x', '1'}, 'coefficients', {'k', 'F0'});
%                    coeffdims = {'N/m'; 'N'};
%                end
               
               ft = fittype({'x', '1'}, 'coefficients', {'k', 'F0'});
               fit_param = fitoptions(ft);
               if logical(cb_ft3.Value)
                   %fixedcoeffnames = {'F0'};
                   %fixedcoeffdims = {'N'};
                   %fixedcoeffvals = edit_ft3.Value;
                   fit_param.Lower = [-Inf, edit_ft3.Value];
                   fit_param.Upper = [Inf, edit_ft3.Value];
               else
                   fit_param.Lower = [-Inf, -Inf];
                   fit_param.Upper = [Inf, Inf];
               end
               
               
               ft = fittype({'x', '1'}, 'coefficients', {'k', 'F0'}, 'options', fit_param);
               coeffdims = {'N/m'; 'N'};
               inputs = {};
               inputvals = [];
               inputdims = {};
               

            case 'cubic'    %elastic membrane with pre-stress
               ft = fittype({'x','x^3'}, 'coefficients', {'k','K'});
               coeffdims = {'N/m', 'Pa/m'};
               %for eval calculation
               inputs = {'R_hole', 'r_tip'}';
               inputvals = [paramVals.f_radius*1e-6, paramVals.f_thick*1e-9]';
               inputdims = {'m', 'm'}';
            
            case 'cubic_w_corr'
               ft = fittype({'x','x^3'}, 'coefficients', {'k','K'});
               coeffdims = {'N/m', 'Pa/m'};
               %for eval calculation
               inputs = {'R_hole', 'r_tip'}';
               inputvals = [paramVals.f_radius*1e-6, paramVals.f_thick*1e-9]';
               inputdims = {'m', 'm'}';
               
            case 'SolMem_PointIndent_A'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress, paramVals.young], 'Lower', [0, 0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(N0, E, x) membraneIndent_pointIndent_const_N_d(x*1e-9, N0, E*1e9, paramVals.f_thick*1e-9, paramVals.f_radius*1e-6)*1e9, ...
                    'coefficients',{'N0','E'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m', 'Pa'};
                inputs = {'R_hole', 'thick_film'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.f_thick*1e-9]';
                inputdims = {'m', 'm'}';
                
            case 'SolMem_PointIndent_B'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress, paramVals.young], 'Lower', [0, 0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(N0, E, x) membraneIndent_pointIndent_const_u_d(x*1e-9, N0, E*1e9, paramVals.f_thick*1e-9, paramVals.f_radius*1e-6, paramVals.poisson)*1e9, ...
                    'coefficients',{'N0','E'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m', 'Pa'};
                inputs = {'R_hole', 'thick_film', 'poisson'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.f_thick*1e-9, paramVals.poisson]';
                inputdims = {'m', 'm', ''}';
               
            case 'SolMem_SpheIndent_A'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress, paramVals.young], 'Lower', [0, 0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(N0, E, x) membraneIndent_circIndent_const_N_d(x*1e-9, N0, E*1e9, paramVals.f_thick*1e-9, paramVals.f_radius*1e-6, paramVals.tip_radius*1e-9)*1e9,  ...
                    'coefficients',{'N0','E'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m', 'Pa'};
                inputs = {'R_hole', 'r_tip', 'thick_film'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_radius*1e-9, paramVals.f_thick*1e-9]';
                inputdims = {'m', 'm', 'm'}';


            case 'FluidMem_SpheIndent'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress], 'Lower', [0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(gamma0, x) FluidMembraneIndent.Spherical_F(x*1e-9, gamma0, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6)*1e9,  ...
                    'coefficients',{'gamma0'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m'};
                inputs = {'R_hole', 'r_tip'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_radius*1e-9]';
                inputdims = {'m', 'm'}';

                %restrict fitdata to max possible indentation with this model
                d_max = FluidMembraneIndent.Spherical_d_b(paramVals.tip_radius*1e-9, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6);
                if fit_constraints(curr_curve, fitselectIdx).max > d_max
                    fit_constraints(curr_curve, fitselectIdx).enable = true;
                    fit_constraints(curr_curve, fitselectIdx).max = d_max;
                end

            case 'FluidElasMem_SpheIndent'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress, paramVals.young], 'Lower', [0, 0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(gamma0, E, x) FluidMembraneIndent.Spherical_FE(x*1e-9, E*1e9*paramVals.f_thick*1e-9, gamma0, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6)*1e9,  ...
                    'coefficients',{'gamma0','E'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m','Pa'};
                inputs = {'R_hole', 'r_tip', 'thick_film'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_radius*1e-9, paramVals.f_thick*1e-9]';
                inputdims = {'m', 'm', 'm'}';

                %restrict fitdata to max possible indentation with this model
                d_max = FluidMembraneIndent.Spherical_d_b(paramVals.tip_radius*1e-9, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6);
                if fit_constraints(curr_curve, fitselectIdx).max > d_max
                    fit_constraints(curr_curve, fitselectIdx).enable = true;
                    fit_constraints(curr_curve, fitselectIdx).max = d_max;
                end


            case 'FluidMem_CylIndent'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress], 'Lower', [0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(gamma0, x) FluidMembraneIndent.Cylindrical_F(x*1e-9, gamma0, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6)*1e9,  ...
                    'coefficients',{'gamma0'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m'};
                inputs = {'R_hole', 'r_tip'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_radius*1e-9]';
                inputdims = {'m', 'm'}';

                %restrict fitdata to max possible indentation with this model
                d_max = FluidMembraneIndent.Cylindrical_d_b(paramVals.tip_radius*1e-9, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6);
                if fit_constraints(curr_curve, fitselectIdx).max > d_max
                    fit_constraints(curr_curve, fitselectIdx).enable = true;
                    fit_constraints(curr_curve, fitselectIdx).max = d_max;
                end

            case 'FluidElasMem_CylIndent'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress, paramVals.young], 'Lower', [0, 0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(gamma0, E, x) FluidMembraneIndent.Cylindrical_FE(x*1e-9, E*1e9*paramVals.f_thick*1e-9, gamma0, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6)*1e9,  ...
                    'coefficients',{'gamma0','E'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m','Pa'};
                
                %restrict fitdata to max possible indentation with this model
                d_max = FluidMembraneIndent.Cylindrical_d_b(paramVals.tip_radius*1e-9, paramVals.tip_radius*1e-9, paramVals.f_radius*1e-6);
                if fit_constraints(curr_curve, fitselectIdx).max > d_max
                    fit_constraints(curr_curve, fitselectIdx).enable = true;
                    fit_constraints(curr_curve, fitselectIdx).max = d_max;
                end
                inputs = {'R_hole', 'r_tip', 'thick_film'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_radius*1e-9, paramVals.f_thick*1e-9]';
                inputdims = {'m', 'm', 'm'}';

            case 'FluidMem_ConicIndent'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress], 'Lower', [0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(gamma0, x) FluidMembraneIndent.Conical_F(x*1e-9, gamma0, paramVals.tip_angle/180*pi, paramVals.f_radius*1e-6)*1e9,  ...
                    'coefficients',{'gamma0'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m'};
                inputs = {'R_hole', 'alpha_tip'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_angle]';
                inputdims = {'m', 'grad'}';

            case 'FluidElasMem_ConicIndent'
                fit_param = fitoptions('Method','NonlinearLeastSquares','StartPoint',[paramVals.prestress, paramVals.young], 'Lower', [0, 0]);
                %fit_param.Normal = 'on';
                ft = fittype(@(gamma0, E, x) FluidMembraneIndent.Conical_FE(x*1e-9, E*1e9*paramVals.f_thick*1e-9, gamma0, paramVals.tip_angle/180*pi, paramVals.f_radius*1e-6)*1e9,  ...
                    'coefficients',{'gamma0','E'}, 'independent', 'x', 'options', fit_param);
                coeffdims = {'N/m','Pa'};
                inputs = {'R_hole', 'alpha_tip', 'thick_film'}';
                inputvals = [paramVals.f_radius*1e-6, paramVals.tip_angle, paramVals.f_thick*1e-9]';
                inputdims = {'m', 'grad', 'm'}';

        end
        
        fitdata = table(act_data.ind, act_data.F, 'VariableNames', {'X','Y'});
        fitdata.Properties.Description = act_data.Properties.Description;
        if fit_constraints(curr_curve,fitselectIdx).enable
            iLeftBorder = find((act_data.ind*1e-9 > fit_constraints(curr_curve, fitselectIdx).min),1 ,'first');
            iRightBorder = find((act_data.ind*1e-9 < fit_constraints(curr_curve, fitselectIdx).max),1 , 'last');
        else
            iLeftBorder = 1;
            iRightBorder = height(act_data);
        end

        %fitdata = table(act_data.ind(iLeftBorder:iRightBorder), act_data.F(iLeftBorder:iRightBorder), 'VariableNames', {'X','Y'});

        fitdata = fitdata(iLeftBorder:iRightBorder,:);
        %get data from plot and sort ascending

        %tic
        if contains(fitselect, 'Mem_') && ~strcmp(eventdata.Source.Text, 'Fit all')
            tic
            wbh = uiprogressdlg(fh, 'Message',['Fitting dataset ' filepmenu.Items{curr_curve}]...
                ,'Title','Fitting in progress' ...
                ...,'Visible', 'off'...
                ,'Indeterminate', 'on');
            %wbh.Position = getnicedialoglocation(wbh.Position, wbh.Units);
            %wbh.Children.Title.Interpreter = 'none';
            %wbh.Visible = 'on';
        end
         try
            if contains(fitselect, 'Mem_')
                [fitresults, gofs, output] = fit(fitdata.X, fitdata.Y, ft);
            else
                [fitresults, gofs, output] = fit(fitdata.X*1e-9, fitdata.Y*1e-9, ft);
            end
            
        catch ME
            uialert(fh, ME.message, 'Error while fitting');
            return
        end
        %toc
        if contains(fitselect, 'Mem_') && ~strcmp(eventdata.Source.Text, 'Fit all')
            toc
            close(wbh);
        end

        %fitplotdata(fitplotdata.Y<0 | fitplotdata.Y > 1.3*cdata.Y(iRightBorder) ...
        %    | fitplotdata.X>max(cont_l,cdata.X(iRightBorder)),:)=[];

        %fitplotdata.Properties.UserData = {fitresults, [fittype_str; parameter_str; dimension_str]};
        %peaks(curr_curve).fits{curr_peak} = fitplotdata;


        bounds = confint(fitresults);
        errors = mean(abs(bounds - ones(2,1)*coeffvalues(fitresults)));

        newFit = struct();

        newFit.cfits = fitresults;
        newFit.fit_gof = gofs;
        %format all as column vectors! (only one column!!!)
        newFit.coefs = [coeffnames(fitresults); fixedcoeffnames'];
        newFit.coefdims = [coeffdims'; fixedcoeffdims'];
        newFit.coefvals = [coeffvalues(fitresults)'; fixedcoeffvals'];
        newFit.coeferrs = [errors'; NaN(length(fixedcoeffvals),1)];
        newFit.evals = [];
        newFit.evaldims = [];
        newFit.evalvals = [];
        newFit.evalerrs = [];
        newFit.fitdata = fitdata;
        newFit.fitmodel = fitselect;
        newFit.fitmodelLong = pmenu_fittype.Items{strcmp(fitselect, pmenu_fittype.ItemsData)};
        newFit.fitstats = struct('GoF', gofs, 'out', output, 'Fit', fitresults, 'Data', fitdata);
        
        if strcmp(fitselect,'linear')
%             newFit.coefdims{2} = 'N';
%             newFit.coefvals(2) = fits{curr_curve}.coefvals(2) * 1e-9;
%             newFit.coeferrs(2) = fits{curr_curve}.coeferrs(2) * 1e-9;
        end

        if strcmp(fitselect,'cubic')
            newFit.evals = {'gamma0', 'E'}';
            newFit.evalvals = [newFit.coefvals(1)/pi, ...
                newFit.coefvals(2) * 3 * (paramVals.f_radius*1e-6)^2 /(pi* paramVals.f_thick*1e-9)]';
            newFit.evalerrs = newFit.evalvals./newFit.coefvals .* errors';
            newFit.evaldims = {'N/m', 'Pa'}';
            %newFit.coefdims = {'N/m', 'Pa/nm'}';
            %newFit.coefvals = newFit.coefvals';
            %newFit.coeferrs = newFit.coeferrs';
        end

        if strcmp(fitselect,'cubic_w_corr')
            newFit.evals = {'gamma0', 'E'}';
            newFit.evalvals = [newFit.coefvals(1)/2/pi*log(paramVals.f_radius*1e-6/paramVals.tip_radius/1e-9), ...
                newFit.coefvals(2) * (paramVals.f_radius*1e-6)^2 /(paramVals.f_thick*1e-9 * (0.867 + 0.2773*paramVals.poisson + 0.8052*paramVals.poisson^2) )]'; 
                %see Vella & Davidovitch, Soft Matter, 2017, 13, 2264
            newFit.evalerrs = newFit.evalvals./newFit.coefvals .* errors';
            newFit.evaldims = {'N/m', 'Pa'}';
        end
        
        if contains(fitselect,'Mem_') && numel(newFit.coefvals) > 1 
             newFit.coefvals(2) = newFit.coefvals(2) * 1e9;
             newFit.coeferrs(2) = newFit.coeferrs(2) * 1e9;
        end

        newFit.inputs = inputs;
        newFit.inputvals = inputvals;
        newFit.inputdims = inputdims;

        if extendfitsMenu.Checked == "off"
            fits{curr_curve} = newFit;
        else
            %if was started from plotall: 
            %if ~strcmp(eventdata.Source.Text, 'Fit all')
            fits{curr_curve, fitselectIdx} = newFit;
            selectedFit(curr_curve) = fitselectIdx;
            %else
            % fits{curr_curve, selectedFit(curr_curve)} = newFit;
            %end
        end
        
        

        if ~strcmp(eventdata.Source.Text, 'Fit all')
            actualize_plotview();
        end
    end

    function pb_fitall_Callback(hObject, eventdata)
        num_data = length(data);
        act_curve = curr_curve;

        if compareParamValuesToDefault
            answ = uiconfirm(fh ...
                , 'The default parameter values for fitting have not been changed. Continue anyway?'...
                , 'Parameter warning' ...
                , 'Icon', 'warning'...
                , 'Options', {'Yes', 'No'});
            if ~logical(strcmp(answ, 'Yes'))
                return
            end
        end

        if any(cellfun(@(x) ~isempty(x), fits))
            answ = uiconfirm(fh ...
                , 'This will overwrite already existing fits. Continue anyway?'...
                , 'Overwrite fits?' ...
                , 'Options', {'Yes', 'No'});
            if ~logical(strcmp(answ, 'Yes'))
                return
            end
        end

        wbh = uiprogressdlg(fh, 'Message',['Fitting dataset ' filepmenu.Items{curr_curve}]...
                ,'Title','Fitting in progress' ...
                ...,'Visible', 'off'...
                ,'Value', 0);

        for ifit = 1:num_data
            curr_curve = ifit;
            text_fitrun.Text = [num2str(ifit) '/' num2str(num_data)];
            pb_fit_Callback(pb_fit, eventdata);
            wbh.Value = ifit/num_data;
            wbh.Message = ['Fitting dataset ' filepmenu.Items{curr_curve}];
            %drawnow;
            %pause(0.2);
        end
        close(wbh);

        curr_curve = act_curve;
        actualize_plotview();
        text_fitrun.Text = '';
    end

    function tb_set_FitConstr_Callback(hObject, eventdata)
        if extendfitsMenu.Checked == "off"
            fitselectIdx = 1;
        else
            fitselectIdx = find(strcmp(pmenu_fittype.Value, pmenu_fittype.ItemsData),1);
        end
        fit_constraints(curr_curve,fitselectIdx).enable = hObject.Value;
        actualize_plotview();
    end

    function edit_minFitConstr_Callback(hObject, eventdata)
        if extendfitsMenu.Checked == "off"
            fitselectIdx = 1;
        else
            fitselectIdx = find(strcmp(pmenu_fittype.Value, pmenu_fittype.ItemsData),1);
        end
        fit_constraints(curr_curve,fitselectIdx).min = edit_minFitConstr.Value*1e-9;
        edit_minFitConstr.Value= fit_constraints(curr_curve,fitselectIdx).min*1e9;
        actualize_plotview();
    end

    function edit_maxFitConstr_Callback(hObject, eventdata)
        if extendfitsMenu.Checked == "off"
            fitselectIdx = 1;
        else
            fitselectIdx = find(strcmp(pmenu_fittype.Value, pmenu_fittype.ItemsData),1);
        end
        fit_constraints(curr_curve,fitselectIdx).max = edit_maxFitConstr.Value*1e-9;
        edit_maxFitConstr.Value= fit_constraints(curr_curve,fitselectIdx).max*1e9;
        actualize_plotview();
    end     


    function pb_show_FitStats(hObject, eventdata)
        fh_t = ShowFitStats(fits{curr_curve, selectedFit(curr_curve)}.fitstats);
        fh_t.FitStatisticsUIFigure.Name = [fh_t.FitStatisticsUIFigure.Name ': ' data{curr_curve}.Properties.Description];
    end


%%%%%%% additional helper functions %%%%%%%
    function add_data(newData)
        dataL = length(data);
        if istable(newData)
            newData = {newData};
        end

        if extendfitsMenu.Checked == "off"
            modelNum = 1;
        else
            modelNum = numel(pmenu_fittype.ItemsData);
        end
        
        newFitConst = struct('enable', false, 'min', [], 'max', []);
        
        for ii = 1:length(newData)
            if ~any(contains(newData{ii}.Properties.VariableNames, 'ind')) && any(contains(newData{ii}.Properties.VariableNames, 'sep'))
                newData{ii} = newData{ii}(newData{ii}.sep<0,:);
                newData{ii}.ind = -newData{ii}.sep;
                newData{ii}.Properties.VariableDescriptions{end} = 'indentation';
                newData{ii}.Properties.VariableUnits{end} = 'nm';
                newData{ii} = sortrows(newData{ii},'ind','ascend');
            end

            nanlines = all(isnan(table2array(newData{ii})),2);
            newData{ii}(nanlines,:) = [];


            for iiM = 1:modelNum
                newFitConst(ii,iiM).enable = false;
                newFitConst(ii,iiM).min = min(newData{ii}.ind)*1e-9;
                newFitConst(ii,iiM).max = max(newData{ii}.ind)*1e-9;
            end
        end

        
        if isempty(data)
            data = newData;
            filepmenu.Items = cellfun(@(x) x.Properties.Description, newData,...
                'UniformOutput', false);
            curr_curve = 1;
            if extendfitsMenu.Checked == "off"
                selectedFit = ones(length(newData),1);
            else
                selectedFit = zeros(length(newData),1);
            end
            fits = cell(length(data), modelNum);
            fit_constraints = newFitConst;

        else
            data = [data; newData];            
            filepmenu.Items = [filepmenu.Items, cellfun(@(x) x.Properties.Description, newData,...
                'UniformOutput', false)];
            curr_curve = dataL+1;
            if extendfitsMenu.Checked == "off"
                selectedFit = [selectedFit; ones(length(newData),1)];
            else
                selectedFit = [selectedFit; zeros(length(newData),1)];
            end

            fits{end+length(newData), modelNum} = '';
            fit_constraints = [fit_constraints; newFitConst];
        end
        filepmenu.ItemsData = (1:length(data));
        dataGroups(1).Idxs = [dataGroups(1).Idxs; dataL+(1:numel(newData))];
    end

    function actualize_plotview()
        if isempty(curr_curve)
            text_actplotno.Text = '0/0';
            edit_minFitConstr.Value = 0;
            edit_maxFitConstr.Value = 50;

            tb_setFitConstr.Value = false;

            edit_minFitConstr.Enable = 'off';
            edit_maxFitConstr.Enable = 'off';
            %tb_setFitConstr.String = 'Enable fit constraints';
            closeMenu.Enable = 'off';
            closeAllMenu.Enable = 'off';
            cla(axes1);
            print_fitresults();
            return
        else
            extendfitsMenu.Enable = "on";
            closeMenu.Enable = 'on';
            closeAllMenu.Enable = 'on';

            if extendfitsMenu.Checked == "off"
                modelSelectIdx = 1;
            else
                modelSelectIdx = find(strcmp(pmenu_fittype.Value, pmenu_fittype.ItemsData),1);
            end
        end
        filepmenu.Value = curr_curve;

        text_actplotno.Text = [num2str(curr_curve) '/' num2str(numel(data))];

        edit_minFitConstr.Value = fit_constraints(curr_curve,modelSelectIdx).min*1e9;
        edit_maxFitConstr.Value = fit_constraints(curr_curve,modelSelectIdx).max*1e9;

        tb_setFitConstr.Value = fit_constraints(curr_curve,modelSelectIdx).enable;

        if fit_constraints(curr_curve,modelSelectIdx).enable
            edit_minFitConstr.Enable = 'on';
            edit_maxFitConstr.Enable = 'on';
            %tb_setFitConstr.String = 'Disable fit constraints';
        else
            edit_minFitConstr.Enable = 'off';
            edit_maxFitConstr.Enable = 'off';
            %tb_setFitConstr.String = 'Enable fit constraints';
        end

        plot_actdata();
        print_fitresults();
    end

    function plot_actdata(varargin)
        %actualizes the plot with the given data

        % check if export button can be activated:
        if logical(sum(cellfun(@(x) ~isempty(x), fits(:))))
            %pb_export.Enable = 'on';
            expMenu.Enable = 'on';
            evalMenu.Enable = 'on';
        else
            %pb_export.Enable = 'off';
            expMenu.Enable = 'off';
            evalMenu.Enable = 'off';
        end
        
        if extendfitsMenu.Checked == "off" || selectedFit(curr_curve) == 0
            modelIdx = 1;
        else
            modelIdx = selectedFit(curr_curve);
        end

        thisFit = fits{curr_curve, modelIdx};

        if isempty(thisFit)
            pb_showFitStats.Enable = 'off';
        else
            pb_showFitStats.Enable = 'on';
        end

        plotdata = data{curr_curve};
        if nargin > 0
            keep_limits = ~varargin{1};
        else
            keep_limits = false;
        end

        limits = [axes1.XLim; axes1.YLim];
        lhs = axes1.Children;
        delete(lhs);
        %axes(axes1);
        drawnow limitrate
        scatter(axes1, plotdata.ind, plotdata.F ,'.b');
        axes1.Box = 'on';
        
        if ~isempty(plotdata.Properties.UserData)
            legendstr = {[plotdata.Properties.Description , ' ', plotdata.Properties.UserData{1}]};
        else
            legendstr = {plotdata.Properties.Description};
        end

        %plot fit

        if ~isempty(thisFit)
            axes1.NextPlot = 'add';
            if logical(fitplotMenu.Checked == "on")
                %hold on
                if  contains(thisFit.fitmodel, 'Mem_')
                    yFitData = thisFit.cfits(thisFit.fitdata.X);
                else
                    yFitData = thisFit.cfits(thisFit.fitdata.X*1e-9)*1e9;
                end
                xFitData = thisFit.fitdata.X;%*1e9;
                
                %delete(pfh(1));
                %hold off
            else
                %hold on
                if  contains(thisFit.fitmodel, 'Mem_')
                    yFitData = thisFit.cfits(linspace(axes1.XLim(1),axes1.XLim(2),50)');
                else
                    yFitData = thisFit.cfits(linspace(axes1.XLim(1),axes1.XLim(2),50)*1e-9)*1e9;
                end
                xFitData = linspace(axes1.XLim(1),axes1.XLim(2),50);
                %plot(fits{curr_curve}.cfits);
                %hold off
            end
            pfh = plot(axes1, xFitData, yFitData,'-r');
            legendstr = [legendstr; {'fit'}];
        end
        
        label_axes(plotdata, find(strcmp(plotdata.Properties.VariableNames, 'ind')),find(strcmp(plotdata.Properties.VariableNames, 'F')));

        if showLegendMenu.Checked == "on"
            lh = legend(axes1, [char(legendstr)]);
            lh.Interpreter = 'none';
            lh.Location = 'NorthWest';
        else
            legend(axes1, 'hide');
        end
        if keep_limits
            axes1.XLim = limits(1,:);
            axes1.YLim = limits(2,:);
        end
        

        if fit_constraints(curr_curve, modelIdx).enable
            axes1.NextPlot = 'add';
            th = stem(axes1, fit_constraints(curr_curve, modelIdx).min*1e9, max(plotdata.F),'>m','MarkerSize',5,'MarkerFaceColor', 'm', 'LineWidth', 1.5);
            th.DisplayName = 'contraints';
            th = stem(axes1, fit_constraints(curr_curve, modelIdx).max*1e9, max(plotdata.F),'<m','MarkerSize',5,'MarkerFaceColor', 'm', 'LineWidth', 1.5);
            th.Annotation.LegendInformation.IconDisplayStyle = 'off';
            %th.DisplayName = 'upper contraint';
            axes1.NextPlot = 'replace';
        end
    end


    function label_axes(act_data, xcol, ycol)
        axes1.XLabel.String = [act_data.Properties.VariableDescriptions{xcol} ' / '...
                    act_data.Properties.VariableUnits{xcol}];
        %axes1.XLabel.String = ['indentation' ' / '...
        %            act_data.Properties.VariableUnits{xcol}];
        axes1.YLabel.String = [act_data.Properties.VariableDescriptions{ycol} ' / '...
                    act_data.Properties.VariableUnits{ycol}];

        if ~strcmp(act_data.Properties.VariableUnits{xcol},'nm') ...
                || ~strcmp(act_data.Properties.VariableUnits{ycol},'nN')
            warndlg('Dimensions are not given as ''nm'' and ''nN''. Please note that fit results might be incorrect.',...
                'Incorrect units used.', 'modal');
        end
    end





    function print_fitresults()
        if isempty(fits) || selectedFit(curr_curve) == 0 || isempty(fits{curr_curve, selectedFit(curr_curve)})
            resultstxt.String = '';

        else %print fit parameters
            act_fit = fits{curr_curve, selectedFit(curr_curve)};
            parameters = [act_fit.coefs; act_fit.evals];
            parameters(:,2) = [act_fit.coefdims; act_fit.evaldims];
            param_values = [act_fit.coefvals; act_fit.evalvals];
            errors = [act_fit.coeferrs; act_fit.evalerrs];

            num_coefs = length(act_fit.coefvals);
            num_evals = length(act_fit.evalvals);

            unitprefix = {'P' 'T' 'G', 'M', 'k', '', 'm', '\mu', 'n', 'p', 'f', 'a'};
            prefix_exponent = [15 12 9 6 3 0 -3 -6 -9 -12 -15 -18];
            exponent = 3*floor(log10(param_values)/3);
            for ii = 1:length(exponent)
                if exponent(ii) < -18
                    exponent(ii) = -18;
                elseif exponent(ii) > 15
                    exponent(ii) = 15;
                end
                parameters{ii,2} = [unitprefix{exponent(ii) == prefix_exponent}, parameters{ii,2}];
                param_values(ii) = param_values(ii) .* 10.^(-exponent(ii));
                errors(ii) = errors(ii) .* 10.^(-exponent(ii));
            end
            
            %!! coeffvalues() and confint() return row vectors. all others ar formatted
            %as column vectors!
            %{
            bounds = confint(act_fit.cfits);
            errors = mean(abs(bounds - ones(2,1)*coeffvalues(act_fit.cfits)));
            no_fixed_pars = max(size(act_fit.coefvals) - size(coeffvalues(act_fit.cfits)'));
            if no_fixed_pars > 0
                errors(end+1:end + no_fixed_pars,1) = NaN;
            end
            errors = reshape(errors,length(errors),1);
            %}

            no_dig = ceil(-log10(abs(errors./param_values))); %no of significant digits (according to error)
            first_dig = ceil(log10(abs(param_values)));
            prec = max(-first_dig+1,max(0,no_dig-first_dig+1))+1;      %no of significant digits after separator

            %for fixed values:
            length_after_sep = cellfun(@(x) length(num2str(x)), num2cell(param_values)) ... %whole length;
                        - max(1,floor(log10(param_values)+1))-1; %-digits in front of sep (at least 1) - dot
            length_after_sep = max(0, length_after_sep);

%             for ist = 1:length(param_values)
%                 length_after_sep(ist) = find(double(num2str(param_values(ist)))~=double('0'), 1, 'last')...
%                     - strfind(num2str(param_values(ist)),'.');
%             end
            prec(isnan(errors)) = length_after_sep(isnan(errors));

            results_cell = [parameters(:,1)'; num2cell(prec)'; num2cell(param_values)'; num2cell(prec)'; num2cell(errors)'; parameters(:,2)'];
            coefs_cell = results_cell(:,1:num_coefs);
            evals_cell = results_cell(:,num_coefs+1:end);

            str_length_co = max(arrayfun(@(x) length(x{1}), coefs_cell(1,:)) );
            str_length_ev = max(arrayfun(@(x) length(x{1}), evals_cell(1,:)) );
            coefs_text = sprintf(['\\it %' num2str(str_length_co) 's \\rm = %.*f +/- %.*f %s \n'], coefs_cell{:});
            evals_text = sprintf(['\\it %' num2str(str_length_ev) 's \\rm = %.*f +/- %.*f %s \n'], evals_cell{:});
            coefs_text = strrep(coefs_text, '+/- NaN ', '(fixed) ');

            gof_text = ['R^2 = ' num2str(act_fit.fit_gof.rsquare) '   RMSE = ' num2str(act_fit.fit_gof.rmse)];
            model_formula = [' (' formula(act_fit.cfits) ')'];
            if contains(act_fit.fitmodel, 'membrane')
                model_formula = '';
            end
            
            model_txt = ['Fit model:  ' act_fit.fitmodel  model_formula ];
            model_txt = strrep(model_txt, '_', '\_');
            resultstxt.String = char({model_txt ; gof_text; ''; coefs_text});%[fittype_str; results_text];
            resultstxt.FontSize = 12;

            if num_evals ~= 0
                evalstxt.String =  char({'evaluated values:'; evals_text});
            else
                evalstxt.String = '';
            end
            evalstxt.FontSize = 12;
            %{
            switch formula(act_fit.cfits)
                case 'k*x + K*x^3'
                    young_value = param_values(2) * 3 * (exp_param.f_radius*1000)^2 /(pi* exp_param.f_thick);
                    young_error = young_value/param_values(2) * errors(2);
                    young_txt = {'evaluated values: '; ['\it E \rm = ' num2str(young_value) ' +/- ' num2str(young_error) ' GPa']};
                    evalstxt.String = char(young_txt);
                    evalstxt.FontSize = 12;
                otherwise
                    evalstxt.String = '';
                    evalstxt.FontSize = 12;
            end
            %}

        end
    end

    function val = compareParamValuesToDefault()
        %returns true if all parameters still have their default values,
        %false if at least one has been changed.
        allParams = fieldnames(paramDefValues);
        val = true;
        for ii = 1:length(allParams)
            val = val & (paramDefValues.(allParams{ii}) == expParams.(allParams{ii}).Value);
        end
    end




    function figure_size = getnicedialoglocation(figure_size, figure_units)
    % adjust the specified figure position to fig nicely over GCBF
    % or into the upper 3rd of the screen

    %  Copyright 1999-2011 The MathWorks, Inc.

    %%%%%% PLEASE NOTE %%%%%%%%%
    %%%%%% This file has also been copied into:
    %%%%%% matlab/toolbox/ident/idguis
    %%%%%% If this functionality is changed, please
    %%%%%% change it also in idguis.
    %%%%%% PLEASE NOTE %%%%%%%%%

    parentHandle = gcbf;
    convertData.destinationUnits = figure_units;
    convertData.reference = 0;
    if ~isempty(parentHandle)
        % If there is a parent figure
        convertData.hFig = parentHandle;
        convertData.size = get(parentHandle,'Position');
        convertData.sourceUnits = get(parentHandle,'Units');
        c = [];
    else
        % If there is no parent figure, use the root's data
        % and create a invisible figure as parent
        convertData.hFig = figure('visible','off');
        convertData.size = get(0,'ScreenSize');
        convertData.sourceUnits = get(0,'Units');
        c = onCleanup(@() close(convertData.hFig));
    end

    % Get the size of the dialog parent in the dialog units
    container_size = hgconvertunits(convertData.hFig, convertData.size ,...
        convertData.sourceUnits, convertData.destinationUnits, convertData.reference);

    delete(c);

    figure_size(1) = container_size(1)  + 1/2*(container_size(3) - figure_size(3));
    figure_size(2) = container_size(2)  + 2/3*(container_size(4) - figure_size(4));
    end

end

function [ex_data, ex_results] = ask_export_box(parent)

    ex_data = 0;
    ex_results = 1;
    
    if ispc
        ThisFontSize = 10;
    elseif isunix
        ThisFontSize = 10;
    end
    
%     parPos = parent.Position;
%     midparPos = parPos(1:2) + parPos(3:4)/2;
%     
%     FigPos(3:4) = [200 140];
%     FigPos(1:2) = midparPos - FigPos(3:4)/2;
    transfUnit = @(relPos, Parent) (reshape((reshape(relPos, 2,2)'.* Parent.Position(3:4))', 1 ,4));
    
    askboxh = uifigure(parent, ...
                 'Visible','off' ...
                ...,'Position',FigPos... %[360,500,450,285]);
                ...,'DockControls', 'off'...
                ...,'MenuBar', 'none'...
                ...,'WindowStyle', 'modal'...
                );
    askboxh.Position(3:4) = [200 140];
    askboxh.Name = 'Export files';
    
    text_thres = uicontrol(askboxh...
           ,'Units','normalized'...
           ,'Style','text'...
           ,'String', 'Select which files to export:'...
           ,'HorizontalAlignment', 'center'...
           ,'Position',[0.1, 0.8, 0.9, 0.15]...
           ,'FontSize', ThisFontSize ...
           );
    
    pb_OK = uibutton(askboxh, 'push'...
           ,'Position', transfUnit([0.13, 0.05, 0.35, 0.2], askboxh)...
           ,'Text', 'OK'...
           ,'ButtonPushedFcn', @pb_OK_CB ...
           ...,'FontSize', ThisFontSize ...
           );
    
    pb_cancel = uibutton(askboxh, 'push'...
           ,'Position', transfUnit([0.52, 0.05, 0.35, 0.2], askboxh) ...
           ,'Text', 'Cancel'...
           ,'ButtonPushedFcn', @pb_cancel_CB ...
           ...,'FontSize', ThisFontSize ...
           );
    
    cb_exdata = uicontrol(askboxh, 'Units','normalized'...
           ,'Style','checkbox'...
           ,'String', 'Export curves'...
           ,'Position',[0.2, 0.6, 0.7, 0.1]...
           ,'FontSize', ThisFontSize ...
           ,'Value', ex_data ...
           ,'Callback', @cb_exdata_CB ...
           ,'Enable', 'on'...
           );
    
    cb_exres = uicontrol(askboxh, 'Units','normalized'...
           ,'Style','checkbox'...
           ,'String', 'Export fit results'...
           ,'Position',[0.2, 0.4, 0.7, 0.1]...
           ,'FontSize', ThisFontSize ...
           ,'Value', ex_results ...
           ,'Callback', @cb_exres_CB...
           );
    
    askboxh.Visible = 'on';
    pb_cancel.Visible = 'on';
    
    waitfor(askboxh);

    function pb_OK_CB(hObject, eventdata)
        %ex_data = 0; %delete again if data export works
        delete(askboxh);
    end

    function pb_cancel_CB(hObject, eventdata)
        ex_data = 0;
        ex_results = 0;
        delete(askboxh);
    end

    function cb_exdata_CB(hObject, eventdata)
        ex_data = hObject.Value;
    end

    function cb_exres_CB(hObject, eventdata)
        ex_results = hObject.Value;
    end
end

function newParams = paramBox(parent, Params)
   %input: parent uifigure handle, structure with parameter values
   paramNames = fieldnames(Params);
   paramTexts = structfun(@(x) [x.Name ' / ' x.Unit], Params, "UniformOutput",false);

   newParams = Params;

   lineHeight = 30;
   editBoxW = 60;
   letterW = 8;
   BoxSize = [ max(150, (max(structfun(@length, paramTexts)) * letterW + editBoxW + 10)), ...
       (numel(paramNames)+1) * lineHeight + 60];

   transfUnit = @(relPos, Parent) (reshape((reshape(relPos, 2,2)'.* Parent.Position(3:4))', 1 ,4));

   paramBoxh = uifigure('Visible', true, 'Name', 'Set constants');
   paramBoxh.Position(3:4) = BoxSize;
   paramBoxh.Position(1:2) = parent.Position(1:2) + (parent.Position(3:4)-BoxSize)./2;

    pb_OK = uibutton(paramBoxh, 'push' ...
           ,'Position',[0.13, 10, 70, 28]...
           ,'Text', 'OK'...
           ,'ButtonPushedFcn', @pb_OK_CB ...
           );
    
    pb_cancel = uibutton(paramBoxh, 'push' ...
           ,'Position',[0.52, 10, 0.35, 28]...
           ,'Text', 'Cancel'...
           ,'ButtonPushedFcn', @pb_cancel_CB ...
           );

    pb_OK.Position([1 3]) = [0.13, 0.35] .* BoxSize(1);
    pb_cancel.Position([1 3]) = [0.52, 0.35] .* BoxSize(1);
    uilabel(paramBoxh ...
            ,"Position", [5, BoxSize(2)- lineHeight-5, BoxSize(1) - 10, lineHeight-5]...
            ,"Text", 'Experimental (constant) parameters'...
            ,'FontWeight', "bold" ...
            );

    for ii = 1:(numel(paramNames)-1)
        if ii<6
            lineNo = ii+1;
        else
            lineNo = ii+2;
        end

        if ii == 6
            uilabel(paramBoxh ...
            ,"Position", [5, BoxSize(2)- (lineNo-1)*lineHeight-5, BoxSize(1) - 10, lineHeight-5]...
            ,"Text", 'Fit parameters (start values and used for plotting)'...
            ,'FontWeight', "bold" ...
            );
        end


        uilabel(paramBoxh ...
            ,"Position", [5, BoxSize(2)-lineNo*lineHeight-5, BoxSize(1) - editBoxW - 10, lineHeight-5]...
            ,"Text", paramTexts.(paramNames{ii})...
            );
        uieditfield(paramBoxh, 'numeric' ...
            ,"Position", [BoxSize(1) - editBoxW - 5, BoxSize(2)-lineNo*lineHeight-5, editBoxW, lineHeight-5]...
            ,"Value", Params.(paramNames{ii}).Value...
            ,'ValueChangedFcn', @paramValueChanged ...
            ,'UserData', paramNames{ii}...
            );
    end
    paramBoxh.Visible = true;

    waitfor(paramBoxh);
    function pb_OK_CB(~, ~)
        %ex_data = 0; %delete again if data export works
        delete(paramBoxh);
    end

    function pb_cancel_CB(~,~)
        newParams = [];
        delete(paramBoxh);
    end

    function paramValueChanged(hObject, ~)
        newParams.(hObject.UserData).Value = hObject.Value;
    end

end
