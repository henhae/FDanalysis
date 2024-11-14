classdef fitmodelDef
    %class for setting up a fit model and use in curve fit, either for
    %linear or non-linear fit models
    
    % the class features a check for fixed and variable parameters and
    % provides the correct anonymous function for the fit function

    %TODO: for linear models, a distinction between coefficients (for the
    %indiviual terms) and parameters exists. A functional relation between
    %those and appropriate checks still have to be implemented. 
    % (e.g. f(x) = a*x + b*x^3, where a = pi*sigma * R and b = pi*E/(6*R^2) 
    % then sigma, R and E would be the parameters; however, with only two 
    % coeffients, at least one parameters needs to be fixed.)


properties (Access = public)
    ID                      %short, identifying name of the model
    name                    %long name of the model
    description             %Description of the model
    category                %Category name for the model to be sorted in
    
    % for linear models: display parameters and not linear coefficients
    
    parameterdescription    %cell array of strings: short description of the parameter
    parametervalues         %numeric: standard/start values in basic SI units, NaN if not set
    parameterdims           %cell array of strings: basic SI units of the parameter
    parameter_isfixed       %logical: true if parameter should not vary in fit
    parameter_ubounds       %upper bounds for parameters, default: Inf
    parameter_lbounds       %upper bounds for parameters, default: -Inf

    dependent               %char: name of dependent variable (function result), default: y
    dependentdim            %char: unit of dependent variable (should be in SI)
    independentdim          %char: unit of independent variable (should be in SI)
    dependentdescription = ''
    independentdescription = ''
    coeffdims               %cell array of strings: units of the coefficients of the linear model
    independentNexp
    dependentNexp
end

properties (SetAccess = protected)
    %these properties are extracted from function input
    inputfunction   % as input given: either anonymous function or cell of linear terms
    parameters      % cell array of strings: names of all parameters
    independent     % char: name of the independent variable (default x)
    coefficients    % cell array of strings: names of coefficients for linear models
    %TODO
    fitDataType     % char/cell array of str: type or class of intended fit data (check for certain class property should be possible)
end

properties (Dependent)
    modelfunction   % fct handle: function definition (params sorted)
    modelfunctionStr% char: function definition as used for fittype (params sorted)
    varDec          % char: variable declaration part of function definition
    funcStr         % char: function string w/o variable declaration
    varPars         % cell array of strings: names of variable parameters
    fixedPars       % cell array of strings: names of fixed parameters
    useFct          % directly usable function including fixed parameters
    fitType
    fitOptions
    parameterNvalues % parameter values in SI units with prefix
    parameterNdims  % cell array of strings: SI units with prefix of the parameter
    parameterNexponents % 
    % parametervalues = parameterNvalues.*10.^parameterNexponents or
    % parametervalues (parameterdims) = parameterNvalues (parameterNdims)
    dependentNdim   %char: unit of dependent variable in SI with prefix
    independentNdim %char: unit of independent variable in SI with prefix
    funcStrN
    modelfunctionStrN
    useFctN
    fitTypeN

    isLinear        %bool: true if is linear model defined by cell
    isNonLinear     %bool: true if is nonlinear model
end

methods
    %constructor
    function obj = fitmodelDef(varargin)
        allowedOptions = {'ID', 'Name', 'Description', 'Category', 'Function'...
            ,'Parameters', 'ParameterValues', 'ParameterUnits', 'ParameterDescription'...
            ,'ParameterUBounds', 'ParameterLBounds'...
            ,'Coefficients', 'CoeffUnits'...
            ,'XName', 'XUnit','XDescription', 'YName', 'YUnit', 'YDescription'};
        if numel(varargin) == 1 && isstruct(varargin{1})
            input = varargin{1};
        else
            input = varargin;
        end
        if isempty(input)
            args = [];
        else
            args = fitmodelDef.parseArguments(input, allowedOptions);
            obj(numel(args)) = obj;
        end

        for ii = 1:numel(args)
            obj(ii) = obj(ii).fillObject(args(ii));
        end

    end

    function val = isempty(obj)
        val = isempty(obj.ID) && isempty(obj.inputfunction);
    end

    function obj = fillObject(obj, args)

        if isfield(args, 'ID')
            obj.ID = args.ID;
        end
        if isfield(args, 'Name')
            obj.name = args.Name;
        end
        if isfield(args, 'Description')
            obj.description = args.Description;
        end
        if isfield(args, 'Category')
            obj.category = args.Category;
        end
        
        %function definition
        if isfield(args, 'fst')
            obj = obj.setModelfunction(args.fst);
        elseif isfield(args, 'Function')
            obj = obj.setModelfunction(args.Function);
        elseif nargin > 0
            error('No model function given.')
        end

        if isfield(args, 'Coefficients')
            if isa(obj.inputfunction,"function_handle")
                warning('"Coefficients" is only used for linear models. Use "Parameters" to define parameters for nonlinear models.');
            else
                if numel(args.Coefficients) ~= numel(obj.inputfunction)
                    error('Number of coefficients does not fit number of linear terms.')
                end
                obj.coefficients = args.Coefficients;
                if iscolumn(obj.coefficients)
                    obj.coefficients = obj.coefficients';
                end

                if ~isfield(args, 'Parameters')
                    obj.parameters = args.Coefficients;
                end
            end
        elseif isa(obj.inputfunction,"function_handle")
            %TODO: if linear model is given but coefficients are not named...

        end
        
        if isfield(args, 'CoeffUnits')
            if isa(obj.inputfunction,"function_handle")
                warning('"Coefficients" is only used for linear models. Use "Parameters" to define parameters for nonlinear models.');
            else
                obj.coeffdims = args.CoeffUnits;
                if iscolumn(obj.coeffdims)
                    obj.coeffdims = obj.coeffdims';
                end
                if ~isfield(args, 'ParameterUnits')
                    obj.parameterdims = args.CoeffUnits;
                end
            end
        end 

        if isfield(args, 'Parameters')
            if isa(obj.inputfunction,"function_handle")
                warning(['Parameters are determined from declaration of anonymous function. "Parameters" input is ignored. '...
                    'Please check that order of any other parameter related input is correct.']);
            else
                obj.parameters = args.Parameters;
                %ToDo: check that all parameters can be calculated from linear
                %coefficients
                if iscolumn(obj.parameters)
                    obj.parameters = obj.parameters';
                end
            end            
        end

        if isfield(args, 'ParameterValues')
            if ischar(args.ParameterValues) || isstring(args.ParameterValues)
                obj.parametervalues = str2num(args.ParameterValues);
            elseif isnumeric(args.ParameterValues)
                obj.parametervalues = args.ParameterValues;
            end
            if iscolumn(obj.parametervalues)
                obj.parametervalues = obj.parametervalues';
            end
        end
        if isfield(args, 'ParameterUnits')
            obj.parameterdims = args.ParameterUnits;
            if iscolumn(obj.parameterdims)
                obj.parameterdims = obj.parameterdims';
            end
        end
        if isfield(args, 'ParameterDescription')
            obj.parameterdescription = args.ParameterDescription;
            if iscolumn(obj.parameterdescription)
                obj.parameterdescription = obj.parameterdescription';
            end
        end
        
        %parameter bounds 
        % automatic definition must come after parameter determination from function
        if isfield(args, 'ParameterUBounds')
            if ischar(args.ParameterUBounds) || isstring(args.ParameterUBounds)
                obj.parameter_ubounds = str2num(args.ParameterUBounds);
            elseif isnumeric(args.ParameterUBounds)
                obj.parameter_ubounds = args.ParameterUBounds;
            end
        elseif ~isempty(obj.parameters)
            obj.parameter_ubounds = Inf(size(obj.parameters));
        else
            obj.parameter_ubounds = [];
        end
        if iscolumn(obj.parameter_ubounds)
            obj.parameter_ubounds = obj.parameter_ubounds';
        end

        if isfield(args, 'ParameterLBounds')
            if ischar(args.ParameterLBounds) || isstring(args.ParameterLBounds)
                obj.parameter_lbounds = str2num(args.ParameterLBounds);
            elseif isnumeric(args.ParameterLBounds)
                obj.parameter_lbounds = args.ParameterLBounds;
            end
        elseif ~isempty(obj.parameters)
            obj.parameter_lbounds = -Inf(size(obj.parameters));
        else
            obj.parameter_lbounds = [];
        end
        if iscolumn(obj.parameter_lbounds)
            obj.parameter_lbounds = obj.parameter_lbounds';
        end
                
        if isfield(args, 'XName')
            if isa(obj.inputfunction,"function_handle")
                warning('X value name is determined from declaration of anonymous function. "XName" input is ignored.');
            else
                obj.independent = args.XName;
                %ToDO: check if args.XName is in every term
            end
        elseif (isfield(args, 'fst') && iscell(args.fst)) || ... %iscell(obj.inputfunction)
                (isfield(args, 'Function') && iscell(args.Function)) 
            obj.independent = 'x';
        end

        if isfield(args, 'YName')
            obj.dependent = args.YName;
        else
            obj.dependent = 'y';
        end

        if isfield(args, 'XUnit')
            obj.independentdim = args.XUnit;
        end
        if isfield(args, 'YUnit')
            obj.dependentdim = args.YUnit;
        end

        if isfield(args, 'XDescription')
            obj.independentdescription = args.XDescription;
        end

        if isfield(args, 'YDescription')
            obj.dependentdescription = args.YDescription;
        end


        obj.independentNexp = 0;
        obj.dependentNexp = 0;

    end
end

methods
    function obj = setModelfunction(obj, fct)
        

        if isa(fct,"function_handle")
            obj = obj.includeAnonymousFct(fct);
        elseif ischar(fct) || isStringScalar(fct)
            fct = str2func(fct);
            obj = obj.includeAnonymousFct(fct);
        elseif iscell(fct)
            %ToDo: checks
            if iscolumn(fct)
                fct = fct';
            end
            obj = obj.setLinearFunction(fct);
            obj.inputfunction = fct;
        else
            warning('No valid function handle provided. Skip.')
            return
        end
        
    end

    function obj = setLinearFunction(obj, fct)        
        obj.parameter_isfixed = false(size(fct));
        obj.parametervalues = nan(size(fct));
    end

    function obj = includeAnonymousFct(obj,fct)
        funcInf = functions(fct);
        if ~strcmp(funcInf.type, 'anonymous')
            error('Please provide an anonymous function.')    
        end
        obj.inputfunction = fct;
        fct_str = func2str(fct);
        
        % select variable declaration and function string from Function Input
        varDecStrBegIdx = find('('== fct_str,1);
        varDecStrEndIdx = find(')'== fct_str,1);
        varDecStr = fct_str(varDecStrBegIdx+1:varDecStrEndIdx-1);
        vars = strtrim(strsplit(varDecStr,','));
        functionStr = fct_str(varDecStrEndIdx+1:end);

        % check and set independent
        if ~(vars{end} == 'x')
            warning(['The last input variable must be the independent variable. ' ...
                'Instead of the default "x", ' vars{end} ' was found and will be used.'])
        end
        obj.independent = vars{end};

        % check and set parameters
        for ii=1:numel(vars)
            if ~contains(functionStr, vars{ii})
                warning(['The variable "' vars{ii} '" seems not to appear in the function.']);
                %keep nonetheless?
            end
        end
        obj.parameters = vars(1:end-1);
        obj.parametervalues = nan(size(obj.parameters));
        obj.parameterdims = cell(size(obj.parameters));
        obj.parameterdescription = cell(size(obj.parameters));
        
        %if function was redefined, check if fixed parameters can remain
        if isempty(obj.fixedPars)
            canBeKept = false;
        else
            canBeKept = true;
            for ii=1:numel(obj.fixedPars)
                canBeKept = canBeKept & any(strcmp(obj.fixedPars, vars(1:end-1)));
            end
        end
        if ~canBeKept
            obj.parameter_isfixed = false(size(obj.parameters));
        end

    end
end

methods    %get methods of dependent properties

    function obj = set.parameter_isfixed(obj, inval)
        if obj.isLinear && sum(inval) > 0
            error('Setting a parameter as fixed is not implemented for a linear model, yet.')
        else
            obj.parameter_isfixed = inval;
        end
    end

    function val = get.varDec(obj)
        if obj.isLinear
            coeffcell = obj.coefficients;
        else
            coeffcell = [obj.varPars,obj.fixedPars];
        end

        val = [strjoin(coeffcell,',') ',' obj.independent];
    end

    function val = get.funcStr(obj)
        if obj.isLinear
            funcCell = cellfun(@(x,y) [x '*' y], obj.coefficients, obj.inputfunction, UniformOutput=false);
            val = strjoin(funcCell, '+');
        else
            fct_str = func2str(obj.inputfunction);
            varDecStrEndIdx = find(')'== fct_str,1);
            val = fct_str(varDecStrEndIdx+1:end);
        end

    end

    function val = get.modelfunction(obj)
        val = str2func(obj.modelfunctionStr);
    end

    function val = get.modelfunctionStr(obj)
        val = ['@(' obj.varDec ')' obj.funcStr];
    end

    %get parameter names of free parameters
    function val = get.varPars(obj)
        val = obj.parameters(~obj.parameter_isfixed);
    end

    %get parameter names of fixed parameters
    function val = get.fixedPars(obj)
        val = obj.parameters(obj.parameter_isfixed);
    end
    
    %construct fittype object from stored function
    function val = get.fitType(obj)

        %linear coeff. function
        if obj.isLinear
            if isempty(obj.coefficients)
                val = fittype(obj.inputfunction, ...
                    "independent", obj.independent,...
                    "dependent", obj.dependent);
            else
                val = fittype(obj.inputfunction, ...
                    "independent", obj.independent,...
                    "dependent", obj.dependent,...
                    "coefficients", obj.coefficients);
            end

        %function with nonlinear coefficients

        %check if this can be substitued by just "fittype(obj.useFct,..."

        elseif obj.isNonLinear && ischar(obj.modelfunctionStr)
            if any(obj.parameter_isfixed)
                if isempty(obj.parametervalues)
                    error('Parameters are set as fixed but no values are given.')
                end
                
                %alternative: no "problem" parameters. declare fixed values
                %as workspace parameters and include them in function
                %definition.
                fctStr = ['@(' strjoin([obj.varPars],',') ',' obj.independent ')'...
                    obj.funcStr];
                
                fixedParsIdx = find(obj.parameter_isfixed);
                for ii = fixedParsIdx
                    if isnan(obj.parametervalues(ii))
                        error(['No value for fixed parameter ' obj.parameters{ii} '  given.'])
                    end
                    eval([obj.parameters{ii} ' = ' num2str(obj.parametervalues(ii)) ';']);
                end
                %doesn't work without eval: str2func does not take
                %workspace variables into account when defining the function.
                eval(['fct = ' fctStr ';']);
                val = fittype(fct,...
                    "independent", obj.independent,...
                    "dependent", obj.dependent);

%                 val = fittype(obj.modelfunction,...
%                     "independent", obj.independent, ...
%                     "problem", obj.fixedPars);
            else
                val = fittype(obj.modelfunction,...
                    "independent", obj.independent,...
                    "dependent", obj.dependent);
            end
        end
    end

    %construct fitoptions object for use in fit: use fitType and other
    %stored option (ToDo)
    function val = get.fitOptions(obj)
        val = fitoptions(obj.fitType);
    end

    function val = get.useFct(obj)
        %parameter name must be surrounded by either mathematical
        %operations, whitespace or be at the end of the string.
        mathOpsPattern = characterListPattern("+-*/^.,()");
        boundaryPattern = whitespacePattern | textBoundary | mathOpsPattern;
        befPat = lookBehindBoundary(boundaryPattern);
        aftPat = lookAheadBoundary(boundaryPattern);

        if obj.isLinear
            %TODO: modify for fixed parameters and if parameters are
            %defined as functions of linear coefficients
            functionStr = obj.funcStr;
            for ii = 1:numel(obj.parameters)
                if obj.parameter_isfixed(ii)
                    thisPat = befPat + obj.parameters{ii} + aftPat;
                    modParamStr = "(" + num2str(obj.parametervalues(ii)) + ")";
                    functionStr = replace(functionStr, thisPat, modParamStr);
                end
            end

        else    % non-linear models

            functionStr = obj.funcStr;

            for ii=1:numel(obj.parameters)
                if obj.parameter_isfixed(ii)
                    thisPat = befPat + obj.parameters{ii} + aftPat;
                    modParamStr = "(" + num2str(obj.parametervalues(ii)) + ")";
                    functionStr = replace(functionStr, thisPat, modParamStr);
                end
            end
        end
        
        newfuncStr = functionStr;            
        val = str2func(['@(' strjoin([obj.varPars],',') ',' obj.independent ')' newfuncStr]);
    end

    function values = get.parameterNvalues(obj)
        [values, ~, ~] = obj.addSIPrefix(obj.parametervalues, obj.parameterdims);
    end

    function values = get.parameterNdims(obj)
        [~, ~, values] = obj.addSIPrefix(obj.parametervalues, obj.parameterdims);
    end

    function values = get.dependentNdim(obj)
        [~, ~, values] = obj.addSIPrefix(10^obj.dependentNexp, obj.dependentdim);
    end

    function values = get.independentNdim(obj)
        [~, ~, values] = obj.addSIPrefix(10^obj.independentNexp, obj.independentdim);
    end

    function values = get.parameterNexponents(obj)
        [~, values, ~] = obj.addSIPrefix(obj.parametervalues, obj.parameterdims);
        values(isnan(values)) = 0;
    end

    %construct function string with parameters to be used in units with prefix
    %The exponent corresponding to the prefix will be included in the function.
    function val = get.funcStrN(obj)
        val = obj.funcStr;

        %parameter name must be surrounded by either mathematical
        %operations, whitespace or be at the end of the string.
        mathOpsPattern = characterListPattern("+-*/^.,()");
        boundaryPattern = whitespacePattern | textBoundary | mathOpsPattern;
        befPat = lookBehindBoundary(boundaryPattern);
        aftPat = lookAheadBoundary(boundaryPattern);

        for ii=1:numel(obj.parameters)
            if ~isnan(obj.parameterNvalues(ii)) && obj.parameterNexponents(ii) ~= 0
                thisPat = befPat + obj.parameters{ii} + aftPat;
                modParamStr = "(" + obj.parameters{ii}+ '*1e' +num2str(obj.parameterNexponents(ii)) + ")";
                val = replace(val, thisPat, modParamStr);
            end
        end

    end

    function val = get.modelfunctionStrN(obj)
        val = ['@(' obj.varDec ')' obj.funcStrN];
    end

    function val = get.useFctN(obj)

        if obj.isLinear
            %TODO: modify for fixed parameters and if parameters are
            %defined as functions of linear coefficients
            fct_str = obj.funcStr;
            if find('@'== fct_str,1)
                varDecStrEndIdx = find(')'== fct_str,1);
                newfuncStr = fct_str(varDecStrEndIdx+1:end);
                for ii = 1:numel(obj.parameters)
                    if obj.parameter_isfixed(ii)
                        newfuncStr = strrep(newfuncStr, [obj.parameters{ii} '*'], [num2str(obj.parametervalues(ii)) '*'] );
                    end
                end
            else
                newfuncStr = '';
            end

        else    % non-linear models
             functionStr = obj.funcStr;
             functionStr = convertCharsToStrings(functionStr);

            %parameter name must be surrounded by either mathematical
            %operations, whitespace or be at the end of the string.
            mathOpsPattern = characterListPattern("+-*/^.,()");
            boundaryPattern = whitespacePattern | textBoundary | mathOpsPattern;
            befPat = lookBehindBoundary(boundaryPattern);
            aftPat = lookAheadBoundary(boundaryPattern);

            for ii=1:numel(obj.parameters)
                thisPat = befPat + obj.parameters{ii} + aftPat;
                %if parameter is fix, substitute with its value
                if obj.parameter_isfixed(ii)
                    modParamStr = "(" + num2str(obj.parametervalues(ii)) + ")";
                    functionStr = replace(functionStr, thisPat, modParamStr);
                    %else substitute with its name and prefix exponent (if not zero)
                elseif ~isnan(obj.parameterNvalues(ii)) && obj.parameterNexponents(ii) ~= 0
                    modParamStr = "(" + obj.parameters{ii}+ '*1e' +num2str(obj.parameterNexponents(ii)) + ")";
                    functionStr = replace(functionStr, thisPat, modParamStr);
                end
            end

            if ~isempty(obj.independentNexp) && obj.independentNexp ~= 0
                 thisPat = befPat + obj.independent + aftPat;
                 modParamStr = "(" + obj.independent + '*1e' +num2str(obj.independentNexp) + ")";
                 functionStr = replace(functionStr, thisPat, modParamStr);
            end

            if ~isempty(obj.dependentNexp) && obj.dependentNexp ~= 0
                functionStr = "(" + functionStr + ')*(1e'+ num2str(obj.dependentNexp*(-1)) + ")";
            end

            newfuncStr = functionStr;
            
        end
        val = str2func(strjoin(['@(' strjoin([obj.varPars],',') ',' obj.independent ')' newfuncStr]));
    end

    function val = get.fitTypeN(obj)

        %linear coeff. function
        if obj.isLinear 
            if isempty(obj.coefficients)
                val = fittype(obj.inputfunction, ...
                    "independent", obj.independent,...
                    "dependent", obj.dependent);
            else
                val = fittype(obj.inputfunction, ...
                    "independent", obj.independent,...
                    "dependent", obj.dependent,...
                    "coefficients", obj.coefficients);
            end

        %function with nonlinear coefficients

        %check if this can be substitued by just "fittype(obj.useFct,..."

        elseif obj.isNonLinear && ischar(obj.modelfunctionStr)
            val = fittype(obj.useFctN,...
                    "independent", obj.independent,...
                    "dependent", obj.dependent);
        end
    end

    function val = get.isLinear(obj)
        val = (~isempty(obj.inputfunction) & iscell(obj.inputfunction));
    end

    function val = get.isNonLinear(obj)
        val = (~iscell(obj.inputfunction) & isa(obj.inputfunction, "function_handle"));
    end

end

methods (Access = public)
    function val = export2struct(obj)
        templ = struct('ID',''...
                ,'Name',''...
                ,'Description',''...
                ,'Category',''...
                ,'YName',''...
                ,'YDescription',''...
                ,'YUnit',''...
                ,'XDescription',''...
                ,'XUnit',''...
                ,'ParameterLBounds',[]...
                ,'ParameterUBounds',[]...
                ,'ParameterDescription',''...
                ,'ParameterUnits',''...
                ,'ParameterValues',[]...
                ,'XName',''...
                ,'Parameters',''...
                ,'Coefficients',''...
                ,'CoeffUnits','' ...
                ,'Function','' ...
                );

        for ii = 1:numel(obj)
            temp_str = templ;
            temp_str.ID = obj(ii).ID;
            temp_str.Name = obj(ii).name;
            temp_str.Description = obj(ii).description;
            temp_str.Category = obj(ii).category;
            temp_str.YName = obj(ii).dependent;
            temp_str.YDescription = obj(ii).dependentdescription;
            temp_str.YUnit = obj(ii).dependentdim;
            temp_str.XDescription = obj(ii).independentdescription;
            temp_str.XUnit = obj(ii).independentdim;
            temp_str.ParameterLBounds = obj(ii).parameter_lbounds;
            temp_str.ParameterUBounds = obj(ii).parameter_ubounds;
            temp_str.ParameterDescription = obj(ii).parameterdescription;
            temp_str.ParameterUnits = obj(ii).parameterdims;
            temp_str.ParameterValues = obj(ii).parametervalues;
    
            if obj(ii).isLinear
                temp_str.XName = obj(ii).independent;
                temp_str.Parameters = obj(ii).parameters;
                temp_str.Coefficients = obj(ii).coefficients;
                temp_str.CoeffUnits = obj(ii).coeffdims;
                temp_str.Function = obj(ii).inputfunction;
            else
                temp_str.Function = func2str(obj(ii).inputfunction);
            end

            val(ii) = temp_str;
        end
    end

    function val = jsonencode(obj, varargin)
        objstruct = obj.export2struct();

        for ii = 1:numel(objstruct)
            objstruct(ii).ParameterLBounds = num2str(objstruct(ii).ParameterLBounds);
            objstruct(ii).ParameterUBounds = num2str(objstruct(ii).ParameterUBounds);
            objstruct(ii).ParameterValues = num2str(objstruct(ii).ParameterValues);
        end

        val = jsonencode(objstruct, varargin{:});
    end

end

methods (Access = private, Static) %other helper functions
    function argstruct = parseArguments(args, argNames, varargin)
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
            argstruct = args;
        
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
                        else, error(['Unknown argument "' args{1} '" .']);
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

    function [new_val, exponent, new_dim] = addSIPrefix(val, SIUnits)
        unitprefix = {'P' 'T' 'G', 'M', 'k', '', 'm', 'µ', 'n', 'p', 'f', 'a'};
        prefix_exponent = [15 12 9 6 3 0 -3 -6 -9 -12 -15 -18];

        if ischar(SIUnits)
            SIUnits = {SIUnits};
        end
        
        new_val = val;
        exponent = 3*floor(log10(val)/3);
        new_dim = SIUnits;

        for ii = 1:length(exponent)
            if exponent(ii) < -18
                exponent(ii) = -18;
            elseif exponent(ii) > 15
                exponent(ii) = 15;
            end
            new_dim{ii} = [unitprefix{exponent(ii) == prefix_exponent}, SIUnits{ii}];
            new_val(ii) = val(ii) .* 10.^(-exponent(ii));
        end

        if numel(new_val)==1
            new_dim = new_dim{1};
        end


    end
end

end