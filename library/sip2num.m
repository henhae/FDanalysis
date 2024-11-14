function [num,spl,sgf,dbg,rgx] = sip2num(str,uni) %#ok<*ISMAT>
% Convert a metric-prefixed string into numeric values (SI/engineering)
%
% (c) 2011-2023 Stephen Cobeldick
%
% Convert a string containing numeric coefficients with SI prefixes into
% the equivalent numeric values, and also return the split string parts.
% For example the string "1 k" is converted to the value 1000. The function
% identifies both symbol prefixes and full names, e.g. either 'k' or 'kilo'.
%
%%% Syntax:
% num = sip2num(str)
% num = sip2num(str,uni)
% [num,spl,sgf,dbg] = sip2num(...)
%
%% Examples %%
%
% >> sip2num('10 k') % OR sip2num('10.0 kilo') OR sip2num('10000') OR sip2num('1e4')
% ans = 10000
%
% >> [num,spl] = sip2num("Power: 200 megawatt")
% num = 200000000
% spl = ["Power: ","watt"]
%
% >> [num,spl,sgf] = sip2num("from -3.6 MV to +1.24kV potential difference.")
% num = [-3600000,1240]
% spl = ["from ","V to ","V potential difference."]
% sgf = [2,3]
%
% >> [num,spl] = sip2num("100 meter","meter") % Try it without the second option.
% num = 100
% spl = ["","meter"]
%
% >> sip2num(num2sip(9e12)) % 9 tera == 9e12 == 9*1000^4
% ans = 9000000000000
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
%% SI Prefix Strings (Bureau International des Poids et Mesures) %%
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
% See also NUM2SIP SIP2NUM_TEST BIP2NUM RKM2NUM WORDS2NUM
%          SSCANF STR2DOUBLE DOUBLE TEXTSCAN

%% Input Wrangling %%
%
% Accepted "micro" symbol characters:
mu1 = char(181); % (U+00B5) 'MICRO SIGN'
mu2 = char(956); % (U+03BC) 'GREEK SMALL LETTER MU'
mux = 'micro';
%
% Prefix and power:
vpw = [     -30;    -27;    -24;    -21;   -18;    -15;   -12;    -9; -6; -6; -6;     -3;    +3;    +6;    +9;   +12;   +15;  +18;    +21;    +24;    +27;     +30]; % Nx1
pfn = {'quecto';'ronto';'yocto';'zepto';'atto';'femto';'pico';'nano';mux;mux;mux;'milli';'kilo';'mega';'giga';'tera';'peta';'exa';'zetta';'yotta';'ronna';'quetta'}; % Nx1
pfs = {'q'     ;'r'    ;'y'    ;'z'    ;'a'   ;'f'    ;'p'   ;'n'   ;'u';mu1;mu2;'m'    ;'k'   ;'M'   ;'G'   ;'T'   ;'P'   ;'E'  ;'Z'    ;'Y'    ;'R'    ;'Q'     }; % Nx1
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
		'SC:sip2num:uni:NotScalarLogicalNorText',...
		'Second input <uni> must be a logical/string scalar or a character vector.')
	% Units are the given string.
	sfx = sprintf('(?=%s)',regexptranslate('escape',uni));
end
%
assert(fistxt(str),...
	'SC:sip2num:str:NotCharVectorNorStringScalar',...
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
assert(size(dbg,2)==2,'SC:sip2num:UnexpectedTokenSize',...
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
		num(k) = num(k).*power(10,vpw(idp));
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%sip2num