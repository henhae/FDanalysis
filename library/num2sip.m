function [str,isp,cof,pfx] = num2sip(num,sgf,typ,trz) %#ok<*ISMAT>
% Convert a scalar numeric into metric-prefixed text (SI/engineering)
%
% (c) 2011-2023 Stephen Cobeldick
%
% Convert a scalar numeric value into a 1xN character vector giving the
% value as a coefficient with an SI prefix, for example 1000 -> '1 k'.
% Values outside the prefix range use E-notation without any prefix.
%
%%% Syntax:
% str = num2sip(num)
% str = num2sip(num,sgf)
% str = num2sip(num,sgf,typ)
% str = num2sip(num,sgf,typ,trz)
% [str,isp,cof,pfx] = num2sip(...)
%
%% Examples %%
%
% >> num2sip(10000) % OR num2sip(1e4)
% ans = '10 k'
% >> num2sip(10000,4,true)
% ans = '10 kilo'
% >> num2sip(10000,4,false,true)
% ans = '10.00 k'
%
% >> num2sip(999,3)
% ans = '999 '
% >> num2sip(999,2)
% ans = '1 k'
%
% >> num2sip(0.5e6)
% ans = '500 k'
% >> num2sip(0.5e6,[],'M')
% ans = '0.5 M'
%
% >> sprintf('Power: %swatt', num2sip(200e6,[],true))
% ans = 'Power: 200 megawatt'
%
% >> sprintf('Clock frequency is %sHz.', num2sip(1234567890,3))
% ans = 'Clock frequency is 1.23 GHz.'
%
% >> num2sip(sip2num('9 T')) % 9 tera == 9e12 == 9*1000^4
% ans = '9 T'
%
%% SI Prefix Strings %%
%
% Order  |1000^+1|1000^+2|1000^+3|1000^+4|1000^+5|1000^+6|1000^+7|1000^+8|1000^+9|1000^+10|
% -------|-------|-------|-------|-------|-------|-------|-------|-------|-------|--------|
% Name   | kilo  | mega  | giga  | tera  | peta  | exa   | zetta | yotta | ronna | quetta |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|-------|--------|
% Symbol |   k   |   M   |   G   |   T   |   P   |   E   |   Z   |   Y   |   R   |   Q    |
%
% Order  |1000^-1|1000^-2|1000^-3|1000^-4|1000^-5|1000^-6|1000^-7|1000^-8|1000^-9|1000^-10|
% -------|-------|-------|-------|-------|-------|-------|-------|-------|-------|--------|
% Name   | milli | micro | nano  | pico  | femto | atto  | zepto | yocto | ronto | quecto |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|-------|--------|
% Symbol |   m   |   µ   |   n   |   p   |   f   |   a   |   z   |   y   |   r   |   q    |
%
%% Input and Output Arguments %%
%
%%% Inputs (**=default):
% num = NumericScalar, the value to be converted to text <str>.
% sgf = NumericScalar, the significant figures in the coefficient, 5**.
% typ = CharacterVector or StringScalar, to use that prefix, e.g. 'k', 'kilo'.
%     = LogicalScalar, true/false** -> select SI prefix as name/symbol.
% trz = LogicalScalar, true/false** -> select if trailing zeros are retained.
%     = 'dp', then the 2nd input controls the number of decimal places.
%
%%% Outputs:
% str = CharVector, input <num> as text: [coefficient,space,prefix].
% isp = LogicalScalar, indicates if <str> includes a prefix.
% cof = DoubleScalar, the coefficient value used in <str>.
% pfx = CharVector, the prefix used in <str>. If none then empty.
%
% See also SIP2NUM NUM2SIP_TEST NUM2BIP NUM2RKM NUM2WORDS NUM2ORD
% SPRINTF NUM2STR MAT2STR INT2STR COMPOSE CHAR STRING TTS

%% Input Wrangling %%
%
% Uncomment your preferred output "micro" symbol:
%mu0 = 'u'; % ASCII (U+0075) 'LATIN SMALL LETTER U'
mu0 = char(181);  % (U+00B5) 'MICRO SIGN'
%mu0 = char(956); % (U+03BC) 'GREEK SMALL LETTER MU'
%
% Uncomment your preferred space character:
%wsp = ' '; % ASCII (U+0020) 'SPACE'
wsp = char(160);  % (U+00A0) 'NO-BREAK SPACE'
%
% Prefix and power:
vpw = [     -30;    -27;    -24;    -21;   -18;    -15;   -12;    -9;     -6;     -3; 0;    +3;    +6;    +9;   +12;   +15;  +18;    +21;    +24;    +27;     +30]; % Nx1
pfn = {'quecto';'ronto';'yocto';'zepto';'atto';'femto';'pico';'nano';'micro';'milli';'';'kilo';'mega';'giga';'tera';'peta';'exa';'zetta';'yotta';'ronna';'quetta'}; % Nx1
pfs = {'q'     ;'r'    ;'y'    ;'z'    ;'a'   ;'f'    ;'p'   ;'n'   ;mu0    ;'m'    ;'';'k'   ;'M'   ;'G'   ;'T'   ;'P'   ;'E'  ;'Z'    ;'Y'    ;'R'    ;'Q'     }; % Nx1
%
pfc = [pfn,pfs]; % Nx2
dpw = 3; % power steps, i.e mode(diff(vpw))
%
assert(isnumeric(num)&&isscalar(num)&&isreal(num),...
	'SC:num2sip:num:NotRealScalarNumeric',...
	'First input <num> must be a real numeric scalar.')
num = double(num);
%
iss = true;
if nargin<4 || isnumeric(trz)&&isequal(trz,[]) % default
	trz = false;
elseif (ischar(trz)&&ndims(trz)<3||isa(trz,'string'))&&strcmpi(trz,'dp')
	trz = true;
	iss = false;
else
	assert(isequal(trz,0)||isequal(trz,1),... % logical scalar...
		'SC:num2sip:trz:NotLogicalScalar',...
		'Fourth input <trz> must be a logical scalar.')
	trz = logical(trz);
end
%
if nargin<2 || isnumeric(sgf)&&isequal(sgf,[]) % default
	sgf = 5;
else
	assert(isnumeric(sgf)&&isscalar(sgf)&&isreal(sgf),...
		'SC:num2sip:sgf:NotRealScalarNumeric',...
		'Second input <sgf> must be a real numeric scalar.')
	assert(fix(sgf)==sgf&&sgf>=iss,...
		'SC:num2sip:sgf:NotWholeNumber',...
		'Second input <sgf> must be a positive whole number.')
	sgf = double(sgf);
end
%
idc = 2;
if nargin<3 || isnumeric(typ)&&isequal(typ,[]) % default
	aj2 = n2pAdjust(log10(abs(num)),dpw); % 2x1
elseif isequal(typ,0)||isequal(typ,1) % logical scalar
	aj2 = n2pAdjust(log10(abs(num)),dpw); % 2x1
	idc = 2-typ;
else
	assert(ischar(typ)&&ndims(typ)<3&&size(typ,1)<2 || isa(typ,'string')&&isscalar(typ),...
		'SC:num2sip:typ:NotTextNorNumeric',...
		'Third input <typ> must be a logical/string scalar, or a character vector.')
	if strcmp(typ,'')
		idr = find(strcmp('',pfs));
	else
		typ = regexprep(typ,'^[\x75\xB5\x3BC]$',mu0);
		[idr,idc] = find(strcmp(typ,pfc));
	end
	assert(numel(idr)==1,...
		'SC:num2sip:typ:NotValidPrefix',...
		'Third input <typ> can be one of the following:%s\b.',sprintf(' "%s",',pfc{:}))
	aj2 = vpw([idr;idr]); % 2x1
end
%
%% Generate String %%
%
% Define two potential coefficients:
pc2 = num./power(10,aj2); % 2x1
% Determine the number of decimal places:
p10 = power(10,sgf-iss.*(1+floor(log10(abs(pc2))))); % 2x1
% Round coefficients to decimal places:
rc2 = round(pc2.*p10)./p10; % 2x1
% Identify which prefix is required:
idx = 1+any(abs(rc2)==[power(10,dpw);1]); % 1x1
pwr = 1+floor(log10(abs(rc2(idx)))); % 1x1
% Select one coefficient:
if isfinite(pwr)
	nc1 = rc2(idx); % 1x1
else
	nc1 = pc2(idx); % 1x1
	pwr = 0;
end
% Obtain the required prefix:
idp = aj2(idx)==vpw; % Nx1
isp = any(idp); % 1x1
if isp
	pfx = pfc{idp,idc};
else
	pfx = '';
end
%
if iss % significant figures
	if isp % within prefix range
		if pwr<0 % fixed prefix;
			str = sprintf('%.*f%s%s',sgf-pwr,nc1,wsp,pfx);
			if ~trz
				str = regexprep(str,'\.?0+\s+',wsp);
			end
		else % automagic prefix:
			fmt = n2pFormat(trz&&sgf>pwr);
			str = sprintf(fmt,max(sgf,pwr),nc1,wsp,pfx);
		end
	else % outside prefix range:
		fmt = n2pFormat(trz&&sgf>1);
		str = sprintf(fmt,sgf,num,wsp,pfx);
	end
else % decimal places
	if isp % within prefix range:
		str = sprintf('%.*f%s%s',sgf,nc1,wsp,pfx);
	else % outside prefix range:
		str = sprintf('%.*e%s%s',sgf,num,wsp,pfx);
	end
end
%
if nargout>2
	cof = sscanf(str,'%f');
end
isp = ~isempty(pfx);
%str = strrep(str,'-',char(8722)); % (U+2212) 'MINUS SIGN'
%str = string(str); % String class output
%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%num2sip
function adj = n2pAdjust(pwr,dPw)
adj = dPw*([0;1]+floor(floor(pwr)/dPw));
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%n2pAdjust
function fmt = n2pFormat(isz)
if isz
	fmt = '%#.*g%s%s';
else
	fmt = '%.*g%s%s';
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%n2pFormat