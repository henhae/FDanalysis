function writeTableWithUnits(T, file, varargin)
        %write table normally with all arguments
        writetable(T, file, varargin{:});

        %get passed arguments
        poss_args = {'FileType', 'WriteVariableNames', 'WriteRowNames', 'DateLocale', ...
            ...%TextFiles only: 
            'Delimiter', 'QuoteStrings', 'Encoding', ...
            ...%SpreadSheets only: 
            'Sheet', 'Range', 'UseExcel'};
        args = parseArguments(varargin, poss_args);
        
        %write units only if VariableNames are also written
        if ~(isfield(args, 'WriteVariableNames') && ~logical(args.WriteVariableNames) )
                    
            %import written file to cell array
            Tfile = fopen(file);
            act_line = fgets(Tfile);

            if ischar(act_line)
                CellFile = cell(2,1);
                ii = 1;
                while ischar(act_line)
                    CellFile{ii} = act_line;
                    act_line = fgets(Tfile);
                    ii = ii+1;
                end
            end
            fclose(Tfile);
            endchar = CellFile{1}(end);
            
            %insert units line as second line
            if isfield(args, 'Delimiter')
                delim = args.Delimiter;
            else
                delim = ',';
            end
            
            unitsline = sprintf(['%s' delim], T.Properties.VariableUnits{:});
            unitsline = [unitsline(1:end-1) endchar];
            if isfield(args, 'WriteRowNames') && logical(args.WriteRowNames)
                unitsline = ['' delim unitsline];
            end
            
            CellFile(3:end+1) = CellFile(2:end); 
            CellFile{2} = unitsline;
            
            %overwrite file with cell contents
            Tfile = fopen(file, 'w', 'n', 'UTF-8');
            for ii = 1:length(CellFile)
                fprintf(Tfile, CellFile{ii});
            end
            fclose(Tfile);
        end




        function argstruct = parseArguments(args, argNames, varargin)
            if nargin > 2
                if nargin >3
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
            
            argstruct = struct();
            while ~isempty(args)
                if logical(mod(numel(args),2))
                    argstruct.fst = args{1};
                    args(1) = [];
                else
                    if ischar(args{1})
                        if any(strcmp(args{1}, argNames))
                            argstruct.(args{1}) = args{2};
                            args(1:2) = [];
                        else, error(['Unknown argument ' args{1} ' .']);
                        end
                    else, error('Wrong input.'); 
                    end
                end
            end
            
            if nargin == 3
                %If default values are given, assign default values to all
                %fields that have not been created above.
                for iNames = 1:length(argNames)
                    if ~isfield(argstruct, argNames{iNames})
                        argstruct.(argNames{iNames}) = defValues{iNames};
                    end
                end
            end
        
        end

    end