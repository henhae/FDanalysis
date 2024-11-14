function out = readNanoscopeFile(path_to_file)
    arguments
        path_to_file {mustBeFile}
    end
    [folder ,filename, file_ext] = fileparts(path_to_file);

    file = fopen(path_to_file);
    
    lineNo = 0;
    image_no = 0;
    cont_to_read_header = true;
    lastline = 'none';
    fullStruct = struct();
    this_header_section = '';
    header = struct();
    
    %read header
    while cont_to_read_header
        lineNo = lineNo+1;
        act_line = fgetl(file);
        
        if isnumeric(act_line) && act_line == -1 %EOF
            cont_to_read_header = false;
        elseif isempty(act_line)                %skip empty lines
        elseif strcmp(act_line, '\*File list end') ...
                || strcmp (act_line, char(26))   %ctrl+Z        %end of header
            cont_to_read_header = false;
        elseif act_line(1) == '\'               % '\' indicates header lines
            if act_line(2) == '*'       %new "section"
                last_header_section = this_header_section;
                this_header_section = strtrim(act_line(3:end));
                %modify name: remove internal blanks and convert name to "camelCase"
                blankPos = strfind(this_header_section, ' ');
                this_header_section(blankPos + 1) = upper(this_header_section(blankPos + 1));
                this_header_section(blankPos) = [];
                if isempty(last_header_section)
                     fst_section = this_header_section;
                end
                %if section name was found before (e.g. 2nd channel...)
                if strcmp(last_header_section, this_header_section)
                    iSection = iSection + 1;
                else
                    iSection = 1;
                end
                %header.(this_header_section){iSection} = containers.Map;
                header.(this_header_section){iSection} = dictionary;
            else    %fill dictionary with Parameters => StrValues
                tokens = regexp(act_line, '\\(@)?(\d?:)?([^:]*):(.*)', 'tokens');
                fieldname = strjoin(tokens{1}(1:3),'');
                fieldname = strtrim(fieldname);
                %fieldname = strrep(fieldname, ' ', '_');
                header.(this_header_section){iSection}(fieldname) = char(tokens{1}{end});
            end
        
        else                   
        end
    end
    
    %break here, if nothing has been read successfully
    if isempty(header) || ~isfield(header, 'CiaoScanList')
        warning(['No Nanoscope file header. Probably corrupt file: '...
             path_to_file])
        out = [];
        return
    end

    % data
    %image or force file ?
    % if isfield(header, 'CiaoImageList')
    %     dataType = "Image";
    % elseif isfield(header, 'CiaoForceImageList') || isfield(header, 'ForceFileList')
    %     dataType = "Force";
    % end
    dataType = strtrim(header.CiaoScanList{1}('Operating mode'));
    
    switch dataType
        case "Image"
            listName = 'CiaoImageList';
        case "Force"
            listName = 'CiaoForceImageList';
        case "Force Image"
    end
    
    data = cell(length(header.(listName)),1);
        
    for ii = 1:length(data)
        thisPartList = header.(listName){ii};        

        %%%   get data
        DataOffset = str2double(thisPartList('Data offset'));
        DataLength = str2double(thisPartList('Data length'));
        BytesPerPixel = str2double(thisPartList('Bytes/pixel'));

        %from version 9.2 on, all data seem to be 32 bit.
        if str2num(header.(fst_section){1}('Version')) > 0x9200000
            BytesPerPixel = 4;
        end

        switch BytesPerPixel
            case 1
                prec = 'uint8';
            case 2
                prec = 'uint16';
            case 4
                prec = ['bit' num2str(BytesPerPixel * 8)];
            case 8
                prec = 'uint64';
        end
        
        if prec(1) ~= 'u'
            %BitsPerPixel = BitsPerPixel -1;
        end
        %BitsPerPixel = 8*BytesPerPixel;

    
        if dataType == "Image"
            pixPerLine = str2double(thisPartList('Samps/line'));
            numLines = str2double(thisPartList('Number of lines'));        
        
            if DataLength ~= pixPerLine*numLines*BytesPerPixel
                disp('Something''s wrong here...')
            end
    
        
            fseek(file, DataOffset, "bof");
            %this_channel_data= fread(file, [pixPerLine, numLines], [prec '=>' prec], 'l');
            this_channel_data= fread(file, [pixPerLine, numLines], ['*' prec], 'l');
            %fread fills columns but data in the file are scan lines starting from
            %bottom:
            data{ii} = flipud(this_channel_data');

        elseif dataType == "Force"
            pixPerLine = cellfun(@str2double, regexp(thisPartList('Samps/line'), '\s+(\d+)','tokens'));
            if DataLength < sum(pixPerLine)*BytesPerPixel
                %DataLength gives full blocked data length and thus might be 
                % larger due to reaching the setpoint, Samps/Line gives
                % actual recorded values.
                disp([filename ': DataLength < sum(pixPerLine)*BytesPerPixel: ' num2str(DataLength) '<' num2str(sum(pixPerLine)*BytesPerPixel)])
            end

            fseek(file, DataOffset, "bof");
            %this_channel_data = fread(file, sum(pixPerLine) ,[prec '=>' prec], 'l');
            this_channel_data = fread(file, sum(pixPerLine) ,['*' prec], 'l');
            
            
            %now sort this whole shit..
            %its easy for just approach/retract:
            %TODO: which is approach and which retract changed at some
            %software version. unknown when... How to do this...?
            data{ii} = NaN([max(pixPerLine) length(pixPerLine)]);
            start = 1;
            for iLine = 1:length(pixPerLine)
                data{ii}(1:pixPerLine(iLine),iLine) = this_channel_data(start:sum(pixPerLine(1:iLine)));
                start = start+pixPerLine(iLine);
            end


        end

        if ii ~= length(data) && feof(file) && false
            disp(['End of file reached while still parsing channels. '...
                '(Stopped after channel no. ' num2str(ii) ')' ]);
            out = [];
            fclose(file);
            return
        end

    end


    %%% get and parse parameters

    params = struct();
    params.ZScale = [];         %cell(size(data));
    params.ChannelName = "";    %cell(size(data));
    params.ZUnit = "";          %cell(size(data));
    params.Position = struct('X', sip2num(header.CiaoScanList{1}("X Offset")),...
            'Y', sip2num(header.CiaoScanList{1}("Y Offset")), ...
            'Unit', 'm');  % in m
    params.StagePosition = struct('X', sip2num(header.CiaoScanList{1}("Stage X")),...
            'Y', sip2num(header.CiaoScanList{1}("Stage Y")), ...
            'Z', sip2num(header.CiaoScanList{1}("Stage Z")),...
            'Unit', 'm');  % in m
    params.ScanSize = sip2num(header.CiaoScanList{1}("Scan Size")); % in m
    if contains(dataType, "Image") %parameter not necessarily present in older image files
        params.AspectRatio = pixPerLine/numLines;
    end
    if contains(dataType, "Force") %parameter not necessarily present in older image files
        params.SprConst = str2double(header.(listName){1}("Spring Constant"));
    end

    for ii = 1:length(data)
        thisPartList = header.(listName){ii};

        %%%  get channel name
        % if isKey(thisPartList, '@2:Image Data')
        %     channelName = thisPartList('@2:Image Data');
        % elseif isKey(thisPartList, '@3:Image Data')
        %     channelName = thisPartList('@3:Image Data');
        % elseif isKey(thisPartList, '@4:Image Data')
        %     channelName = thisPartList('@4:Image Data');
        if d_conv.isKeyStrPart(thisPartList, 'Image Data') && sum(d_conv.isKeyStrPart(thisPartList, 'Image Data')) == 1
            chNameEntry = parseCIAOEntry(d_conv.lookupStrPart(thisPartList, 'Image Data'));
        else
            [~, fname, ~] = fileparts(path_to_file);
            warning(['Channel ' num2str(ii) ' of file ' fname ' has corrupt header.'])
        end
        
        params.ChannelName(ii,1) = chNameEntry.chName2;

        %%%  get scale factor:
        
        %from Bruker handbook:
        %The hard scale is the scale at which the file was originally captured. 
        %However, to help minimize round off errors in the off-line processing, 
        %the software automatically scales the image data to the full range of 
        %the data word. While the hard value of the Z scale is updated, the hard
        %scale is not. Therefore, this hard scale should be ignored and we will 
        %calculate a corrected hard scale:
        % corr. hard-scale = hard-value / max(LSB)
        % ==>
        % soft-value = soft-scale * hard-value * data(in LSB) / max(LSB)
        %max(LSB) = 2^(Bytes/Pixel*8) - typically 65536 (2 Bytes/pix)
        %LSB: (least-significant bit) binary data representation


        %this is for the scaling factor which seems different than the
        %actual raw data type, at least in versions (> 9.2) where 32bit
        %encoding is used but Bytes/Pixel is still 2.
        BitsPerPixel_scaling = 8 * str2double(thisPartList('Bytes/pixel'));


        %find and get Z Scale, either as '@2:Z scale' or '@4:Z scale'
        if d_conv.isKeyStrPart(thisPartList, 'Z scale') && sum(d_conv.isKeyStrPart(thisPartList, 'Z scale')) == 1
            chScale = parseCIAOEntry(d_conv.lookupStrPart(thisPartList ,'Z scale'));
        elseif sum(d_conv.isKeyStrPart(thisPartList, 'Z scale')) > 1    
            %what to do if more than one Z scale exists?
        else %Z scale not found... what to do then... break?
        end

        %strange stuff. empirical maybe for SF versions >> 0x92...?
        if contains(dataType, "Force") && str2num(header.(fst_section){1}('Version')) > 0x9700000
            if d_conv.isKeyStrPart(thisPartList, 'FV scale') && sum(d_conv.isKeyStrPart(thisPartList, 'FV scale')) == 1
                chFVScale = parseCIAOEntry(d_conv.lookupStrPart(thisPartList ,'FV scale'));
                if chFVScale.HardValue ~= chScale.HardValue
                    chScale = chFVScale;
                end
                BitsPerPixel_scaling = 8*BytesPerPixel;
                
                %desperate stuff...  works for the moment. check with newer
                %software manual & check with files from other versions.
                if contains(chNameEntry.chName2, "Deflection") 
                    chScale.HardValue = chScale.HardScale * 2^BitsPerPixel_scaling;
                end
            end
        end
        %it seems like the number format in newer versions is signed int32.
        %nevertheless the scaling factor is still 2^16, i.e. from 2 bytes for most channels.
        %Bytes/pixel give the correct scaling.
        %From inspecting the data, in Deflection data the highest 2 bytes 
        %are just 0 and the values are scaled with 2 bytes.
        %In force files, Z scale and FV scale are different for the 
        %Height_sensor channel and obviously the FV scale is used.
        %In Deflection (error) channel, maybe they thought "we don't need a
        %rescaling if we have 4 bytes"...? So the HardScale seems the
        %correct value and not HardValue/(2^scaling_factor)

        
        %assemble soft scale parameter name 
        if ischar(chScale.SoftScaleName)
            sScaleParName = ['@' chScale.SoftScaleName];
        elseif isstring(chScale.SoftScaleName)
            sScaleParName = "@" + chScale.SoftScaleName;
        end
    
        %find and get soft scale (channel sensitivity)
        if isKey(header.ScannerList{1}, sScaleParName)
            chSens = parseCIAOEntry(header.ScannerList{1}(sScaleParName));
        elseif isKey(header.CiaoScanList{1}, sScaleParName)
            chSens = parseCIAOEntry(header.CiaoScanList{1}(sScaleParName));
        else %SoftScale parameter name was not found
            disp(sScaleParName)
        end
        
        params.ZScaleParts(ii,1).HardScale = chScale.HardValue / (2^(BitsPerPixel_scaling));
        params.ZScaleParts(ii,1).HardScaleUnit = chScale.HardValueUnit + "/LSB";
        params.ZScaleParts(ii,1).SoftScale = chSens.HardValue;
        params.ZScaleParts(ii,1).SoftScaleUnit = chSens.HardValueUnit;
        params.ZScaleParts(ii,1).SoftScaleName = chScale.SoftScaleName;

        params.ZScale(ii,1) = chSens.HardValue * chScale.HardValue / (2^(BitsPerPixel_scaling));
        params.ZUnit(ii,1) = extractBefore(chSens.HardValueUnit, "/");


    
    % chNameLine = regexp(channelName, '\s+(\S)\s+\[(.)*\]\s+\"(.)*\"', 'tokens');
    %                 obj.Img(ii).DataType = chNameLine{1}{2};
    %                 obj.Img(ii).DataName = chNameLine{1}{3};    
    % 
    %                 scansize = strtrim(strsplit(strtrim(channelHeader('Scan Size')),' '));
    %                 obj.Img(ii).XScale = str2double(scansize{1});
    %                 obj.Img(ii).YScale = str2double(scansize{2});
    %                 obj.Img(ii).XUnit = scansize{3};
    %                 obj.Img(ii).YUnit = scansize{3};
    % 
    %                 if isKey(channelHeader, '@2: Z_scale')
    %                     channelScaleInfo = regexp(channelHeader('@2: Z_scale'), '.*\[(.*)\] \(\d+\.?\d*.*\) (\d+\.?\d*) (.*)', 'tokens');
    %                 end
    %                 channelSensName = strtrim(channelScaleInfo{1}{1});
    %                 channelScale = str2double(channelScaleInfo{1}{2});
    %                 channelUnit = channelScaleInfo{1}{3};
    % 
    %                 if strcmp(channelSensName, 'Sens._Zsens')
    %                     channelSensEntry = obj.header.ScannerList{1}(['@__' channelSensName]);
    %                 else
    %                     disp(channelSensName)
    %                     channelSensEntry = obj.header.CiaoScanList{1}(['@__' channelSensName]);
    %                 end
    %                 channelSensEntryInfos = regexp(channelSensEntry, ' V (\d+.\d*) ([a-zA-Z]*)?/?(V)?', 'tokens');
    %                 channelSens = str2double(channelSensEntryInfos{1}{1});
    %                 if isempty(channelSensEntryInfos{1}{3})
    %                     channelSensEntryInfos{1}{3} = 'V';
    %                 end
    %                 if ~strcmp(channelSensEntryInfos{1}{3}, channelUnit)
    %                     disp(['Somehow the units don''t match: ' channelSensEntryInfos{1}{2} ' and ' channelUnit]);
    %                     if strcmp(channelUnit, 'mV')
    %                         channelSens = channelSens;% /1000 ??
    %                     end
    %                 end
    %                 obj.Img(ii).ZScale = channelSens / 2^(8*str2double(channelHeader('Bytes/pixel')));
    
        
    end
    fclose(file);
    
    out = struct('Header', header, 'Data', {data}, 'Params', params,...
        'Type', "Nanoscope " + dataType);
end


function out = parseCIAOEntry(str)
    %str: header parameter value as string/character array
    %out: struct with some of the following fields:
    %chName1 = Internal-designation for selection
    %chName2 = external-designation for selection
    %SoftScaleName = parameter tag of SoftScale
    %HardValue = numeric value
    %HardValueUnit = unit (for V params: Volts (V), sometimes mV or )


    %from Bruker handbook:
    %CIAO parameters:
    %Parameter Type: S : "Select parameter", C : "Scale parameter", V "Value parameter"
    %   S a parameter that describes some selection that has been made
    %   C a parameter that is simply a scaled version of another
    %   V a parameter that contains a double and a unit of measure, and some scaling definitions C
    %HardValue  The hard value is the analog representation of a measurement. It is simply the value 
    %           read on the parameter panel when you set the Units to Volts. The hard-value is the 
    %           value you would read with a voltmeter inside of the NanoScope electronics or inside 
    %           the head. This value is always in volts with the exception of the Drive Frequency 
    %           (which is in Hertz) and certain STM parameters (which are in Amps).
    %           A value parameter might be missing a soft-scale or a hard-scale, but must always have a hard-value.
    %HardScale  The hard scale is the conversion factor we use to convert LSBs into hard values. 
    %           We use the prefix “hard-” in hard-scale and hard-value because these numbers are 
    %           typically defined by the hardware itself and are not changeable by the user.
    %SoftValue  A soft-value is what the user sees on the screen when the Units are set to Metric.
    %SoftScale  The soft-scale is what we use to convert a hard-value into a soft-value. Soft-scales 
    %           are user defined, or are calibration numbers that the user divines. Soft-scales in the 
    %           parameters are typically not written out — rather, another tag appears between the brackets, 
    %           like [Sens. Zsens]. In that case, you look elsewhere in the parameter list for tag and use 
    %           that parameter's hard-value for the soft-scale.
    % S param format: [Internal-designation for selection] “external-designation for selection”
    % C param format: [soft-scale] hard-value
    % V param format: [soft-scale] (hard-scale) hard-value
    % (LSB: (least-significant bit) binary data representation)

    %detect parameter type:
    type = regexp(str, '\s+([SCV])\s+.*','tokens');


    %regular expressions to analyze parameter entries
    switch type{1}
        case "S" %selectParamExpr 
            expr = '\s+(?<ParamType>\S)\s+\[(?<chName1>.)*\]\s+\"(?<chName2>.)*\"';
        case "C" %scaleParamExpr 
            expr = ['\s+(?<ParamType>\S)\s+\[(?<SoftScaleName>.*)\]\s+'...
            '(?<HardValue>\d+\.?\d*)\s+(?<HardValueUnit>.*)'];
        case "V" %valueParamExpr 
            expr = ['\s+(?<ParamType>[SCV])' ...
                '(?<SoftScaleName>\s+\[.*\])?' ...      %optional softscale
                '(?<HardScale>\s+\(.*\))?' ...          %optional hardscale and hardscale units
                '\s+(?<HardValue>\d+\.?\d*)' ...        %hardvalue
                '\s*(?<HardValueUnit>.*)?'];            %optional hardvalue unit
            %expr = ['\s+(?<ParamType>\S)\s+(\[(?<SoftScaleName>.*)?\]\s+)?' ...    %optional softscale
            % '(\((?<HardScale>\d+\.?\d*)\s+(?<HardScaleUnit>.*)/LSB\)\s+)? ' ...    %optional hardscale and hardscale units
            % '(?<HardValue>\d+\.?\d*)(\s+(?<HardValueUnit>.*))?'];                  %optional hardvalue unit
            %['\s+(?<ParamType>\S)\s+\[(?<SoftScaleName>.*)\]\s+\((?<HardScale>\d+\.?\d*)\s+(?<HardScaleUnit>.*)/LSB\)\s+(?<HardValue>\d+\.?\d*)\s+(?<HardValueUnit>.*)'];
    end

    out = regexp(str,expr,'names');

    if isfield(out, 'SoftScaleName')
        out.SoftScaleName = extractBetween(out.SoftScaleName, "[", "]");
    end

    if isfield(out, 'HardValue') 
        if isempty(out.HardValue)
            out.HardValue = NaN;
        else
            out.HardValue = str2double(out.HardValue);
        end

    end

    if isfield(out, 'HardScale') && ~isempty(out.HardScale)
        tmp = regexp(out.HardScale, '\s*\((?<HardScale>\d+\.?\d*)\s+(?<HardScaleUnit>.*)/LSB\))?','names');
        if ~isempty(tmp)
            if isfield(tmp, 'HardScale') && ~isempty(tmp.HardScale)
                out.HardScale = str2double(tmp.HardScale);
            end
            if isfield(tmp, 'HardScaleUnit') && ~isempty(tmp.HardScaleUnit)
                out.HardScaleUnit = tmp.HardScaleUnit;
            end        
        end        
    end

    if isfield(out, 'HardValueUnit') && out.HardValueUnit == "mV"
        out.HardValue = out.HardValue/1000;
        out.HardValueUnit = "V";
    end

end