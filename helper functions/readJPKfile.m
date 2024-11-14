function out = readJPKfile(filename)
file = fopen(filename);

lineNo = 0;
segmentNo = 0;
cont_to_read_file = true;
lastline = 'none';
fullStruct = struct();

while cont_to_read_file
    lineNo = lineNo+1;
    act_line = fgetl(file);

    if isnumeric(act_line) && act_line == -1
        cont_to_read_file = false;
    elseif isempty(act_line)
        %skip empty lines
    elseif act_line(1) == '#'   % '#' indicates header lines
        if ~strcmp(lastline, 'header')
            segmentNo = segmentNo + 1;
        end
        if length(act_line)>2
            %read line
            thisLineCell = textscan(act_line(3:end), '%q');
            thisLineCell = thisLineCell{1};
            %properties are divided by a ":" from their values
            %if a property is detected, modify its name to be used as
            %fieldName in the result structure
            if thisLineCell{1}(end) == ':'
                fieldname = thisLineCell{1}(1:end-1);
                %modify name: remove "-" and convert name to "camelCase"
                minSignPos = strfind(fieldname, '-');
                fieldname(minSignPos + 1) = upper(fieldname(minSignPos + 1));
                fieldname(minSignPos) = [];
                %modify name: .%d. to (%d). 
                fieldname = regexprep(fieldname, '[.](\d+)[.]', '($1+1).');
                %read value and convert to number if number is detected.
                if length(thisLineCell) > 2
                    fieldContent = thisLineCell(2:end);
                elseif length(thisLineCell) > 1
                    fieldContent = thisLineCell{2};
                    if ~any(isnan(str2double(fieldContent)))
                        fieldContent = str2double(fieldContent);
                    end
                else %field has no value
                    fieldContent = [];
                end
                try
                    %since "fieldname" might contain a sequence of
                    %subfields (e.g. globalSetting.pixelClock.Name) we need
                    %"eval" here.
                    eval(['fullStruct(segmentNo).' fieldname ' = fieldContent;']);
                catch
                    disp(['Warning: Parameter ' fieldname ' not loaded due to error.']);
                end

            end
        end
        lastline = 'header';
    else
        thisLine = textscan(act_line, '%f');
        thisLine = thisLine{1};
        if ~isfield(fullStruct, 'Data') || isempty(fullStruct(segmentNo).Data)
            fullStruct(segmentNo).Data = thisLine';
        else
            fullStruct(segmentNo).Data(end+1,:) = thisLine';
        end
        lastline = 'data';
    end

end
fclose(file);

out = fullStruct;
