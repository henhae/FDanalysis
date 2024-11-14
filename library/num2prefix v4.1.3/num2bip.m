function [str,isp,cof,pfx] = num2bip(num,sgf,typ,trz) %#ok<*ISMAT>
% Convert a scalar numeric into binary-prefixed text (computer memory)
%
% (c) 2011-2023 Stephen Cobeldick
%
% Convert a scalar numeric value into a 1xN character vector giving the
% value as a coefficient with a binary prefix, for example 1024 -> '1 Ki'.
% Values outside the prefix range use E-notation without any prefix.
%
%%% Syntax:
% str = num2bip(num)
% str = num2bip(num,sgf)
% str = num2bip(num,sgf,typ)
% str = num2bip(num,sgf,typ,trz)
% [str,isp,cof,pfx] = num2bip(...)
%
%% Examples %%
%
% >> num2bip(10240) % OR num2bip(1.024e4) OR num2bip(pow2(10,10)) OR num2bip(10*2^10)
% ans = '10 Ki'
% >> num2bip(10240,4,true)
% ans = '10 kibi'
% >> num2bip(10240,4,false,true)
% ans = '10.00 Ki'
%
% >> num2bip(1023,3)
% ans = '1020 '
% >> num2bip(1023,2)
% ans = '1 Ki'
%
% >> num2bip(pow2(19))
% ans = '512 Ki'
% >> num2bip(pow2(19),[],'Mi')
% ans = '0.5 Mi'
%
% >> sprintf('Memory: %sbyte', num2bip(pow2(200,20),[],true))
% ans = 'Memory: 200 mebibyte'
%
% >> sprintf('Data saved in %sB.', num2bip(1234567890,3))
% ans = 'Data saved in 1.15 GiB.'
%
% >> num2bip(bip2num('9 Ti')) % 9 tebi == pow2(9,40) == 9*1024^4
% ans = '9 Ti'
%
%% Binary Prefix Strings (ISO/IEC 80000-13) %%
%
% Order  |1024^1 |1024^2 |1024^3 |1024^4 |1024^5 |1024^6 |1024^7 |1024^8 |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|
% Name   | kibi  | mebi  | gibi  | tebi  | pebi  | exbi  | zebi  | yobi  |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|
% Symbol*|  Ki   |  Mi   |  Gi   |  Ti   |  Pi   |  Ei   |  Zi   |  Yi   |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|
%
%% Input and Output Arguments %%
%
%%% Inputs (**=default):
% num = NumericScalar, the value to be converted to text <str>.
% sgf = NumericScalar, the significant figures in the coefficient, 5**.
% typ = CharacterVector or StringScalar, to use that prefix, e.g. 'Ki', 'kibi'.
%     = LogicalScalar, true/false** -> select binary prefix as name/symbol.
% trz = LogicalScalar, true/false** -> select if trailing zeros are retained.
%     = 'dp', then the 2nd input controls the number of decimal places.
%
%%% Outputs:
% str = CharVector, input <num> as text: [coefficient,space,prefix].
% isp = LogicalScalar, indicates if <str> includes a prefix.
% cof = DoubleScalar, the coefficient value used in <str>.
% pfx = CharVector, the prefix used in <str>. If none then empty.
%
% See also BIP2NUM NUM2BIP_TEST NUM2SIP NUM2RKM NUM2WORDS NUM2ORD
% SPRINTF NUM2STR MAT2STR INT2STR COMPOSE CHAR STRING TTS

%% Input Wrangling %%
%
% Uncomment your preferred space character:
%wsp = ' '; % ASCII (U+0020) 'SPACE'
wsp = char(160);  % (U+00A0) 'NO-BREAK SPACE'
%
% Prefix and power:
vpw = [ 0;   +10;   +20;   +30;   +40;   +50;   +60;   +70;   +80];%;   +90;  +100]; % Nx1
pfn = {'';'kibi';'mebi';'gibi';'tebi';'pebi';'exbi';'zebi';'yobi'};%;'robi';'qubi'}; % Nx1
pfs = {'';'Ki'  ;'Mi'  ;'Gi'  ;'Ti'  ;'Pi'  ;'Ei'  ;'Zi'  ;'Yi'  };%;'Ri'  ;'Qi'  }; % Nx1
%
pfc = [pfn,pfs]; % Nx2
dpw = 10; % power steps, i.e mode(diff(vpw))
%
assert(isnumeric(num)&&isscalar(num)&&isreal(num),...
	'SC:num2bip:num:NotRealScalarNumeric',...
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
		'SC:num2bip:trz:NotLogicalScalar',...
		'Fourth input <trz> must be a logical scalar.')
	trz = logical(trz);
end
%
if nargin<2 || isnumeric(sgf)&&isequal(sgf,[]) % default
	sgf = 5;
else
	assert(isnumeric(sgf)&&isscalar(sgf)&&isreal(sgf),...
		'SC:num2bip:sgf:NotRealScalarNumeric',...
		'Second input <sgf> must be a real numeric scalar.')
	assert(fix(sgf)==sgf&&sgf>=iss,...
		'SC:num2bip:sgf:NotWholeNumber',...
		'Second input <sgf> must be a positive whole number.')
	sgf = double(sgf);
end
%
idc = 2;
if nargin<3 || isnumeric(typ)&&isequal(typ,[]) % default
	aj2 = n2pAdjust(log2(abs(num)),dpw); % 2x1
elseif isequal(typ,0)||isequal(typ,1) % logical scalar
	aj2 = n2pAdjust(log2(abs(num)),dpw); % 2x1
	idc = 2-typ;
else
	assert(ischar(typ)&&ndims(typ)<3&&size(typ,1)<2 || isa(typ,'string')&&isscalar(typ),...
		'SC:num2bip:typ:NotTextNorNumeric',...
		'Third input <typ> must be a logical/string scalar, or a character vector.')
	if strcmp(typ,'')
		idr = find(strcmp('',pfs));
	else
		[idr,idc] = find(strcmp(typ,pfc));
	end
	assert(numel(idr)==1,...
		'SC:num2bip:typ:NotValidPrefix',...
		'Third input <typ> can be one of the following:%s\b.',sprintf(' "%s",',pfc{:}))
	aj2 = vpw([idr;idr]); % 2x1
end
%
%% Generate String %%
%
% Define two potential coefficients:
pc2 = pow2(num,-aj2); % 2x1
% Determine the number of decimal places:
p10 = power(10,sgf-iss.*(1+floor(log10(abs(pc2))))); % 2x1
% Round coefficients to decimal places:
rc2 = round(pc2.*p10)./p10; % 2x1
% Identify which prefix is required:
idx = 1+any(abs(rc2)==[pow2(dpw);1]); % 1x1
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%num2bip
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