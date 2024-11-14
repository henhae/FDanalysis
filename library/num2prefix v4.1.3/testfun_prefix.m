function chk = testfun_prefix(fnh)
% Test function for checking number<->prefixed-text conversion functions.
%
% (c) 2011-2023 Stephen Cobeldick
%
% See also NUM2BIP_TEST NUM2SIP_TEST NUM2RKM_TEST
%          BIP2NUM_TEST SIP2NUM_TEST RKM2NUM_TEST

chk = @nestfun;
cnt = 0;
itr = 0;
if feature('hotlinks')
	fmt = '<a href="matlab:opentoline(''%1$s'',%2$d)">%1$s|%2$d:</a>';
else
	fmt = '%s|%d:';
end
%
	function nestfun(varargin)
		% (in1, in2, in3, ..., fnh, out1, out2, out3, ...)
		%
		dbs = dbstack();
		%
		if ~nargin % post-processing
			fprintf(fmt, dbs(2).file, dbs(2).line);
			fprintf(' %d of %d testcases failed.\n',cnt,itr)
			return
		end
		%
		idx = find(cellfun(@(f)isequal(f,fnh),varargin));
		assert(nnz(idx)==1,'Missing/duplicated function handle.')
		%
		xpC = varargin(idx+1:end);
		opC =  cell(size(xpC));
		boo = false(size(xpC));
		%
		[opC{:}] = fnh(varargin{1:idx-1});
		%
		for k = 1:numel(xpC)
			opA = opC{k};
			xpA = xpC{k};
			if isequal(xpA,@i)
				% ignore this output
			elseif ~isequal(class(opA),class(xpA))
				boo(k) = true;
				opT = class(opA);
				xpT = class(xpA);
			elseif ischar(opA)||isa(opA,'string')||iscellstr(opA) %#ok<ISCLSTR>
				opA = regexprep(opA,{'\s','([eE][-+])0(\d{2})'},{' ','$1$2'});
				if ~isequal(size(opA),size(xpA))||~all(reshape(strcmp(opA,xpA),1,[]))
					boo(k) = true;
					opT = tfPretty(opA);
					xpT = tfPretty(xpA);
				end
			elseif isfloat(opA)
				if ~tfIsEqualFP(opA,xpA)
					boo(k) = true;
					opT = tfPretty(opA);
					xpT = tfPretty(xpA);
				end
			elseif ~isequal(opA,xpA)
				boo(k) = true;
				opT = tfPretty(opA);
				xpT = tfPretty(xpA);
			end
			if boo(k)
				dmn = min(numel(opT),numel(xpT));
				dmx = max(numel(opT),numel(xpT));
				erT = repmat('^',1,dmx);
				erT(opT(1:dmn)==xpT(1:dmn)) = ' ';
				%
				fprintf(fmt, dbs(2).file, dbs(2).line);
				fprintf(' (output #%d)\n',k);
				fprintf('actual: %s\n', opT);
				fprintf('expect: %s\n', xpT);
				fprintf('diff:   ')
				fprintf(2,'%s\n',erT); % red!
			end
		end
		cnt = cnt+any(boo);
		itr = itr+1;
	end
%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%testfun_prefix
function ie = tfIsEqualFP(a,b)
% Compare equality of floating-point arrays with 2*EPS tolerance.
assert(isfloat(a)&&isfloat(b),'Inputs must be floating point numeric.')
af = isfinite(a(:));
bf = isfinite(b(:));
ai = isinf(a(:));
bi = isinf(b(:));
ie = isequal(size(a),size(b)) && ~any(xor(af,bf)|xor(ai,bi)) && ...
	all(a(ai)==b(bi)) && all(abs(a(af)-b(bf))<=(eps(a(af))+eps(b(bf))));
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%tfIsEqualFP
function out = tfPretty(inp)
if isempty(inp)|| ndims(inp)>2 %#ok<ISMAT>
	out = sprintf('x%u',size(inp));
	out = sprintf('%s %s',out(2:end),class(inp));
elseif isnumeric(inp) || islogical(inp)
	out = regexprep(mat2str(inp,23),'\s+',',');
elseif ischar(inp)
	out = mat2str(inp);
elseif isa(inp,'string')
	if isscalar(inp)
		out = sprintf('"%s"',inp);
	else
		fmt = repmat(',"%s"',1,size(inp,2));
		out = sprintf([';',fmt(2:end)],inp.');
		out = sprintf('[%s]',out(2:end));
	end
elseif iscell(inp)
	tmp = cellfun(@tfPretty,inp.','uni',0);
	fmt = repmat(',%s',1,size(inp,2));
	out = sprintf([';',fmt(2:end)],tmp{:});
	out = sprintf('{%s}',out(2:end));
else
	error('Class "%s" is not supported.',class(inp))
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%tfPretty