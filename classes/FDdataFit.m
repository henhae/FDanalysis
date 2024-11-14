classdef FDdataFit
    %class for fitting the FDdata, including the model, fit results,
    %fitoptions and the fitted data (part of FDdata_ar or indices)
    properties
        model           % fitmodelDef object
        cfit            % cfit object from performed fit
        gof             % struct: goodness of fit stats from performed fit
        outp            % struct: fitinfo output from performed fit
        fitOptions      % fitoptions object for fit
        trace           % char: which trace to fit: "ap" or "rt"
        xchannel
        ychannel
        data            % data to fit either given as table with two or three columns (x-y-weight)
                        %   or vector array of indices, a tuple is
                        %   interpreted as begin:end
        confLevel =0.95 % Confidence level for calculation of confidence bounds/errors,
                        %  specified as a scalar. This argument must be between 0 and 1
                        % default: 0.95
    end

    properties (Dependent)
        paramRes
        errors
    end

    methods
        %constructor
        function obj = FDdataFit(model)
            arguments
                model   fitmodelDef = [];
            end
            % if isa(model, 'fitmodelDef')
            %     obj.model = model;
            % else
            %     error('No valid fitmodel definition for FDdata given.')
            % end
            if ~isempty(model)
                obj.model = model;
                obj.fitOptions = fitoptions(obj.model.fitType);
            end
        end

        %output either data table or index vector (esp. convert [start,end] to (start:end) vector)
        function data = get.data(obj)
            if istable(obj.data)
                data = obj.data;
            elseif isvector(obj.data)
                if numel(obj.data)==2
                    data = (obj.data(1):obj.data(2));
                else
                    data = obj.data;
                end
            else
                data = [];
            end
        end

        function val = get.paramRes(obj)
            if ~isempty(obj.cfit)
                val = coeffvalues(obj.cfit).*10.^obj.model.parameterNexponents(~obj.model.parameter_isfixed);
            else
                val = nan(size(obj.model.varPars));
            end

        end

        function val = get.errors(obj)
            if ~isempty(obj.cfit)
                val = (confint(obj.cfit, obj.confLevel) - coeffvalues(obj.cfit)) .* ...
                    10.^obj.model.parameterNexponents(~obj.model.parameter_isfixed);
            else
                val = [];
            end
        end

        function val = isempty(obj)
            if numel(obj) == 0
                val = true;
            elseif isscalar(obj)
                val = isempty(obj.model);
            else
                val = false(size(obj));
                for ii=1:numel(obj)
                    val(ii) = isempty(obj(ii));
                end
            end
        end
        
    end

    methods %main functions

        function obj = addFitoptions(obj, varargin)
            allowedOptions = {'Normalize',...
                                'Exclude',...
                                'Weights',...
                                'Method',...
                                'Robust',...
                                'StartPoint',...
                                'Lower',...
                                'Upper',...
                                'Algorithm',...
                                'DiffMinChange',...
                                'DiffMaxChange',...
                                'Display',...
                                'MaxFunEvals',...
                                'MaxIter',...
                                'TolFun',...
                                'TolX'};
            opts = obj.parseArguments(varargin, allowedOptions);
            foundOptsNames = fieldnames(opts);
            for optName = foundOptsNames
                obj.fitOptions.(optName{1}) = opts.(optName{1});
            end
            %obj.fitOptions = fitoptions(obj.fitOptions);
        end


        function obj = fit(obj, varargin)
            allowedArgs = {'XData','YData'};
            defArgs = {[], []};
            args = obj.parseArguments(varargin, allowedArgs, defArgs);
            if isempty(args.XData) && istable(obj.data)
                args.XData = obj.data.x;
            end
            if isempty(args.YData) && istable(obj.data)
                args.YData = obj.data.y;
            end

            if obj.model.isLinear
                %include bounds.
                lbounds = obj.model.parameter_lbounds(~obj.model.parameter_isfixed);
                obj = obj.addFitoptions('Lower', lbounds);

                ubounds = obj.model.parameter_ubounds(~obj.model.parameter_isfixed);
                obj = obj.addFitoptions('Upper', ubounds);   

                obj = obj.addFitoptions('Robust', 'Bisquare');
            end


            %modify standard options
            if obj.model.isNonLinear
                %options only for user defined model
                if ...isempty(obj.fitOptions.StartPoint) && 
                   ~any(isnan(obj.model.parametervalues))
                    startvals = obj.model.parameterNvalues(~obj.model.parameter_isfixed);
                    obj = obj.addFitoptions('StartPoint', startvals);
                end
%                 if obj.fitOptions.TolX == 1e-6 && istable(obj.data)
%                     obj.fitOptions.TolX = max(eps*100, 1e-8 * max(obj.data.y));
%                 end

                if any(~isnan(obj.model.parameter_lbounds(~obj.model.parameter_isfixed)))
                    lbounds = obj.model.parameter_lbounds(~obj.model.parameter_isfixed).*...
                        10.^(obj.model.parameterNexponents(~obj.model.parameter_isfixed)*(-1));
                    lbounds(isnan(lbounds)) = -Inf;
                    obj = obj.addFitoptions('Lower', lbounds);
                end

                if any(~isnan(obj.model.parameter_ubounds(~obj.model.parameter_isfixed)))
                    ubounds = obj.model.parameter_ubounds(~obj.model.parameter_isfixed).*...
                        10.^(obj.model.parameterNexponents(~obj.model.parameter_isfixed)*(-1));
                    ubounds(isnan(ubounds)) = Inf;
                    obj = obj.addFitoptions('Upper', ubounds);
                end

                %Since TolX criterion is obviously NOT scaled, here the
                %scaling is done outside: determine if x- and y-data have
                %exponents <-3 or >3. If yes extract the exponent (div3) and
                %insert it in the model definition. It will use this to
                %modify the function definition.
                %WARNING: In the resulting cfit object, the normalized function 
                %"useFctN" is stored wher units with prefixes have to be
                %used.
                if abs(log10(max(args.XData)))>3
                    exponentX = 3*floor(log10(max(args.XData))/3);
                else
                    exponentX = 0;
                end 
                obj.model.independentNexp = exponentX;
                if abs(log10(max(args.YData)))>3 
                    exponentY = 3*floor(log10(max(args.YData))/3);
                else
                    exponentY = 0;
                end
                obj.model.dependentNexp = exponentY;

                ft = obj.model.fitTypeN;
            else
                exponentX = 0;
                exponentY = 0;
                ft = obj.model.fitType;
            end

            %test function evaluation:


            %if isempty(obj.cfit)
                [obj.cfit, obj.gof, obj.outp] = fit(args.XData*10^(-exponentX), args.YData*10^(-exponentY), ft, obj.fitOptions);
            %else
            %    warning('Fit überschrieben!');
            %end
        end

        function ys = funcRes(obj, xs)
            if ~isempty(obj.paramRes)
                paramVals = num2cell(obj.paramRes);
                ys = obj.model.useFct(paramVals{:},xs);
            else
                val = [];
            end
        end

        
        function lh = plot(obj, varargin)
            %Syntax:
            %plot(obj)
            %plot(obj, Name, Value)
            %plot(obj, parent)
            %plot(obj, parent, Name, Value)

            allowedArgs = {'XData','YData','Units', 'DataName', 'ShowModelName'};
            defArgs = {[], [], 'raw', [], false};
            args = obj.parseArguments(varargin, allowedArgs, defArgs);
            if isempty(args.XData) && istable(obj.data)
                args.XData = obj.data.x;
            end
            if isempty(args.YData) && istable(obj.data)
                args.YData = obj.data.y;
            end

            if isempty(args.fst)
                args.Axis = gca;
            else 
                args.Axis = args.fst;
            end

            xName = [obj.model.independentdescription '  \it' obj.model.independent '\rm '];
            yName = [obj.model.dependentdescription '  \it' obj.model.dependent '\rm '];
            
            if strcmp(args.Units, 'raw')
                if isempty(args.XData)
                    lh = plot(obj.cfit);
                    lh.XData = lh.XData*10^(obj.model.independentNexp);
                    lh.YData = lh.YData*10^(obj.model.dependentNexp);
                elseif isempty(args.YData)
                    lh = plot(args.Axis, args.XData, obj.funcRes(args.XData), '-g');
                else
                    lh = plot(args.Axis, args.XData, obj.funcRes(args.XData), '-r',...
                        args.XData, args.YData, '.b');
                end

                xUnit = obj.model.independentdim;
                yUnit = obj.model.dependentdim;
               
            else

                if isempty(args.XData)
                    lh = plot(obj.cfit);
                elseif isempty(args.YData)
                    lh = plot(args.Axis, args.XData*10^(-obj.model.independentNexp), obj.cfit(args.XData*10^(-obj.model.independentNexp)), '-g');
                else
                    lh = plot(args.Axis, args.XData*10^(-obj.model.independentNexp), obj.cfit(args.XData*10^(-obj.model.independentNexp)), '-r',...
                        args.XData*10^(-obj.model.independentNexp), args.YData*10^(-obj.model.dependentNexp), '.b');
                end

                xUnit = obj.model.independentNdim;
                yUnit = obj.model.dependentNdim;

            end

            xlabel(args.Axis, [xName ' / ' xUnit]);
            ylabel(args.Axis, [yName ' / ' yUnit]);
            
            if args.ShowModelName
                lh(1).DisplayName = 'fitted curve';
            else
                lh(1).DisplayName = obj.model.ID;
            end
            if numel(lh)>1
                if isempty(args.DataName)
                    lh(2).DisplayName = 'data';
                else
                    lh(2).DisplayName = args.DataName;
                end
            end

        end
    end


    methods (Access = private) %other helper functions
    function argstruct = parseArguments(obj, args, argNames, varargin)
            %check input
             if nargin > 3
                if nargin > 4
                    error('Too many input values.');
                else
                    defValues = varargin{1};
                    if length(defValues) ~= length(argNames)
                        error('Number of arguments and default values does not match.')
                    elseif ~iscell(defValues)
                        error('Default values are not given as cell.')
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
                        warning(['Unknown argument ' argfields{ii} '.']);
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
                            else, error(['Unknown argument ' args{1} ' .']);
                            end
                            args(1:2) = [];
                        else, error('Wrong input.'); 
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

end