classdef FDdata_ar
    %class declaration for AFM force-distance measurements
    %   properties include data, some metadata (from file header) and
    %   fits/data evaluations

    properties 
        ap  FDdata  = FDdata;
        rt  FDdata  = FDdata;
        callingAppWindow = [];
        errHandling = 'Command';
        warnHandling = 'Command';
        file            char

        DataFits    FDdataFit    % (array of) FDdataFit object(s)
    end
    
    properties (Dependent)
        DeflSens        double
        SprConst        double
        OrigChannel     char
    end

    properties (SetAccess = protected)
        %Evaluation values
        AdhEnergy       double
        AdhForce        double
        AdhSep          double
        RuptLength      double

        %header properties
        Position
    end
    
    
    methods %constructor
        function obj = FDdata_ar(varargin)
            if nargin == 0
                    obj.ap = FDdata();
                    obj.rt = FDdata();
            else
                validArgs = {'OscCor', 'ContactPointDet', 'errHandling',...
                    'warnHandling', 'callingAppWindow'};
                givenArgs = varargin;
                args = obj.parseArguments(givenArgs, validArgs);
                
                if isfield(args, 'errHandling') 
                        obj.errHandling = args.errHandling;
                end
                
                if isfield(args, 'warnHandling') 
                        obj.warnHandling = args.warnHandling;
                end
                
                if isfield(args, 'callingAppWindow') 
                        obj.callingAppWindow = args.callingAppWindow;
                end
                
                if isfield(args, 'fst')
                    datavar = args.fst;
                    
                    if ischar(datavar) 
                        if exist(datavar, 'file') == 2
                            obj.file = datavar;
                            datavar = obj.read_file(datavar);
                        else
                            obj.FDerror(['File not found:' datavar])
                        end
                    end

                    if istable(datavar)
                        obj = obj.include_table_from_BrukerData(datavar);
                    end
                    if isstruct(datavar)
                        if ~isfield(datavar, 'Type') || datavar(1).Type == "JPK"
                            obj = obj.include_struct_from_JPKData(datavar);
                        elseif datavar(1).Type == "Nanoscope Force"
                            obj = obj.include_struct_from_Nanoscope(datavar);
                        end
                    end

                end
                %error('Not supported, yet.')
            end
        end
    end
    
    methods %get and set methods

        function obj= set.warnHandling(obj, value)
            if ~any(strcmp(value, {'Dialog', 'UIDialog', 'Command', 'suppress'}))
                error('Unknown argument for warning handler property.')
            end
            obj.warnHandling = value;
            obj.ap.warnHandling = value;
            obj.rt.warnHandling = value;
        end
        
        function obj= set.errHandling(obj, value)
            if ~any(strcmp(value, {'Dialog', 'UIDialog', 'Command', 'suppress'}))
                obj.FDerror('Unknown argument for error handler property.');
            end
            obj.errHandling = value;
            obj.ap.errHandling = value;
            obj.rt.errHandling = value;
        end
        
        function obj= set.callingAppWindow(obj, value)
            if isempty(value) || ...
                    (ishandle(value) && isprop(value, 'RunningAppInstance'))
                obj.callingAppWindow = value;
                obj.ap.callingAppWindow = value;
                obj.rt.callingAppWindow = value;
            else
                obj.FDerror('Input is not an App Window.')
            end
        end
        
        
        function val = get.DeflSens(obj)
            if isempty(obj.ap.DeflSens) && isempty(obj.rt.DeflSens)
                val = false;
                obj.FDwarning('Deflection Sensitivity not set.');
            elseif isempty(obj.ap.DeflSens)
                val = obj.rt.DeflSens;
            elseif isempty(obj.rt.DeflSens)
                val = obj.ap.DeflSens;
            else
                val1 = obj.ap.DeflSens;
                val2 = obj.rt.DeflSens;
                if val1 == val2
                    val = val1;
                elseif abs(val1-val2)/val1 < 0.001
                    obj.FDwarning('Relative difference in deflection sensitivities for approach and retract is larger than 0 but less than 0.001!');
                    val = round(val1,4,'significant');
                else
                    val = (val1+val2)/2;
                    obj.FDerror('Relative difference in deflection sensitivities for approach and retract is larger 0.001! Set to mean value.');
                end
            end
        end
        
        function obj = set.DeflSens(obj, val)
            obj.ap.DeflSens = val;
            obj.rt.DeflSens = val;
        end
        
        function val = get.SprConst(obj)
            if isempty(obj.ap.SprConst) && isempty(obj.rt.SprConst)
                val = false;
                obj.FDwarning('Spring constant not set.');
            elseif isempty(obj.ap.SprConst)
                val = obj.rt.SprConst;
            elseif isempty(obj.rt.SprConst)
                val = obj.ap.SprConst;
            else
                val1 = obj.ap.SprConst;
                val2 = obj.rt.SprConst;
                if val1 == val2
                    val = val1;
                elseif abs(val1-val2)/val1 < 0.001
                    obj.FDwarning('Relative difference in spring constant for approach and retract is larger than 0 but less than 0.001!');
                    val = round(val1,4,'significant');
                else
                    val = (val1+val2)/2;
                    obj.FDerror('Relative difference in spring constant for approach and retract is larger 0.001! Set to mean value.');
                end
            end
        end
        
        function obj = set.SprConst(obj, val)
            obj.ap.SprConst = val;
            obj.rt.SprConst = val;
        end
        
        function val = get.OrigChannel(obj)
            apOrig = obj.ap.OrigChannel;
            rtOrig = obj.rt.OrigChannel;
            if strcmp(apOrig, rtOrig)
                val = apOrig;
            else
                val = 'var';
            end
        end
        
        function obj = set.OrigChannel(obj, val)
            obj.ap = obj.ap.setRawData(val);
            obj.rt = obj.rt.setRawData(val);
        end
    end
    
    methods % overloading
%         function val = length(obj)
%             if isscalar(obj)
%                 val = [length(obj.ap) length(obj.rt)];
%             else
%                 val = builtin('length', obj);
%             end
%         end
        
        function val = isempty(obj)
            if isscalar(obj)
                val = all([isempty(obj.ap) isempty(obj.rt)]);
            else
                val = builtin('isempty', obj);
            end
        end
    end
    
    methods
        %TODO: split in auto_correct and correct, where auto_correct can/should be
        %called without options and tries to determine many things
        %automatically. E.g. if correct baseline is not found (for only one trace) etc.
        
        
        function obj = auto_correct(obj, varargin)
                        
            if nargin == 1 
                    obj.ap = obj.ap.auto_correct;
                    obj.rt = obj.rt.auto_correct;
            else
                validArgs = {'BaselinePrio', 'ContactPointPrio'...
                    'ContactPointX', 'ContactPointIndex',...
                'BaselineX', 'BaselineIndex', 'BaselineThres',...
                'CorrectOsc', 'OscLambda'};
                if nargin == 2 && isstruct(varargin{1})
                    argStruct = varargin{1};
                else
                    givenArgs = varargin;
                    argStruct = obj.parseArguments(givenArgs, validArgs);
                    if isfield(argStruct, 'fst')
                        obj.FDerror('Wrong input argument.');
                    end
                end
                
                % !! In case of priorization, the oscillation correction is
                % not performed for the non-priorized part !!
                if isfield(argStruct, 'BaselinePrio')
                    if strcmp(argStruct.BaselinePrio, 'ap')
                        obj.ap = obj.ap.correct(argStruct);
                        %argStruct.BaselineX = obj.ap.Height(obj.ap.iBl);
                        %obj.rt = obj.rt.correct(argStruct);
                        obj.rt.iBl = [1,2];
                        obj.rt.Bl = obj.ap.Bl;
                    else
                        obj.rt = obj.rt.correct(argStruct);
                        %argStruct.BaselineX = obj.rt.Height(obj.rt.iBl);
                        %obj.ap = obj.ap.correct(argStruct);
                        obj.ap.iBl = [1,2];
                        obj.ap.Bl = obj.rt.Bl;
                    end
                else
                    obj.ap = obj.ap.correct(argStruct);
                    obj.rt = obj.rt.correct(argStruct);
                end
                
%                 if isfield(argStruct, 'OscCor') && strcmp(argStruct.OscCor, 'on')
%                     obj.ap = obj.ap.auto_correct('osc');
%                     obj.rt = obj.rt.auto_correct('osc');
%                 else
%                     obj.ap = obj.ap.auto_correct;
%                     obj.rt = obj.rt.auto_correct;
%                 end
                
                if isfield(argStruct, 'ContactPointPrio')
                    switch argStruct.ContactPointPrio
                        case 'ap'
                            %TODO: use here chan2i-method of FDdata:
                            % obj.rt.iCP = obj.rt.chan2i(obj.ap.Height(obj.ap.iCP(1)), 'Height', 1)
                            % or with property CP_Height:
                            % obj.rt.iCP = obj.rt.chan2i(obj.ap.CP_Height, 'Height', 1)
                            [~, new_iCP_rt] = min(abs(obj.ap.Height(obj.ap.iCP(1)) - obj.rt.Height ));
                            obj.rt.iCP = new_iCP_rt;
                        case 'rt'
                            [~, new_iCP_ap] = min(abs(obj.rt.Height(obj.rt.iCP(1)) - obj.ap.Height ));
                            obj.ap.iCP = new_iCP_ap;
                        case 'lowest'
                            obj.ap.iCP = length(obj.ap);
                            obj.rt.iCP = length(obj.rt);
                    end
                end
            end

        end
        
        % Determine simple evaluation values from the curves as e.g. rupture
        % length, adhesion energy, snap-in distance etc.
        function obj = evaluate(obj, varargin)

            %varargin: cell of strings with Names of values to evaluate
            
            %check input:
            if nargin < 2
                obj.FDwarning('Not enough input values. Skip evaluation.');
                return;
            end

            if ~all(cellfun(@ischar, varargin))
                obj.FDerror('Wrong input.');
                return;
            end

            validEvals = {'AdhesionEnergy', 'RuptureLength', 'AdhesionForce',...
                'AdhesionSeparation'};

            evalsToDo = cell(0);

            if any(strcmp(varargin, 'all'))
                evalsToDo = validEvals;
            else
                for ii=1:length(varargin)
                    if ~any(strcmp(varargin{ii},validEvals))
                        obj.FDerror(['Unknown value: ' varargin{ii}]);
                        return;
                    else
                        evalsToDo{end+1} = varargin{ii};
                    end
                end
            end

            
            all_obj = obj;
            

            for ii = 1:numel(all_obj)
                obj = all_obj(ii);
                %%%  calculations:
                if any(strcmp('AdhesionForce', evalsToDo)) || any(strcmp('AdhesionSeparation', evalsToDo))
                    %maximum adhesion force = minimum value in Fc between end
                    %of baseline and end of data
                    if any(strcmp('Fc', obj.rt.AvChannels))
                        [obj.AdhForce, forcePeakIdx] = min(obj.rt.Fc(obj.rt.iBl(2):end));
                        forcePeakIdx = forcePeakIdx + obj.rt.iBl(2) + 1 ;
                        obj.AdhForce = abs(obj.AdhForce);
                        if obj.AdhForce <= obj.rt.getNoise('F')
                            obj.AdhForce = 0;
                        end
                    else
                        obj.FDwarning('No corrected force available. Adhesion force not calculated');
                    end
                end
    
                if any(strcmp('AdhesionSeparation', evalsToDo))
                    %adhesion peak separation: separation of point of maximum
                    %adhesion to contact point.
                    if isempty(obj.AdhForce) || obj.AdhForce == 0
                        obj.AdhSep = 0;
                        obj.FDwarning('No adhesion peak detected. Its separation was not calculated');
                    elseif any(strcmp('Sep', obj.rt.AvChannels))
                        obj.AdhSep = obj.rt.Sep(forcePeakIdx);
                    else 
                        obj.FDwarning('No separation available. Adhesion peak separation not calculated');
                    end
                end    
                
    
                if any(strcmp('RuptureLength', evalsToDo)) || any(strcmp('AdhesionEnergy', evalsToDo))
                    %rupture length: last data point before baseline which is
                    %still above the noise.
                    fac = 3;
                    if any(strcmp('Sep', obj.rt.AvChannels))
                        ruptIdx = find((abs(obj.rt.Fc) > obj.rt.getNoise('F') * fac) & ...
                            ((obj.rt.Sep)< min(obj.rt.Sep(obj.rt.iBl)) ), 1,"first");
                        obj.RuptLength = obj.rt.Sep(ruptIdx);
                    else
                        obj.FDwarning('No separation available. Rupture length not calculated');    
                    end        
                end

                if any(strcmp('AdhesionEnergy', evalsToDo))
                    %adhesion energy: integral of Fc between end of rupture point %baseline
                    %and contact point.
                    if any(strcmp('Fc', obj.rt.AvChannels)) && any(strcmp('Sep', obj.rt.AvChannels))
                        if obj.rt.iCP(1) > ruptIdx
                            obj.AdhEnergy = trapz(obj.rt.Sep(ruptIdx:obj.rt.iCP(1)),...
                                obj.rt.Fc(ruptIdx:obj.rt.iCP(1)));
                            obj.AdhEnergy = abs(obj.AdhEnergy);
                        else
                            obj.AdhEnergy = 0;
                        end
                    else
                        obj.FDwarning('No corrected force or separation available. Adhesion energy not calculated');    
                    end
                end

                all_obj(ii) = obj;
            end
            obj = all_obj;
        end

        function obj = zero_evals(obj,varargin)
            if nargin > 2
                obj.FDerror('Too many input values.');
            elseif nargin == 2
                if any(strcmp(varargin{1}, {'ap', 'rt'}))
                    if any(strcmp(varargin, 'ap'))
                        ap_zero = true;
                    else
                        ap_zero = false;
                    end
                    if any(strcmp(varargin, 'rt'))
                        rt_zero = true;
                    else
                        rt_zero = false;
                    end
                else
                    obj.FDerror('Unknown input.');
                end
            else
                ap_zero = true;
                rt_zero = true;
            end

            if ap_zero
            end

            if rt_zero
                obj.AdhEnergy = [];
                obj.AdhForce = [];
                obj.AdhSep = [];
                obj.RuptLength = [];
            end
        end
        
        function ph = plot(obj, varargin)
            %plot FD data with ap and rt channel
            %usage:
            %obj.plot()     %plots ap and rt channel, corrected if possible
            %obj.plot(s)    %where s is 'cor' or 'uncor', plots (un-)corrected data
            %obj.plot(s)    %where s is 'evals', plots corrected data and evaluated properties
            %obj.plot(x, y) %plots channel y vs. channel x
            
            X_chs = {'Time', 'Extension', 'mExtension', 'Height', 'Sep', 'Ind'};
            X_desc = {'Time', 'Extension', 'Extension w. offset', 'Height', 'Separation', 'Indentation'};
            X_units = { 's', 'm', 'm', 'm'};
            Y_chs = {'DeflV', 'Defl', 'F'};
            Y_units = {'V', 'm', 'N'};
            Y_desc = {'Deflection', 'Deflection', 'Force'};
            if any(cellfun(@(x) any(strcmp(x,obj.ap.AvChannels)) , {'Fc', 'Deflc', 'DeflVc'}))
                Y_chs(end+1:end+3) = {'DeflVc', 'Deflc', 'Fc'};
                Y_units(end+1:end+3) = Y_units;
                Y_desc(end+1:end+3) = Y_desc;
            end
            
            prefixes = {'', 'm', '\mu', 'n', 'p', 'f'};

            additionals = {'CP', 'Bl', 'evals'};
            addPlots = {};
            
            switch nargin 
                case 1
                    %automatic choice of channels to plot:

                    av_X_chs = cellfun(@(x) any(strcmp(x,obj.ap.AvChannels)) , X_chs) & ...
                        cellfun(@(x) any(strcmp(x,obj.rt.AvChannels)) , X_chs);
                    X_iChoice = find(av_X_chs, 1, 'last');
                    

                    av_Y_chs = cellfun(@(x) any(strcmp(x,obj.ap.AvChannels)) , Y_chs) & ...
                        cellfun(@(x) any(strcmp(x,obj.rt.AvChannels)) , Y_chs);
                    Y_iChoice = find(av_Y_chs, 1, 'last');
                     
                case 2
                    if strcmp(varargin{1}, 'uncor')
                        X_iChoice = 2;
                        av_Y_chs = cellfun(@(x) any(strcmp(x,obj.ap.AvChannels)) , Y_chs) & ...
                        cellfun(@(x) any(strcmp(x,obj.rt.AvChannels)) , Y_chs);
                        Y_iChoice = find(av_Y_chs, 1, 'last');
                    elseif strcmp(varargin{1}, 'cor')
                        if numel(Y_chs) > 3
                            X_iChoice = 4;
                            Y_iChoice = numel(Y_chs);
                        else
                            obj.FDerror('Data not corrected, yet.')
                        end
                    elseif strcmp(varargin{1}, 'evals')
                        if numel(Y_chs) > 3
                            X_iChoice = 4;
                            Y_iChoice = numel(Y_chs);
                            addPlots = additionals;
                        else
                            obj.FDerror('Data not corrected, yet.')
                        end
                    else
                        obj.FDerror('Unknown input value.')
                    end
                    
                case 3 % X- and Y-channel given as strings
                    if ischar(varargin{1})
                        X_iChoice = find(strcmp(varargin{1}, X_chs));
                        if isempty(X_iChoice)
                            obj.FDerror('X-channel not available.')
                        end
                    end
                    if ischar(varargin{2})
                        Y_iChoice = find(strcmp(varargin{2}, Y_chs));
                        if isempty(Y_iChoice)
                            obj.FDerror('Y-channel not available.')
                        end
                    end
                    
                otherwise
                obj.FDerror('Wrong number of input parameters.')
            end
            
            X_ch = X_chs{X_iChoice};
            X_unit = X_units{X_iChoice};
            Y_ch = Y_chs{Y_iChoice};
            Y_unit = Y_units{Y_iChoice};
            
            X_exp = max( ceil(-log10(max(abs( [obj.ap.(X_ch); obj.rt.(X_ch)] )))/3));
            Y_exp = max( ceil(-log10(max(abs( [obj.ap.(Y_ch); obj.rt.(Y_ch)] )))/3));
            X_unit = [prefixes{X_exp+1} X_unit];
            Y_unit = [prefixes{Y_exp+1} Y_unit];
            
            ph = plot(obj.ap.(X_ch)*10^(3*X_exp), obj.ap.(Y_ch)*10^(3*Y_exp), '.b', ...
                obj.rt.(X_ch)*10^(3*X_exp), obj.rt.(Y_ch)*10^(3*Y_exp), '.r');
            xlabel(['\it ' X_desc{X_iChoice} ' \rm / ' X_unit]);
            ylabel(['\it ' Y_desc{Y_iChoice} ' \rm / ' Y_unit]);

            if ~isempty(addPlots)
                ah = ph.Parent;
                ah.NextPlot = 'add';
                if any(strcmp(addPlots, 'CP'))
                    plot(ah, obj.ap.(X_ch)(obj.ap.iCP(1))*10^(3*X_exp), ...
                        obj.ap.(Y_ch)(obj.ap.iCP(1))*10^(3*Y_exp), 'db',...
                        obj.rt.(X_ch)(obj.rt.iCP(1))*10^(3*X_exp), ...
                        obj.rt.(Y_ch)(obj.rt.iCP(1))*10^(3*Y_exp), 'dr',...
                        'MarkerSize', 8, ...
                        'MarkerFaceColor', 'g');
                end
                if any(strcmp(addPlots, 'Bl'))
                    plot(ah, obj.ap.(X_ch)(obj.ap.iBl)*10^(3*X_exp), ...
                        obj.ap.(Y_ch)(obj.ap.iBl)*10^(3*Y_exp), 'db',...
                        obj.rt.(X_ch)(obj.rt.iBl)*10^(3*X_exp), ...
                        obj.rt.(Y_ch)(obj.rt.iBl)*10^(3*Y_exp), 'dr',...
                        'MarkerSize', 8, ...
                        'MarkerFaceColor', 'k');
                end
                if any(strcmp(addPlots,'evals')) && strcmp(X_ch, 'Sep') && strcmp(Y_ch, 'Fc')
                    if ~isempty(obj.AdhForce) && obj.AdhForce > 0
                        iAh = find(abs(abs(obj.rt.Fc) - obj.AdhForce)<eps(obj.AdhForce), 1,'last');
                        plot(ah, obj.rt.Sep(iAh)*10^(3*X_exp), obj.rt.Fc(iAh)*10^(3*Y_exp), 'pg');
                    end

                    if ~isempty(obj.AdhSep) && obj.AdhSep > 0
                        plot(ah, [0, obj.rt.Sep(iAh)]*10^(3*X_exp), 1.1*[1 1]*obj.rt.Fc(iAh)*10^(3*Y_exp), '-|g');
                    end

                    if ~isempty(obj.AdhEnergy) && obj.AdhEnergy > 0
                        pah = area(ah, obj.rt.Sep(obj.rt.iBl(2):obj.rt.iCP(1))*10^(3*X_exp),...
                        obj.rt.Fc(obj.rt.iBl(2):obj.rt.iCP(1))*10^(3*Y_exp), ...
                        'FaceColor', 'g', 'LineStyle', 'none');
                        pah.FaceAlpha = 0.5;
                        pah.ShowBaseLine = 'off';
                    end
                end
                ah.NextPlot = 'replace';
            end

            
        end
    end
    
    
    methods % helper functions
        function obj = include_table_from_BrukerData(obj, data)
            if ~istable(data)
                obj.FDwarning('Wrong data format. Expected table.')
                obj = false;
                return; 
            end

            M_ex = table();
            M_rt = table();

            %cell with the following columns:
            % 1: name of channel in Bruker file, 
            % 2: channel name in FDdata where data will be written into
            % 3: factor according to unit prefix used in Bruker file (FDdata uses prefix-less numbers in SI units only)
            possible_channels = {'Time_s_Ex', 'Time', 1;...
                             'Time_s_Rt', 'Time', 1;...
                             'Calc_Ramp_Ex_nm', 'Extension', 1e-9;...
                             'Calc_Ramp_Rt_nm', 'Extension', 1e-9;...
                             'Defl_V_Ex', 'DeflV', 1;
                             'Defl_V_Rt', 'DeflV', 1;...
                             'Defl_nm_Ex','Defl', 1e-9;...
                             'Defl_nm_Rt', 'Defl', 1e-9;... 
                             'Defl_pN_Ex','F', 1e-12;... 
                             'Defl_pN_Rt','F', 1e-12; ...
                             'Height_Sensor_nm_Ex', 'Extension', 1e-9;...
                             'Height_Sensor_nm_Rt', 'Extension', 1e-9};  

            %copy all available fields of "possible_data" from M into either M_ex or M_rt 
            for iif = 1:size(possible_channels,1)
                if any(strcmpi(possible_channels{iif,1}, data.Properties.VariableNames))
                    if contains(possible_channels{iif,1}, 'Ex') %$approach part
                        M_ex.(possible_channels{iif,2}) = data.(possible_channels{iif,1}) * possible_channels{iif,3};
                    else    %retraction part
                        M_rt.(possible_channels{iif,2}) = data.(possible_channels{iif,1}) * possible_channels{iif,3};
                    end
                end
            end
            
            %Retraction Vectors get turned to have the same apparence as
            %approach vectors, i.e. baseline start is at point No. 1
            %If time channel is available, sort with descending time, otherwise
            % just flip columns upside down
            if any(strcmpi('Time', M_rt.Properties.VariableNames))
                M_rt = sortrows(M_rt,'Time','descend');
            else
                M_rt = flipud(M_rt);
            end
            
            obj.ap = obj.ap.include_table(M_ex);
            obj.rt = obj.rt.include_table(M_rt);
            
%             obj.ap = FDdata(M_ex);
%             obj.rt = FDdata(M_rt);            
        end
        
        function obj = include_struct_from_JPKData(obj, data)
            if ~isstruct(data)
                obj.FDwarning('Wrong data format. Expected: structure.')
                obj = false;
                return; 
            end
            
            for ii=1:length(data)
                if strcmp(data(ii).segment, 'extend')
                    s_ex = data(ii);
                elseif strcmp(data(ii).segment, 'retract')
                    s_rt = data(ii);
                elseif strcmp(data(ii).segment, 'pause')
                end
            end
            
            % measuredHeight is measured extension of piezo, height is
            % extension due to applied voltage. (very likely...)
            hCol = strcmp('measuredHeight', s_ex.columns);
            defCol = strcmp('vDeflection', s_ex.columns);
            timeCol = strcmp('seriesTime', s_ex.columns);
            
            switch s_ex.calibrationSlots{defCol}
                case "force"
                    defDimName = 'F';
            end                
            
            t_ex = table(s_ex.Data(:,hCol), s_ex.Data(:,defCol), s_ex.Data(:,timeCol),...
                'VariableNames', {'Height', defDimName, 'Time'});
            
            obj.ap = obj.ap.include_table(t_ex);
            obj.ap.SprConst = s_ex.springConstant;
            obj.ap.DeflSens = s_ex.sensitivity;
            
            %assume here, that columns are the same as in approach part
            
            t_rt = table(s_rt.Data(:,hCol), s_rt.Data(:,defCol), s_rt.Data(:,timeCol),...
                'VariableNames', {'Height', defDimName, 'Time'});
            
            t_rt = sortrows(t_rt,'Time','descend');
            
            obj.rt = obj.rt.include_table(t_rt);
            obj.rt.SprConst = s_rt.springConstant;
            obj.rt.DeflSens = s_rt.sensitivity;
            
            %what to do with the  "pause" segment? ignore it for the moment

            %save additional header properties
            if isfield(data, 'xPosition')
                obj.Position.x = data(1).xPosition;
                obj.Position.y = data(1).yPosition;
            end
        end

        function obj = include_struct_from_Nanoscope(obj, data)
            if ~isstruct(data)
                obj.FDwarning('Wrong data format. Expected: structure.')
                obj = false;
                return; 
            end
            isNanoscope = (isfield(data, 'Type') && data.Type == "Nanoscope" ) || ...
                (isfield(data, 'Header') && isfield(data, 'Params') && isfield(data, 'Data') && ...
                isfield(data.Header, 'CiaoForceImageList'));

            if ~isNanoscope
                obj.FDwarning('Wrong data format. Missing fields for Nanoscope data.')
                obj = false;
                return; 
            end

            IdeflChan = find(contains(data.Params.ChannelName, "Deflection"),1);
            IheightChan = find(contains(data.Params.ChannelName, "Height"),1);

            try
                %needs symbolic math toolbox
                hChanUnit = str2symunit(data.Params.ZScaleParts(IheightChan).SoftScaleUnit);
                hChanUnitFact = double(separateUnits(unitConvert(hChanUnit, "SI")));

                dChanUnit = str2symunit(data.Params.ZScaleParts(IdeflChan).SoftScaleUnit);
                deflSensFact = double(separateUnits(unitConvert(dChanUnit, "SI")));
            catch

                prefixes = {'p', 'n', 'u', 'm'};
                factors = 10.^[-12, -9, -6, -3];
                hUnitStr = char(data.Params.ZScaleParts(IheightChan).SoftScaleUnit);
                IhunitSIPart = strfind(hUnitStr, "m/V");
                if ~isempty(IhunitSIPart)
                    if IhunitSIPart>1 && isletter(hUnitStr(IhunitSIPart-1))
                        Ipref = strcmp(hUnitStr(IhunitSIPart-1), prefixes);
                        hChanUnitFact = factors(Ipref);
                    else
                        hChanUnitFact = 1;
                    end
                end

                IdunitSIPart = strfind(hUnitStr, "m/V");
                if ~isempty(IdunitSIPart)
                    if IdunitSIPart>1 && isletter(hUnitStr(IdunitSIPart-1))
                        Ipref = strcmp(hUnitStr(IdunitSIPart-1), prefixes);
                        deflSensFact = factors(Ipref);
                    else
                        deflSensFact = 1;
                    end
                end

            end

            %assume that approach part is in col.1 and retract in col.2
            %what happens if there's a "pause"...?

            if size(data.Data{IheightChan},2) ~= 2
                obj.FDerror('Unexpected number of segments: Number of segments in file is not two (approach and retract).')
                return
            end

            piezo_ext = data.Data{IheightChan}(:,1)*data.Params.ZScale(IheightChan) * hChanUnitFact;
            piezo_ext(:,2) = data.Data{IheightChan}(:,2)*data.Params.ZScale(IheightChan) * hChanUnitFact;

            deflV = data.Data{IdeflChan}(:,1)*data.Params.ZScaleParts(IdeflChan).HardScale;
            deflV(:,2) = data.Data{IdeflChan}(:,2)*data.Params.ZScaleParts(IdeflChan).HardScale;


            %time channel:
            %do it like in Nanoscope export: Just use the scan rate
            scanRate = str2double(data.Header.CiaoForceList{1}("Scan rate")); %in Hz
            timeStep = 1/scanRate/numel(data.Data{IheightChan});

            times = ((1:numel(data.Data{IheightChan}))-1)*timeStep;
            times = reshape(times, size(data.Data{IheightChan}));
            
            % this causes improper handling if zeros are present at the
            % channel end (see zero handling below)
            % instead: do this after zero deletion
            % if piezo_ext(1,1) > piezo_ext(end,1)
            %     times(:,1) = flipud(times(:,1));
            % end
            % if piezo_ext(1,2) < piezo_ext(end,2)
            %     times(:,2) = flipud(times(:,2));
            % end


            t_ex = table(piezo_ext(:,1)...
                ,deflV(:,1)...
                , times(:,1) ...
                ,'VariableNames' ...
                , {'Extension' ... % in m
                    , 'DeflV' ...   % in V
                    , 'Time' ...    % in s
                    });
            %delete pure zero rows.
            t_ex( table2array(sum(t_ex(:,1:2),2)) == 0 ,:) = [] ;
            if t_ex.Extension(1) > t_ex.Extension(end)
                t_ex.Time = flipud(t_ex.Time);
            end

            t_ex = sortrows(t_ex,'Time','ascend');

            obj.ap = obj.ap.include_table(t_ex);
            obj.ap.SprConst = data.Params.SprConst;
            obj.ap.DeflSens = data.Params.ZScaleParts(IdeflChan).SoftScale * deflSensFact;

            t_rt = table(piezo_ext(:,2)...
                ,deflV(:,2)...
                , times(:,2) ...
                ,'VariableNames' ...
                , {'Extension' ...
                    , 'DeflV' ...
                    , 'Time' ...
                    });

            t_rt( table2array(sum(t_rt(:,1:2),2)) == 0 ,:) = [] ;
            if t_rt.Extension(1) < t_rt.Extension(end)
                t_rt.Time = flipud(t_rt.Time);
            end

            t_rt = sortrows(t_rt,'Time','descend');

            obj.rt = obj.rt.include_table(t_rt);
            obj.rt.SprConst = data.Params.SprConst;
            obj.rt.DeflSens = data.Params.ZScaleParts(IdeflChan).SoftScale * deflSensFact;

            %save additional header properties
            if isfield(data.Params, 'Position')
                obj.Position.x = data.Params.Position.X; %in m
                obj.Position.y = data.Params.Position.Y; %in m
            end

        end

        function [datavar, varargout] = read_file(obj, fileName)
            [fpath, fname, fext] = fileparts(fileName);

            %guess the file type:
            fileNo = fopen(fileName);
            act_line = fgetl(fileNo);
            
            if fext == ".txt"  %textfile with exportet data in ascii format
                if act_line(1) == '#'
                    fileType = 'JPK_ex';
                elseif contains(act_line, 'Force file list')
                    fileType = 'Bruker_ex_w_head';
                    no_head_lines = 1;
                    while ~(isnumeric(act_line) && act_line == -1) ...
                            && ~contains(act_line, '*Force file')
                            
                        no_head_lines = no_head_lines + 1;
                        act_line = fgetl(fileNo);
                        % if num_hlines == 2264
                        %     dummy = 0;
                        % end
                    end
                else
                    fileType = 'Bruker_ex';
                end
            elseif fext == ".spm" && contains(act_line, 'Force file list')
                %Nanoscope force file of "newer" versions
                fileType = 'Bruker_Nanoscope';
            elseif contains(act_line, 'Force file list')
                if isnan(str2double(fext(2:end)))
                    %probably modified file
                else
                    %Nanoscope force file of "older" versions, file
                    %extension is numeric: 000 ++
                    fileType = 'Bruker_Nanoscope';
                end
            elseif fext == ".jpk-force"
                obj.FDerror('JPK rawdata import not implemented, yet. Please export your data to txt-files first.')
            else
                obj.FDerror('File type could not be determined.')
            end

            fclose(fileNo);
            
            switch fileType
                case 'Bruker_ex'%Import of Bruker txt files.
                    datavar = readtable(fileName,'Delimiter','\t');
                case 'Bruker_ex_w_head'
                    datavar = readtable(fileName, "NumHeaderLines" , no_head_lines+1,...
                        'Delimiter','\t');
                case 'JPK_ex' %Import of JPK txt files
                    datavar = readJPKfile(fileName);
                    datavar(1).Type = "JPK";
                case 'Bruker_Nanoscope'
                    datavar = readNanoscopeFile(fileName);
                    %datavar.Type = "Nanoscope Force";
            end
            
        end
        
        function writetotxt(obj, path)
            %Write data to txt file similar to Bruker files
            possible_channels = {'Time_s_Ex', 'Time', 1;...
                             'Height_Sensor_nm_Ex', 'Extension', 1e-9;...
                             'Defl_V_Ex', 'DeflV', 1;
                             'Defl_nm_Ex','Defl', 1e-9;...
                             'Defl_pN_Ex','F', 1e-12;
                             'Separation_nm_Ex', 'Sep', 1e-9;
                             'Defl_V_Ex_corr', 'DeflVc', 1;
                             'Defl_nm_Ex_corr','Deflc', 1e-9;...
                             'Defl_pN_Ex_corr','Fc', 1e-12;};
                         
            iChannels = cellfun(@(x) any(strcmp(x, obj.ap.AvChannels)), possible_channels(:,2));
            M = table();
            AvChannels = (1:length(possible_channels));
            AvChannels(~iChannels) = [];
            
            endNaNs = NaN(abs(length(obj.ap) - length(obj.rt)),1);
            
            for iC = AvChannels
                apData = obj.ap.(possible_channels{iC,2}) / possible_channels{iC,3};
                if length(obj.ap) < length(obj.rt)
                    apData = [apData; endNaNs];
                end
                M.(possible_channels{iC,1}) = apData;
                rtData = flipud(obj.rt.(possible_channels{iC,2}) / possible_channels{iC,3});
                if length(obj.ap) > length(obj.rt)
                    rtData = [rtData; endNaNs];
                end
                M.(strrep(possible_channels{iC,1}, '_Ex', '_Rt')) = rtData;
            end
            writetable(M, path, 'Delimiter', '\t');            
        end
        
        function argstruct = parseArguments(~, args, argNames)
            while ~isempty(args)
                if logical(mod(numel(args),2))
                    argstruct.fst = args{1};
                    args(1) = [];
                else
                    if ischar(args{1})
                        if any(strcmp(args{1}, argNames))
                            argstruct.(args{1}) = args{2};                            
                        else, obj.FDerror(['Unknown argument ' args{1} ' .']);
                        end
                        args(1:2) = [];
                    else, obj.FDerror('Wrong input.'); 
                    end
                end
            end
        end
        
        function FDwarning(obj, warnstr)
            switch obj.warnHandling
                case 'Dialog'
                    warndlg(warnstr, 'Warning');
                case 'UIDialog'
                    if ~isempty(obj.callingAppWindow)
                        uialert(obj.callingAppWindow, warnstr, 'Warning', 'Icon','warning');
                    else
                        warndlg(warnstr, 'Warning');
                    end
                case 'Command'
                    warning(warnstr);
                case 'suppress'
            end
        end
        
        function FDerror(obj, errstr)
            switch obj.errHandling
                case 'Dialog'
                    errdlg(errstr, 'Error');
                case 'UIDialog'
                    if ~isempty(obj.callingAppWindow)
                        uialert(obj.callingAppWindow, errstr, 'Error', 'Icon','error');
                    else
                        errdlg(errstr, 'Error');
                    end
                case 'Command'
                    error(errstr);
                case 'suppress'
            end
        end
        
        
    end
end