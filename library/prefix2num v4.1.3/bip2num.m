function [num,spl,sgf,dbg,rgx] = bip2num(str,uni) %#ok<*ISMAT>
% Convert a binary-prefixed string into numeric values (computer memory)
%
% (c) 2011-2023 Stephen Cobeldick
%
% Convert a string containing numeric coefficients with binary prefixes into
% the equivalent numeric values, and also return the split string parts.
% For example the string "1 Ki" is converted to the value 1024. The function
% identifies both symbol prefixes and full names, e.g. either 'Ki' or 'kibi'.
%
%%% Syntax:
% num = bip2num(str)
% num = bip2num(str,uni)
% [num,spl,sgf,dbg] = bip2num(...)
%
%% Examples %%
%
% >> bip2num('10 Ki') % OR bip2num('10.0 kibi') OR bip2num('10240') OR bip2num('1.024e4')
% ans = 10240
%
% >> [num,spl] = bip2num("Memory: 200 mebibyte")
% num = 209715200
% spl = ["Memory: ","byte"]
%
% >> [num,spl,sgf] = bip2num("From -3.6 MiB to +1.24KiB data allowance.")
% num = [-3774873.6,1269.76]
% spl = ["From ","B to ","B data allowance."]
% sgf = [2,3]
%
% >> [num,spl] = bip2num("100 Pixel","Pixel") % Try it without the second option.
% num = 100
% spl = ["","Pixel"]
%
% >> bip2num(num2bip(pow2(9,40))) % 9 tebi == pow2(9,40) == 9*1024^4
% ans = 9895604649984
%
%% String Format %%
%
% * Any number of coefficients may occur in the string.
% * The coefficients may be any combination of digits, positive or negative,
%   integer or decimal, exponents may be included using E-notation (e/E).
% * An Inf or NaN value in the string will also be converted to a numeric.
% * The space-character between the coefficient and the prefix is optional.
% * The prefix is optional, may be either the binary prefix symbol or the
%   full prefix name (the code checks for prefix names first, then symbols).
%
% Optional input <uni> controls the prefix/units recognition: if the units
% starts with prefix characters, then this argument must be specified.
%
%% Binary Prefix Strings (ISO/IEC 80000-13) %%
%
% Order  |1024^1 |1024^2 |1024^3 |1024^4 |1024^5 |1024^6 |1024^7 |1024^8 |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|
% Name   | kibi  | mebi  | gibi  | tebi  | pebi  | exbi  | zebi  | yobi  |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|
% Symbol |  Ki   |  Mi   |  Gi   |  Ti   |  Pi   |  Ei   |  Zi   |  Yi   |
% -------|-------|-------|-------|-------|-------|-------|-------|-------|
%
%% Input and Output Arguments %%
%
%%% Inputs (**=default):
% str = CharVector or StringScalar, text to convert to numeric value/s.
% uni = CharVector or StringScalar, to specify the units after the prefix.
%     = Logical Scalar, true/false -> match only the prefix name/symbol.
%     = **[], automagically check for prefix name or symbol, with any units.
%
%%% Outputs:
% num = NumericVector, size 1xN. Has N values defined by the coefficients
%       and prefixes detected in <str>.
% spl = CellOfCharVector or StringArray, size 1xN+1. Contains the N+1 parts
%       of <str> split by the N detected coefficients and prefixes.
% sgf = NumericVector, size 1xN, significant figures of each coefficient.
% dbg = To aid debugging: size Nx2, the detected coefficients and prefixes.
%
% See also NUM2BIP BIP2NUM_TEST SIP2NUM RKM2NUM WORDS2NUM
%          SSCANF STR2DOUBLE DOUBLE TEXTSCAN

%% Input Wrangling %%
%
% Prefix and power:
vpw = [   +10;   +20;   +30;   +40;   +50;   +60;   +70;   +80];%;   +90;  +100]; % Nx1
pfn = {'kibi';'mebi';'gibi';'tebi';'pebi';'exbi';'zebi';'yobi'};%;'robi','qubi'}; % Nx1
pfs = {'Ki'  ;'Mi'  ;'Gi'  ;'Ti'  ;'Pi'  ;'Ei'  ;'Zi'  ;'Yi'  };%;'Ri'  ,'Qi'  }; % Nx1
%
pfc = [pfn,pfs]; % Nx2
idc = 1:2;
sfx = '';
%
fistxt = @(t) ischar(t)&&ndims(t)==2&&size(t,1)<2 || isa(t,'string')&&isscalar(t);
%
% Determine the prefix+unit combination:
if nargin<2 || (isnumeric(uni)&&isequal(uni,[]))
	% Name/symbol prefix, any units.
elseif isequal(uni,0)||isequal(uni,1)
	% true/false -> name/symbol.
	idc = 2-uni;
else
	assert(fistxt(uni),...
		'SC:bip2num:uni:NotScalarLogicalNorText',...
		'Second input <uni> must be a logical/string scalar or a character vector.')
	% Units are the given string.
	sfx = sprintf('(?=%s)',regexptranslate('escape',uni));
end
%
assert(fistxt(str),...
	'SC:bip2num:str:NotCharVectorNorStringScalar',...
	'First input <str> must be a string scalar or a character vector.')
%
%% String Parsing %%
%
% Sign characters for positive and negative:
% (U+002B) 'PLUS SIGN'
% (U+002D) 'HYPHEN-MINUS'
% (U+2212) 'MINUS SIGN'
% (U+FB29) 'HEBREW LETTER ALTERNATIVE PLUS SIGN'
% (U+FE63) 'SMALL HYPHEN-MINUS'
% (U+FF0B) 'FULLWIDTH PLUS SIGN'
% (U+FF0D) 'FULLWIDTH HYPHEN-MINUS'
neg = '\x2D\x2212\xFE63\xFF0D';
pos = '\x2B\xFB29\xFF0B';
sgn = sprintf('[%s%s]',neg,pos);
%
% Locate any coefficients (possibly with a prefix):
pfx = sprintf('|%s',pfc{:,idc});
rgx = '([nN][aA][nN]|[iI][nN][fF]|\.\d+|\d+\.?\d*)';
rgx = sprintf('(%s?%s([eE]%s?\\d+)?)\\s*(%s)?%s',sgn,rgx,sgn,pfx(2:end),sfx);
[dbg,spl] = regexp(str,rgx,'tokens','split','matchcase');
dbg = vertcat(dbg{:});
%
if isempty(dbg)
	num = [];
	sgf = [];
	return
end
%
assert(size(dbg,2)==2,'SC:bip2num:UnexpectedTokenSize',...
	'Octave''s buggy REGEXP strikes again! Try using MATLAB.')
%
dbg(:,1) = regexprep(dbg(:,1),sprintf('[%s]',neg),'-');
dbg(:,1) = regexprep(dbg(:,1),sprintf('[%s]',pos),'+');
%
% Calculate values from the coefficients:
num = sscanf(sprintf(' %s',dbg{:,1}),'%f',[1,Inf]);
for k = 1:numel(num)
	[idp,~] = find(strcmp(dbg{k,2},pfc),1);
	if numel(idp)
		num(k) = pow2(num(k),vpw(idp));
	end
end
%
% Count significant figures:
if nargout>2
	xgr = {sgn,'(INF|NAN|E.+)','(?<=^\d+)0+$','^0+(?=\d)','^0*\.0*(?=[1-9])','^0*\.(?=0+$)','\.'};
	sgf = reshape(cellfun('length',regexprep(dbg(:,1),xgr,'','ignorecase')),1,[]);
end
%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%bip2num