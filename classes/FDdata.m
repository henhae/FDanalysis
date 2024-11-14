classdef FDdata
    %class declaration for AFM force-distance data (single curve)
    
    properties      
        %Input Data
        Time        %piezo travel time in s
        Height      %height above surface in m (incl offset)
        Extension   %piezo extension distance in m (relative incl. offset?)

        %TODO: Get height at minimum/maximum piezo extension to calculate
        %extension from height and vice versa

        ZOffset     %offset for mHeight/mExtension calculation in m
        SprConst    %cantilever's Spring constant in N/m
        DeflSens    %deflection sensitivity in m/V

        OscLambda   %wavelength of baseline oscillation in m
        %derived properties, may be set by user
        Bl          %function handle defining the baseline function
        iBl         %start and end indices of baselines
        iCP         %contact point
        warnHandling
        errHandling
        callingAppWindow = [];
    end
    
    properties (Access = protected)
        %Y data of the curve/original input data. One of these channels in
        %descending priority: DeflV, Defl, F
        Y
        % Mark which height channel [extension height] has been set.
        H = [false false];
    end


    properties (Access = protected, Dependent)
        %hidden properties recieved by easy calculations
        Yc
        Noise
    end
    
    properties      (SetAccess = protected)
        OscCor          %fit object from sinusoidal fit to the baseline
        OrigChannel     %String identifying the original input data, i.e. Y
    end
    
    properties (Dependent)      
        %properties received by easy calculations
        DeflV           %cantilever deflection in V
        Defl            %cantilever deflection in m
        F               %Force on the cantilever in N
        DeflVc          %cantilever deflection in V, corrected
        Deflc           %cantilever deflection in m, corrected
        Fc              %Force on the cantilever in N, corrected
    end
    
    properties (Dependent, SetAccess = protected)
        mExtension      %piezo extension modified by ZOffset in m
        Sep             %separation between surface and tip in m
        Ind             %indentation in m
        AvChannels
        CP_Ext          % contact point in Extension values
        CP_Height       % contact point in Height values
        DataTable       %Table with all available channels
    end
    
    methods %constructor
        function obj = FDdata(varargin)
            obj.errHandling = 'Command';
            obj.warnHandling = 'Command';
            obj.OscLambda = 0;
            
            switch nargin
                case 0
                case 1
                    if isnumeric(varargin{1})
                        if ismatrix(varargin{1})
                            if isvector(varargin{1})
                                %only one vector given: Use as F in N
                                obj.F = varargin{1};
                            else
                                %Matrix given assume first two rows/columns
                                %to be Height in m and Force in N
                                channels = obj.clean_channels(varargin{1});
                                obj.Height = channels(:,1);
                                obj.F = channels(:,2);
                            end
                        end
                    elseif istable(varargin{1})
                        obj = obj.include_table(varargin{1});
                    elseif isempty(varargin{1})
                    else
                        obj.FDerror('Wrong data type for input no. 1. Needs to be numeric or table');
                    end
                       
                case 2
                    if isnumeric(varargin{1}) && isvector(varargin{1}) && isnumeric(varargin{2}) && isvector(varargin{2})
                        %two vectors given? 
                        %assume these are Height in m and Force in N
                        if numel(varargin{1}) == numel(varargin{2})
                            channels = zeros(length(varargin{1}),2);
                            for ii = 1:length(channels)
                                channels(ii,:) = [varargin{1}(ii), varargin{2}(ii)];
                            end
                            channels = obj.clean_channels(channels);
                            obj.Height = channels(:,1);
                            obj.F = channels(:,2);
                        else
                            obj.FDerror('The two given input channels differ in size.');
                        end
                    elseif ischar(varargin{1}) && isnumeric(varargin{2}) && isvector(varargin{2})
                        %string and vector given
                        if isprop(obj, varargin{1})
                            obj.(varargin{1}) = varargin{2};
                        else
                            obj.FDerror('Unknown channel.');
                        end
                    else
                        obj.FDerror('Wrong data types given. For two channels, two vectors must be given.')
                    end
                otherwise
                    %Expect string and vector pairs, where string gives
                    %the channel name
                    if mod(nargin,2) > 0
                        obj.FDerror('Wrong number of input parameters.')
                    end
                    iin = 1;
                    channels = table();
                    chs_left = iin < nargin;
                 
                    while iin <= nargin
                        if ischar(varargin{iin}) && chs_left && isvector(varargin{iin+1})
                            if isprop(obj, varargin{iin})
                                if iscolumn(varargin{iin+1})
                                    channels.(varargin{iin}) = varargin{iin+1};
                                else
                                    channels.(varargin{iin}) = varargin{iin+1}';
                                end
                            else
                                obj.FDerror(['Property "' varargin{iin} '" not defined.'])
                            end
                            iin = iin + 2;
                        end
                    end
                    obj = obj.include_table(channels);
            end
            if ~isempty(obj.OrigChannel)  && ~strcmp('DeflV', obj.OrigChannel)
                obj.FDwarning(['No DeflV channel given. ' obj.OrigChannel ' is used as "raw data".']);
            end
        end
    end
    
    methods         %set and get methods
        
        function val = get.AvChannels(obj)
            %lists all channels that are not empty
            poss_channels = {'Time', 'Extension', 'mExtension', 'Height', 'Sep', 'Ind'...
                'DeflV', 'Defl', 'F',...
                'DeflVc', 'Deflc', 'Fc'};
            val = poss_channels(cellfun(@(x) ~isempty(obj.(x)), poss_channels));
        end
        
        function obj = set.Time(obj, inval)
            T_temp = obj.prepare_input(inval, 'Time');
            obj.Time = T_temp;
%             if ~any(contains(obj.AvChannels, 'Time'))
%                 obj.AvChannels{end+1} = 'Time';
%             end
        end
        
        function obj = set.Extension(obj, inval)
            H_temp = obj.prepare_input(inval, 'Extension');
            obj.Extension = H_temp;
            if isempty(H_temp)
                obj.H(1) = false;
            else
                obj.H(1) = true;
            end
        end

        function obj = set.Height(obj, inval)
            H_temp = obj.prepare_input(inval, 'Height');
            obj.Height = H_temp;
            if isempty(H_temp)
                obj.H(2) = false;
            else
                obj.H(2) = true;
            end
%             if isempty(obj.Extension)
%                 obj.Extension= -H_temp; %max(H_temp)+min(H_temp) TODO: Offset from JPK scanner!
%             end
        end
        
        function val = get.Extension(obj)
            %if Extension was not given and Height was set (H(2)), return inverse Height             
            if isempty(obj.Extension) && obj.H(2)
                val =  - obj.Height;    % +max(obj.Height)+min(obj.Height) TODO: Offset from JPK scanner!
            else
                val = obj.Extension;
            end
            %TODO: How to import offset from JPK scanner.
        end
        
        
        function val = get.Height(obj)
            %if Height was not given and Extension was set (H(1)), return inverse Extension
            if isempty(obj.Height) && obj.H(1)
                val =  - obj.Extension;% + max(obj.Height);
            else
                val = obj.Height;
            end
        end

        function val = get.mExtension(obj)
            if ~isempty(obj.ZOffset)
                val = obj.Extension - obj.ZOffset;
            else 
                val = [];
            end
            %TODO: How to import offset from Bruker scanner.
        end

        function obj = set.Sep(obj, ~)
            obj.FDwarning('Setting separation is not possible. Please use internal data correction.')
        end
        
        function val = get.Sep(obj)
            if ~isempty(obj.Deflc)
                val = abs(obj.Extension(1) - obj.Extension(end)) ...
                    - obj.Extension + obj.Deflc;
                if ~isempty(obj.iCP)
                    if isscalar(obj.iCP)
                        CP = val(obj.iCP);
                    elseif numel(obj.iCP) == 2 && (sign(obj.Yc(obj.iCP(2))) ~= sign(obj.Yc(obj.iCP(1))))
                        %if iCP is doublett and Fc has zero point in this
                        %interval, find the Sep value of this zero point
                        a = (obj.Yc(obj.iCP(2))-obj.Yc(obj.iCP(1))) / (val(obj.iCP(2))-val(obj.iCP(1)));
                        CP = val(obj.iCP(1)) - 1/a * obj.Yc(obj.iCP(1));
                    else  %esp.: if Fc has no zero point in this interval
                        CP = val(obj.iCP(1));
                    end
                    val = val-CP;
                else
                    val = val - min(val);
                end
            else
                if ~isempty(obj.DeflVc)
                    obj.FDwarning('Separation cannot be calculated since Defl. Sens. is not given.');
                elseif ~isempty(obj.Fc)
                    obj.FDwarning('Separation cannot be calculated since Spring Constant is not given.');
                else
                    obj.FDwarning('Separation cannot be calculated since data are not corrected, yet.');
                end
                val = [];
            end
        end

        function obj = set.Ind(obj, ~)
            obj.FDwarning('Setting indentation is not possible. Please use internal data correction.')
        end
        
        function val = get.Ind(obj)
            if ~isempty(obj.Sep)
                val = -obj.Sep;
            else
                if ~isempty(obj.DeflVc)
                    obj.FDwarning('Indentation cannot be calculated since Defl. Sens. is not given.');
                elseif ~isempty(obj.Fc)
                    obj.FDwarning('Indentation cannot be calculated since Spring Constant is not given.');
                else
                    obj.FDwarning('Indentation cannot be calculated since data are not corrected, yet.');
                end
                val = [];
            end
        end
        
        function val = get.Yc(obj)
            if isempty(obj.Bl)
                obj.FDwarning('Baseline not detected, yet.');
                val = [];
            else
                val = obj.Y;
                %X = obj.Height;
                X = obj.Extension;
        % For baseline subtraction: f_new = f_old - (a(1)*f_old + a(2));
                if isempty(obj.OscCor)
                    try %if obj.Bl is function handle
                        functions(obj.Bl);
                        val = val - obj.Bl(X);
                    catch
                        val = val - val(1);
                    end
                    
%                     if obj.Bl(2) == 0 %i.e. if no baseline was found
%                         b = val(1);
%                     else
%                         b = obj.Bl(2);
%                     end
%                    val = val - (obj.Bl(1)*X + b);
                else
                    val = val - obj.OscCor(X);
                end
            end
        end
        
        function val = get.Noise(obj)
            if isempty(obj.Yc)  %rough estimation of noise with linear baseline
                a = polyfit(obj.Height(obj.iBl(1):obj.iBl(2)),obj.Y(obj.iBl(1):obj.iBl(2)),1);
                trace_tmp = obj.Y - (a(1)*obj.Y + a(2));
                val = std(trace_tmp( obj.iBl(1):obj.iBl(2) ));
            else
                val = std(obj.Yc( obj.iBl(1):obj.iBl(2) ));
            end
        end

        function val = get.CP_Height(obj)
            val = [];
            if ~isempty(obj.Height)
                if numel(obj.iCP) == 1
                    val = obj.Height(obj.iCP);
                else
                    val = mean(obj.Height(obj.iCP));
                end
            end
        end

       function val = get.CP_Ext(obj)
            val = [];
            if ~isempty(obj.Extension)
                if numel(obj.iCP) == 1
                    val = obj.Extension(obj.iCP);
                else
                    val = mean(obj.Extension(obj.iCP));
                end
            end
        end
        
        function val = get.DeflV(obj)
            val = [];
            if ~isempty(obj.OrigChannel)
                switch obj.OrigChannel 
                    case 'DeflV'
                        val = obj.Y;
                    case 'Defl'
                        if ~isempty(obj.DeflSens)
                            val = obj.Y ./ obj.DeflSens;
                        end
                    case 'F'
                        if ~isempty(obj.DeflSens) && ~isempty(obj.SprConst)
                            val = obj.Y ./ obj.DeflSens ./ obj.SprConst; 
                        end
                end
            end
        end        
        
        function obj = set.DeflV(obj, inval)
            DeflV_temp = obj.prepare_input(inval, 'DeflV');
            
            if ~isempty(obj.OrigChannel)
                switch obj.OrigChannel
                    case 'DeflV'
                        obj.DeflSens = obj.calcNewDeflSens(obj.Defl, DeflV_temp);
                        obj.Y = DeflV_temp;
                        obj.FDwarning('Original data have been reset. DeflSens has been updated.')
                    case 'Defl'
                        obj.DeflSens = obj.calcNewDeflSens(obj.Defl, DeflV_temp);
                    case 'F'
                        if ~isempty(obj.Defl)
                            obj.DeflSens = obj.calcNewDeflSens(obj.Defl, DeflV_temp);
                        else
                            obj.DeflSens = 1;
                            obj.FDwarning('DeflV and F were set but not Defl in nm. DeflSens has now been set to 1.');
                            obj.SprConst = obj.calcNewSprConst(obj.F, DeflV_temp);
                        end
                end
            else
                obj.Y = DeflV_temp;
                obj.OrigChannel = 'DeflV';
            end
        end
        
        function val = get.Defl(obj)
            val = [];
            if ~isempty(obj.OrigChannel)
                switch obj.OrigChannel 
                    case 'DeflV'
                        if ~isempty(obj.DeflSens)
                            val = obj.Y .* obj.DeflSens;
                        end
                    case 'Defl'
                        val = obj.Y;
                    case 'F'
                        if ~isempty(obj.SprConst)
                            val = obj.Y ./ obj.SprConst;
                        end
                end
            end
        end
        
        function obj = set.Defl(obj, inval)
            Defl_temp = obj.prepare_input(inval, 'Defl');
            
            if ~isempty(obj.OrigChannel)
                switch obj.OrigChannel
                    case 'DeflV'
                        obj.DeflSens = obj.calcNewDeflSens(Defl_temp, obj.DeflV);
                        if ~isempty(obj.F)
                            obj.SprConst= obj.calcNewSprConst(obj.F, Defl_temp);
                        end
                    case 'Defl'
                        warnstr = 'Original data have been reset.';
                        if ~isempty(obj.DeflV)
                            obj.DeflSens = obj.calcNewDeflSens(Defl_temp, obj.DeflV);
                            warnstr = [warnstr ' DeflSens has been updated'];
                        end
                        if ~isempty(obj.F)
                            obj.SprConst = obj.calcNewSprConst(obj.F, Defl_temp);
                            warnstr = [warnstr ' SprConst has been updated'];
                        end
                        obj.Y = Defl_temp;
                        obj.FDwarning(warnstr);
                    case 'F'
                        if ~isempty(obj.DeflV)
                            obj.DeflSens = obj.calcNewDeflSens(Defl_temp, obj.DeflV);
                        end
                        obj.SprConst = obj.calcNewSprConst(obj.F, Defl_temp);
                end
            else
                obj.Y = Defl_temp;
                obj.OrigChannel = 'Defl';
            end
%             
%             
%             if any(contains(obj.AvChannels, 'F'))
%                 obj.SprConst = obj.calcNewSprConst(obj.F, Defl_temp);
%             end
%             if any(contains(obj.AvChannels, 'DeflV'))
%                 obj.DeflSens = obj.calcNewDeflSens(Defl_temp, obj.DeflV);
%             end
%             
%             if isempty(obj.OrigChannel)
%                 obj.Y = Defl_temp;
%                 obj.OrigChannel = 'Defl';
%             end
%             if ~any(contains(obj.AvChannels, 'Defl'))
%                 obj.AvChannels{end+1} = 'Defl';
%             elseif strcmp(obj.OrigChannel,'Defl')
%                 obj.FDwarning('Original data have been reset.');                
%             end
        end
        
        function val = get.F(obj)
            val = [];
            if ~isempty(obj.OrigChannel)
                switch obj.OrigChannel
                    case 'DeflV'
                        if ~isempty(obj.DeflSens) && ~isempty(obj.SprConst)
                            val = obj.Y .* obj.DeflSens .* obj.SprConst;
                        end
                    case 'Defl'
                        if ~isempty(obj.SprConst)
                            val = obj.Y .* obj.SprConst;
                        end
                    case 'F'
                        val = obj.Y;
                end
            end
        end
        
        function obj = set.F(obj, inval)
            F_temp = obj.prepare_input(inval, 'F');
            if isempty(obj.OrigChannel)
                obj.Y = F_temp;
                obj.OrigChannel = 'F';
            else
                switch obj.OrigChannel
                    case 'DeflV'
                        if ~isempty(obj.Defl)
                            obj.SprConst = obj.calcNewSprConst(F_temp, obj.Defl);
                        else
                            obj.DeflSens = 1;
                            obj.FDwarning('DeflV and F were set but not Defl in nm. DeflSens has now been set to 1.');
                            obj.SprConst = obj.calcNewSprConst(F_temp, obj.DeflV);
                        end
                    case 'Defl'
                        obj.SprConst = obj.calcNewSprConst(F_temp, obj.Defl);
                    case 'F'
                        if ~isempty(obj.Defl)
                            obj.SprConst = obj.calcNewSprConst(F_temp, obj.Defl);
                        end
                        obj.Y = F_temp;
                        obj.FDwarning('Original data have been reset. SprConst has been updated');
                end
            end  
%             if any(contains(obj.AvChannels, 'Defl'))
%                 obj.SprConst = obj.calcNewSprConst(F_temp, obj.Defl);
%             end
%             if isempty(obj.OrigChannel)
%                 obj.Y = F_temp;
%                 obj.OrigChannel = 'F';
%             end
%             if ~any(contains(obj.AvChannels, 'F'))
%                 obj.AvChannels{end+1} = 'F';
%             elseif strcmp(obj.OrigChannel,'F')
%                 obj.FDwarning('Original data have been reset.');  
%             end
        end
        
        function obj = set.Deflc(obj, ~)
            obj.FDerror('Input of corrected data is not possible.');
        end

        function obj = set.Fc(obj, ~)
            obj.FDerror('Input of corrected data is not possible.');
        end
        
  
        function val = get.DeflVc(obj)
            val = [];
            if ~isempty(obj.DeflV)
                switch obj.OrigChannel 
                    case 'DeflV'
                        val = obj.Yc;
                    case 'Defl'
                        if ~isempty(obj.DeflSens)
                            val = obj.Yc ./ obj.DeflSens;
                        end
                    case 'F'
                        if ~isempty(obj.DeflSens) && ~isempty(obj.SprConst)
                            val = obj.Yc ./ obj.DeflSens ./ obj.SprConst; 
                        end
                end
            end
        end
        
        function val = get.Deflc(obj)
            val = [];
            if ~isempty(obj.Defl)
                switch obj.OrigChannel 
                   case 'DeflV'
                    if ~isempty(obj.DeflSens)
                        val = obj.Yc .* obj.DeflSens;
                    end
                    case 'Defl'
                        val = obj.Yc;
                    case 'F'
                        if ~isempty(obj.SprConst)
                            val = obj.Yc ./ obj.SprConst;
                        end
                end
            end
        end
        
        function val = get.Fc(obj)
            val = [];
            if ~isempty(obj.F)
                switch obj.OrigChannel 
                    case 'DeflV'
                        if ~isempty(obj.DeflSens) && ~isempty(obj.SprConst)
                            val = obj.Yc .* obj.DeflSens .* obj.SprConst;
                        end
                    case 'Defl'
                        if ~isempty(obj.SprConst)
                            val = obj.Yc .* obj.SprConst;
                        end
                    case 'F'
                        val = obj.Yc;
                end
            end
        end
        
        
        function obj = set.DeflSens(obj, val)
            if ~(isnumeric(val) && isscalar(val))
                if isempty(val)
                    obj.FDwarning('No defl-sens. set. Defl and F will not be calculated.');
                else
                    obj.FDerror('Wrong input type');
                end
            end
            obj.DeflSens = val;
        end
        
        function obj = set.SprConst(obj, val)
            if ~(isnumeric(val) && isscalar(val))
                if isempty(val)
                    obj.FDwarning('No spring constant set. F will not be calculated.');
                else
                    obj.FDerror('Wrong input type');
                end
            end
            obj.SprConst = val;
        end

        function val = get.DataTable(obj)
            chans = obj.AvChannels;
            val = table();
            for ii = 1:numel(chans)
                val.(chans{ii}) = obj.(chans{ii});
            end
        end
        
        %overriding/providing standard class functions
        function val = length(obj)
            val = length(obj.Y);
        end
        
        function val = isempty(obj)
            val = ~logical(length(obj));
        end

    end
    
    methods %public class methods

        %returns unit of given channel(s) or values
        function val = Unit(obj, channel)
            units = struct( ...
                'Time', 's',...
                'Extension', 'm',...
                'Height', 'm',...
                'Height_s', 'm',...
                'SprConst','N/m',...
                'DeflSens', 'V/m',...
                'DeflV', 'V',...
                'Defl', 'm',...
                'F', 'N',...
                'DeflVc', 'V',...
                'Deflc', 'm', ...
                'Fc','N'...
                );
            if ischar(channel)
                val = units.(channel);
            elseif iscell(channel)
                val = channel;
                for ii = 1:numel(val)
                    val{ii} = units.(channel{ii});
                end
            end
        end
        
        %set the channel which is assigned as "raw data". i.e. which data
        %are in the Y variable
        function obj = setRawData(obj, channel)
            if ~ischar(channel)
                obj.FDerror('Input error. String expected.')
            end
            
            if any(strcmp(channel, {'DeflV', 'Defl', 'F'}))
                obj.Y = obj.(channel);
                obj.OrigChannel = channel;
                %recalculation of baseline
                if ~isempty(obj.iBl)
                    obj = obj.calc_baseline(obj.iBl);
                end
                if ~isempty(obj.OscCor)
                    obj = obj.correct_osz;
                end
                
            else
                obj.FDerror('Unknown channel for raw data.')
            end
            %--> recalculation of all other channels....
        end
        
        %get baseline noise for channel
        % channel   : str, one of: 'DeflV', 'Defl', or 'F'
        function val = getNoise(obj, channel)
            if ~ischar(channel)
                obj.FDerror('Input error. Function expects string');
            end
            if any(strcmp(channel, obj.AvChannels))
                switch channel
                    case 'DeflV'
                        val = std(obj.DeflVc( obj.iBl(1):obj.iBl(2) ));
                    case 'Defl'
                        val = std(obj.Deflc( obj.iBl(1):obj.iBl(2) ));
                    case 'F'
                        val = std(obj.Fc( obj.iBl(1):obj.iBl(2) ));
                    otherwise
                        obj.FDerror(['Unkown channel ' channel ' for noise calculation.']);
                end
                    
            end
        end
        
        
        %function is obsolete, since obj.correct does the same if called
        %without options
        %TODO find way to automatically detect if oszillations are present.
        %then: remove optional input. (Options are for correct().)
        
        %performs baseline and contact point corrections automatically
        %varargin:  expects input string 'osc'
        function obj = auto_correct(obj, varargin)
            %check for optional correct options
            switch nargin
                case 1
                    cor_osc = false;
                case 2
                    if ischar(varargin{1})
                        if strcmp(varargin{1}, 'osc')
                            cor_osc = true;
                        else, obj.FDerror('Unknown input argument.')
                        end
                    else, obj.FDerror('Input error. String expected.')
                    end
                otherwise
                obj.FDerror('To many input arguments.')
            end
            
            if numel(obj.Y) == 0, return; end
            
            obj = obj.find_iBl;
               
            %get baseline indices
            obj = obj.calc_baseline(obj.iBl);
            
            if cor_osc
                obj = obj.correct_osz;
            else
                obj.OscCor = [];
            end

            %contact-point calculation
            if any(contains(obj.AvChannels, 'Defl'))
                obj = obj.find_cp2;
            else
                obj.FDwarning('Separation cannot be calculated since Spring Constant is not given.');
            end
        end
        
        %%% Corrects raw data and thus enables calculation of Yc:
        %   1. Find (or define) baseline end points (function find_iBl)
        %   2. Calculate baseline (linear or oscillatory)
        %   3. Find (or define) contact point index.
        % Input arguments, as String-Value pair:
        %   'ContactPointX' ? numeric value specifying contact point in Height (m)
        %   'ContactPoint': numeric value specifying index of contact point
        %   'BaselineX': two element vector of numeric values specifying start and end of baseline in Height (m)
        %   'BaselineIndex': two element vector of numeric values specifying start and end indices of baseline
        %   'CorrectOsc': logical value; if true, oscillation correction will be performed 
        function obj = correct(obj, varargin)

            poss_args = {'ContactPointX', 'ContactPointIndex',...
                'BaselineX', 'BaselineIndex', 'BaselineThres', ...
                'CorrectOsc', 'OscLambda'};
            if nargin == 2 && isstruct(varargin{1})
                args = varargin{1};
            else
                args = obj.parseArguments(varargin, poss_args);
            end
            
            if numel(obj.Y) == 0, return; end
            
            %Get start and end indices for baseline
            if isfield(args, 'BaselineIndex')
                if isnumeric(args.BaselineIndex) && numel(args.BaselineIndex) == 2 ...
                        && all(uint32(args.BaselineIndex) == args.BaselineIndex)
                    obj.iBl = sort(args.BaselineIndex);
                else
                    obj.FDerror('Wrong input for baseline indices.');
                end
            elseif isfield(args, 'BaselineX')
                if isnumeric(args.BaselineX) && numel(args.BaselineX) == 2 && ...
                        all(args.BaselineX <= max(obj.Height) & args.BaselineX >= min(obj.Height))
                    %[~, iBl_from_X] = min(abs(args.BaselineX(1) - obj.Height));
                    %[~, iBl_from_X(2)] = min(abs(args.BaselineX(2) - obj.Height));
                    iBl_from_X = obj.chan2i(args.Baseline, 'Height',1);
                    obj.iBl = sort(iBl_from_X);
                else
                    obj.FDerror('Wrong input for baseline height values.');
                end
            elseif isfield(args, 'BaselineThres') && isscalar(args.BaselineThres)
                obj = obj.find_iBl('Thres', args.BaselineThres);
            else
                %TODO: adjust treshold if end of baseline was not found
                %(i.e. iBl(2) == length(Y))
                obj = obj.find_iBl;
            end
            
            
            if isfield(args, 'CorrectOsc') && logical(args.CorrectOsc)
                if isfield(args, 'OscLambda')
                    obj.OscLambda = args.OscLambda;
                end
                obj = obj.correct_osz;
            else
                obj.OscCor = [];
                obj = obj.calc_baseline(obj.iBl);
            end

            %baseline endpoint optimization
            if ~isfield(args, 'BaselineIndex') && ~isfield(args, 'BaselineX')
                obj = obj.optimize_iBl();
            end
            
            %contact-point calculation
            if any(contains(obj.AvChannels, 'Defl'))
                if isfield(args, 'ContactPointIndex')
                    %given value should be one or two indices (if CP is
                    %between those Idxs) and be positive integers
                    if isnumeric(args.ContactPointIndex) && any(numel(args.ContactPointIndex) == [1 2]) ...
                        && all(uint32(args.ContactPointIndex) == args.ContactPointIndex)
                        obj.iCP = args.ContactPointIndex;
                    else
                        obj.FDerror('Wrong input for contact point indices.');
                    end
                elseif isfield(args, 'ContactPointX')
                    if isnumeric(args.ContactPointX) && numel(args.ContactPointX) == 1
                        %[~, iCP_from_X] = min(abs(args.ContactPointX - obj.Height));
                        %obj.iCP = sort(iCP_from_X);
                        obj.iCP = obj.chan2i(args.ContactPointX, 'Height',2);
                    else
                        obj.FDerror('Wrong input for contact point height value.');
                    end
                else
                    obj = obj.find_cp2;
                end
            else
                obj.FDwarning('Separation cannot be calculated since Spring Constant is not given.');
            end
            
        end
        
        %calculates linear baseline
        function obj = calc_baseline(obj,iBl)
            %iBl: Indices of start and end of the baseline
            if numel(iBl) ~= 2
                obj.FDerror('Wrong number of indices (or none) given.');
            end
            a = polyfit(obj.Extension(iBl(1):iBl(2)),obj.Y(iBl(1):iBl(2)),1);
            %obj.Bl = a;
            obj.Bl = @(x) a(1)*x + a(2);
            % For baseline subtraction: f_new = f_old - (a(1)*f_old + a(2));            
        end
        
        %find indices of begin and end of baseline 
        function obj = find_iBl(obj, varargin)
            %Input: Name–Value scheme:
            % 'Thres' -> numeric: treshold in units of noise level (stddev of baseline values)
            % 'UseCorr' -> logical: Use corrected data for baseline determination?
            
            allowedArgs = {'Thres', 'UseCorr'};
            defOptions = {3, false};
            args = obj.parseArguments(varargin,allowedArgs,defOptions);

            try
                mustBeUnderlyingType(args.UseCorr, 'logical')
                mustBeNonempty(args.Thres)
                mustBeScalarOrEmpty(args.Thres)
                mustBeGreaterThan(args.Thres,0)                
            catch ME
                obj.FDerror(ME);
            end
            
            data = obj.Y;
            if args.UseCorr
                if isempty(obj.Yc)
                    obj.FDwarning('Could not perform find_iBl on corrected data as data are not corrected, yet. Performed on uncorrected data instead.')
                else
                    data = obj.Yc;
                end
            end

            obj.iBl = [1, length(data)];
            %divide data into num_parts.
            %criterion for end of baseline: stddev of actual part increases
            %more than (tresh * stddev of parts before)
            num_parts = 8;%[50 20];
            ip = 0;
            foundRightBorder = false;
            width = 1;
            while ~foundRightBorder && num_parts * 3 < length(data) %&& ip < length(num_parts)
                ip = ip + 1;
                width = floor(length(data) ./ num_parts);%(ip));
                width = max(width, 1);

                ii = 0;
                ms = std( data(1:width) );
                
                while (ii+2) * width < length(data) && ~foundRightBorder
                    ii = ii+1;
                    s = std( data( (ii*width)+1 : (ii+1)*width) );
                    %If stddev of tested part is thresh times higher than
                    %the mean value of the stds of the parts before:
                    %break
                    if s > args.Thres * ms
                        %disp(['checked with > ' num2str(num_parts) ' parts'])
                        %disp(['End found in ' num2str(ii+1) 'th part of ' num2str(num_parts) ' parts'])
                        obj.iBl(2) = (ii)*width; %(ii-1)*width;  %bug??

                        %ii = length(data);
                        %ip = length(num_parts)+1;
                        foundRightBorder = true;
                        m = mean( data(1:(ii*width))  );  
                    end

                    if ~foundRightBorder
                        ms = mean( [ones(1, ii) * ms, s] );
                    end
                end
                num_parts = num_parts * 2;

            end

            %%% find more precise point in last checked data part 
            % "chunk" = (data( (ii*width)+1 : (ii+1)*width)
            if ~foundRightBorder
                chunk = data;
                m = mean( chunk( 1:floor(numel(chunk)*4/5) ) );
                ms = std( chunk( 1:floor(numel(chunk)*4/5) ) );
                ii = 0;
            else               
                chunk = data( (ii*width)+1 : (ii+1)*width);
            end

            %get first occurence where cumulative sum control is > 5*std

            %sometimes ms=0, then cusum throws error.
            if ms == 0
                [iUp, iLow] = cusum(chunk, args.Thres*5/3, args.Thres, m);
            else
                [iUp, iLow] = cusum(chunk, args.Thres*5/3, args.Thres, m, ms);
            end

            if isempty(iLow), iLow = length(chunk); end
            if isempty(iUp), iUp = length(chunk); end
            iFound = min(iUp,iLow);

            %get correct index of point in data
            %sprintf('Chunk start idx = %i, end idx = %i', (ii*width)+1, (ii+1)*width)           
            obj.iBl(2) = iFound + ii*width;
        end

        
        %optimize Baseline indices to get closer to real baseline end
        function obj = optimize_iBl(obj)

            %use data without oscillation for baseline detection
            if ~isempty(obj.OscCor)
                obj = obj.find_iBl('UseCorr', true, 'Thres', 2);
            end

            %move last baseline index backwards until inside 0.5*noise of corrected data
            %(or min difference: for low noise low z-resolution basline data 
            %sometimes exhibit only few discrete steps)
            if ~isempty(obj.Yc)
                thres = max(0.5, min(abs(obj.Yc(obj.iBl(1):obj.iBl(2)) ))/obj.Noise);
                obj.iBl(2) = find(abs(obj.Yc(obj.iBl(1):obj.iBl(2))) <= obj.Noise* thres *(1+eps),1, 'last') + obj.iBl(1)-1;
            else
            end
        end
        
        %substract baseline oszillations
        function obj = correct_osz(obj)

            if isempty(obj.iBl)
                obj.FDerror('Baseline not found, yet.');
            end
            
            xData = obj.Extension(obj.iBl(1):obj.iBl(2));
            yData = obj.Y(obj.iBl(1):obj.iBl(2));
            
            %linear fit to approximately find slope in data
            
            a = polyfit(xData,yData,1);
            obj.Bl = @(x) a(1)*x + a(2);
            obj.OscCor = [];


            %fft needs equidistant data:
            
            %if sampling rate was too high, scatter in Height/extension
            %channel might appear (found in JPK data) that is similar or 
            %higher than step size ==> non-monotonic in-/decrease over time
            % ==> sort by height and remove double entries:
            [xUniqueSorted, iSort, ~] = unique(xData,"sorted");
            yUniqueSorted = yData(iSort);

            xForFFT = linspace(xData(1), xData(end),length(xUniqueSorted));
            yForFFT = interp1(xUniqueSorted,yUniqueSorted - obj.Bl(xUniqueSorted), xForFFT,"linear");            
            
            try
                sinFitParams = sineFit(xForFFT,yForFFT,0);
            catch ME
                sinFitParams = [];
                obj.FDerror('Baseline oscillation removal did not work. Try to select different baseline points.')
            end

            %Non-linear fit with sin and linear slope (A*sin(2*pi*x/lambda+phi)+m*x+x0)
            %with parameters from linear fit and FFT as starting parameters
            
            if ~isempty(sinFitParams)
                slope = a(1);
                offs = a(2) + sinFitParams(1);            
                A_s = sinFitParams(2);
                lambda_s = 1/sinFitParams(3);
                phi_s = sinFitParams(4);
                
                % Set up fittype and options.
                ft_rt = fittype( 'A*sin(2*pi*x/lambda+phi)+m*x+x0', 'independent', 'x', 'dependent', 'y','coefficients',{'A', 'lambda', 'phi', 'm', 'x0'} );
                opts = fitoptions( 'Method', 'NonlinearLeastSquares', 'TolX', 1e-12);
                opts.Algorithm = 'Levenberg-Marquardt';
                %opts.Algorithm = 'Trust-Region';
                opts.Robust = 'Bisquare';
                %use parameters from sineFit and line fit as starting points
                opts.StartPoint = [A_s, lambda_s, phi_s, slope, offs]; 
    
                % Fit model to data.
                [fitres_rt, fitinfo, outp] = fit( xData, yData, ft_rt, opts );
                
                cvals = coeffvalues(fitres_rt);
                obj.OscLambda = cvals(2);
                obj.OscCor = fitres_rt;
            end
            
        end
    
        %find contact point:
        function obj = find_cp2(obj)
            min_tresh = 3; 

            trace = obj.Yc;
            trace_end = median(trace(end-5:end));
            
            if trace_end > 0 && trace_end > obj.Noise
                
                %get index of last point with negative deflection value
                iLastZP = find(trace < 0, 1, 'last');
                
                iupBorder = obj.iBl(2);
                found_iCP = false;
                
                while ~logical(found_iCP)
                    %get index of minimum deflection value outside of baseline
                    [~, iMin] = min(trace(iupBorder+1:iLastZP));
                    iMin = iMin + iupBorder;

                    if ( iLastZP <= iupBorder ) || ( trace(iMin) > min_tresh*obj.Noise )
                    %if value is already part of baseline or if minimum not much
                    %outside of noise (no snap-in or adhesion)
                        found_iCP = iLastZP;
                    else
                        %divide trace between iMin and iLastZP in boxes with at
                        %least 10 data points and check if stdev of any of
                        %these boxes is less than 110% of noise. If so, minimum
                        %was not the "last" adhesion.
                        chunk_length = 10;
                        no_parts = floor(numel(trace(iMin:iLastZP))/chunk_length);
                        %if Minimum is less than 10 points away from iLastZP
                        if no_parts == 0
                            if std(trace(iMin:iLastZP)) > min_tresh * obj.Noise
                                found_iCP = [iLastZP , iLastZP]; 
                            else
                                found_iCP = iLastZP; 
                            end
                        else
                            %no_parts = min(no_parts, 20);
                            checkpart = trace(iLastZP - chunk_length*no_parts + 1: iLastZP);
                            
                            chunks = zeros(no_parts,chunk_length);
                            for ip = 1:no_parts
                                chunks(ip,:) = checkpart((ip-1)*chunk_length+1 : ip*chunk_length);
                            end
                            stdevs = std(chunks,0,2);
                            iLowNoiseChunk = find(stdevs < 1.1 * obj.Noise,1,'last');
                            
                            if isempty(iLowNoiseChunk)
                                found_iCP = [iLastZP, iLastZP+1];
                            else
                                iupBorder = iLastZP - (no_parts - (iLowNoiseChunk+1))*chunk_length;
                            end
                            
                        end
                            
                    end
                end
                %if found index larger than length of data (possibly: last
                %point (and not the median of the last chunk) was negative)
                if any(found_iCP > length(obj.Yc))
                    found_iCP = length(obj.Yc);
                end
                obj.iCP = found_iCP;
            else % data end has negative value or is within noise
                % ==> no "real" contact, only cantilever binding towards surface
                % ==> use end of trace as "contact point" 
                obj.iCP = length(trace);
            end
            
            if (numel(obj.iCP) == 1) && (length(trace) ~= obj.iCP)
                %do sophisticated CP search for no adhesion/snap-in situation
            end
        end        
    end
    
    methods     %helper functions
        
        function channel = prepare_input(obj, channel, type)
            %remove NaNs
            channel = obj.clean_channels(channel);
            if ~isempty(channel) && ~isvector(channel)
                obj.FDerror('Data for channel %s is not a vector.', type); 
            end
            
            %check if length is the same as for other given  channels. error if not.
            Channels = {'Time', 'Height', 'Y'};
            for iChan = Channels
                iChan = char(iChan);
                if ~strcmp(iChan, type)
                    if ~isempty(obj.(iChan)) && (numel(channel) ~= numel(obj.(iChan)) )
                        obj.FDerror('New data for %s differ in length from data in channel %s', type, iChan);
                    end
                end
            end
        end
        
        function channels = clean_channels(obj, channels)
            %clean NaNs and turn channel(s) to column vector(s)
            if ~isvector(channels)
                coldim = find(size(channels) == 2, 1);
                if coldim == 1, channels = channels'; end
                channels( any(isnan(channels),2) ,:) = [];
            else
                if ~iscolumn(channels),  channels = channels'; end
                channels( isnan(channels) ) = [];
            end
        end
        
        
        function obj = include_table(obj, datat)
            %remove rows where any entry is NaN
            datat( any(isnan(table2array(datat)),2) ,:) = [];
            for ic = 1:size(datat, 2)
                if isprop(obj, datat.Properties.VariableNames{ic})
                    obj.(datat.Properties.VariableNames{ic}) = datat.(ic);
                else
                    obj.FDwarning(['Channel ' datat.Properties.VariableNames{ic} ' not known. Skipped.'])
                end
            end
            if any(strcmp('DeflV', obj.AvChannels))
                obj = obj.setRawData('DeflV');
            end
        end
        
        function newDeflSens = calcNewDeflSens(obj, Defl, DeflV)
            newDeflSens_v = Defl ./ DeflV;
            newDeflSens_v = newDeflSens_v(DeflV ~= 0);
            cDiff = (max(newDeflSens_v) - min(newDeflSens_v))/min(newDeflSens_v);
            if cDiff > 0
                if cDiff > 0.001
                    obj.FDerror('Different deflection sensitivities! Relative difference in calculated values is larger than 0.001!');
                end
                obj.FDwarning('Relative difference in deflection sensitivities is larger than 0 but less than 0.001! Its mean value will be used.');
            end
            newDeflSens = mean(newDeflSens_v);
            if (any(contains(obj.AvChannels, 'Defl')) && any(contains(obj.AvChannels, 'DeflV')) ) && ~isempty(obj.DeflSens)...
                    && (obj.DeflSens - newDeflSens)/obj.DeflSens > 0.01
                obj.FDwarning('Newly calculated deflection sensitivity value differs from old value by more than 1%.')
            end
            
        end
        
        function newSprConst = calcNewSprConst(obj, F, Defl)
            newSprConst_v = F./Defl;
            newSprConst_v = newSprConst_v(Defl ~= 0);
            cDiff = (max(newSprConst_v) - min(newSprConst_v))/min(newSprConst_v);
            if cDiff > 0
                if cDiff > 0.001
                    obj.FDerror('Different spring constants! Relative difference in calculated spring constants is larger than 0.001!');
                end
                obj.FDwarning('Relative difference in calculated spring constants is larger than 0 but less than 0.001! Its mean value will be used.');
            end
            newSprConst = mean(newSprConst_v, 'omitnan');
            if (any(contains(obj.AvChannels, 'F')) && any(contains(obj.AvChannels, 'Defl')) ) && ~isempty(obj.SprConst)...
                    && (obj.SprConst - newSprConst)/obj.SprConst > 0.01
                obj.FDwarning('Newly calculated spring constant value differs from old value by more than 1%.')
            end
        end
        
        %simple contact point determination. (from Nic w/o modification in algorithm)
        % for curves w/o adhesion/snap-in, or molecule stretching (normal in
        % SM-experiments), it will fail and just yield the lowest point
        % use find_cp2 instead!       
        function obj = find_cp(obj, varargin)
             %treshold in units of f_max
            if nargin > 2
                obj.FDerror('Too many input values.');
            elseif nargin == 2
                tresh = varargin{1};
                if ~isnumeric(tresh) || ~isscalar(tresh)
                    obj.FDerror('Input has to be scalar.')
                end
            else, tresh = 5;
            end
            
            %find contact point of curve
            BL_max = max(abs(obj.Fc(obj.iBl(1):obj.iBl(2))));
            i1stMax = find( abs(obj.Fc(obj.iBl(2)+1:end)) > tresh*BL_max,1,'first' ) + obj.iBl(2);    %to account for the fact that find searches relative to the starting index
            if isempty(i1stMax)
                i1stMax=length(obj.Fc);
            end
            if obj.Fc(i1stMax) < 0  %this means adhesion or snap-in
                fit_start=find(obj.Fc <=0 ,1,'last');
                if fit_start==length(obj.Fc)
                    obj.iCP = fit_start;
                else
                    obj.iCP = [fit_start, fit_start+1];
                end
            else %this means no adhesion, or the curve has a bad "bump" before the negative forces
                CP = obj.Sep(i1stMax);  %simply moving the curve by the separation of its contactpoint
                fit_start=length(obj.Fc);
                if abs(obj.Sep(i1stMax))>10*1e-9 %this usually means, that the curve has a bump and separation correction will go wrong
                    fit_start=find(force <=0 ,1,'last');    %in this case simply the procedure of an adhesion curve is copied
                    if fit_start==length(obj.Fc)
                        CP = obj.Sep(fit_start);
                    else
                        a = (obj.Fc(fit_start+1)-obj.Fc(fit_start)) / (obj.Sep(fit_start+1)-obj.Sep(fit_start));
                        CP = obj.Sep(fit_start) - 1/a * obj.Fc(fit_start);
                    end
                end
            end
        end
        
        %obsolete function: see chan2i
        function out = Height2i(obj, height, nb)
            %Finds index to data height values closest to given "height".
            %nb: if 1: finds closest value, 2: find closest neighbors
            [~, iH] = min(abs(height - obj.Height));
            if nb == 1
                out = iH;
            elseif nb == 2
                poss_iNb = [iH-1, iH+1];
                if obj.Height(iH) > height
                    iH2 = poss_iNb(obj.Height(poss_iNb) < height);
                else
                    iH2 = poss_iNb(obj.Height(poss_iNb) > height);
                end
                out = sort([iH, iH2]);
            else
                
            end
        end
        
        function out = chan2i(obj, x, chan, nb, varargin)
            %Finds index to channel value closest to given "x".
            %x: value(s) to find
            %chan: name of channel to test
            %nb: if 1: finds closest value, 2: find closest neighbors
            %out: array or cell array (if x is non-scalar and nb=2)


            if ~any(strcmp(chan, obj.AvChannels))
                obj.FDerror('Unknown or unset channel.')
            end
            if nb<1 || nb>2
                obj.FDerror('Wrong input value for parameter "nb". Must be 1 or 2.')
            end
            if nargin == 5
                is_strict = logical(varargin{1});
            elseif nargin > 5
                obj.FDerror('Too many input values.')
            else
                is_strict = false;
            end


            %TODO: include check that "x" is within the min-max of the
            %channel values. What to output if not? (include "strict"
            %option: if TRUE: output error, if FALSE output bound. value
            
            if nb == 1
                out = zeros(size(x));
            elseif nb == 2 && numel(x) == 1
                out = 0;
            elseif nb == 2 && numel(x) > 1
                out = cell(size(x));
            end

            for ii = 1:numel(x)
                if is_strict && (x(ii) > max(obj.(chan)) || x(ii)< min(obj.(chan)))
                    obj.FDerror(['Error: Given value is not within the bounds of channel ' chan '.'])
                end
                [~, iH] = min(abs(x(ii) - obj.(chan)));
                if nb == 1
                    out(ii) = iH;
                elseif nb == 2
                    poss_iNb = [iH-1, iH+1];
                    if obj.(chan)(iH) > x(ii)
                        iH2 = poss_iNb(obj.(chan)(poss_iNb) < x(ii));
                    else
                        iH2 = poss_iNb(obj.(chan)(poss_iNb) > x(ii));
                    end
                    if iscell(out)
                        out{ii} = sort([iH, iH2]);
                    else
                        out = sort([iH, iH2]);
                    end
                else
                    
                end
            end
        end
        
        
        function FDwarning(obj, warnstr)
            if isempty(obj.warnHandling)
                obj.warnHandling = 'Command';
            end
            if ~any(strcmp(obj.warnHandling, {'Dialog', 'UIDialog', 'Command', 'suppress'}))
                obj.FDerror('Unknown argument for warning handler property.')
            end
            switch obj.warnHandling
                case 'Dialog'
                    warndlg(warnstr, 'Warning');
                case 'UIDialog'
                    if ~isempty(obj.callingAppWindow) && ishandle(obj.callingAppWindow) ...
                            && isprop(obj.callingAppWindow, 'RunningAppInstance')
                        uialert(obj.callingAppWindow, warnstr, 'Warning', 'Icon','warning');
                    else
                        warndlg(warnstr, 'Error');
                    end
                case 'Command'
                    warning(warnstr);
                case 'suppress'
            end
        end
        
        function FDerror(obj, errorM)
            if isa(errorM, 'MException')
                errstr = errorM.message;
            elseif ischar(errorM) || isstring(errorM)
                errstr = errorM;
            end

            if isempty(obj.warnHandling)
                obj.warnHandling = 'Command';
            end

            if ~any(strcmp(obj.errHandling, {'Dialog', 'UIDialog', 'Command', 'suppress'}))
                ME = MException('MATLAB:invalidOption', 'Unknown argument for warning handler property.');
                %error('Unknown argument for warning handler property.')
                throw(ME);
            end

            switch obj.errHandling
                case 'Dialog'
                    errordlg(errstr, 'Error');
                case 'UIDialog'
                    if ~isempty(obj.callingAppWindow) && ishandle(obj.callingAppWindow) ...
                            && isprop(obj.callingAppWindow, 'RunningAppInstance')
                        uialert(obj.callingAppWindow, errstr, 'Error', 'Icon','error');
                    else
                        errordlg(errstr, 'Error');
                    end
                case 'Command'
                    if isa(errorM, 'MEexception')
                        rethrow(errorM);
                    else
                        error(errstr);
                    end
                case 'suppress'
            end
        end
        
        
    end %methods helper functions

    
    methods (Access = private)  % other helper function
        
        function argstruct = parseArguments(obj, args, argNames, varargin)
            %check input
             if nargin > 3
                if nargin > 4
                    obj.FDerror('Too many input values.');
                else
                    defValues = varargin{1};
                    if length(defValues) ~= length(argNames)
                        obj.FDerror('Number of arguments and default values does not match.')
                    elseif ~iscell(defValues)
                        obj.FDerror('Default values are not given as cell.')
                    end
                end
            end

            %construct args structure
            if isempty(args)
                argstruct = struct();

            elseif isstruct(args)
                %clean given args-structure and pass only allowed argNames
                argfields = fieldnames(args);
                for ii = 1:length(argfields)
                    if ~any(contains(argNames,argfields{ii}))
                        args = rmfield(args,argfields{ii});
                        obj.FDwarning(['Unknown argument ' argfields{ii} '.']);
                    end
                end
            
            elseif iscell(args)
                %transform PropertyName-PropertyValue list to arg structure
                %with PropertyNames as fieldnames.
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

            %If default values are given, assign default values to all
            %fields that have not been created above.
            if nargin == 4
                for ii = 1:length(argNames)
                    if ~isfield(argstruct, argNames{ii})
                        argstruct.(argNames{ii}) = defValues{ii};
                    end
                end
            end

        end %parseArguments


    end
    
end %classdef