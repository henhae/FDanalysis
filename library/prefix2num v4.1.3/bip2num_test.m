function bip2num_test
% Test function for BIP2NUM.
%
% (c) 2011-2023 Stephen Cobeldick
%
% See Also TESTFUN_PREFIX BIP2NUM NUM2BIP RKM2NUM NUM2RKM SIP2NUM NUM2SIP

fnh = @bip2num;
chk = testfun_prefix(fnh);
spl = {'',''};
%
%% Help Examples %%
%
chk(     '1 Ki', fnh, 1024)
chk(    '10 Ki', fnh, 10240)
chk('10.0 kibi', fnh, 10240)
chk(    '10240', fnh, 10240)
chk(  '1.024e4', fnh, 10240)
chk('Memory: 200 mebibyte', fnh, 209715200, {'Memory: ','byte'})
chk('From -3.6 MiB to +1.24KiB data allowance.', fnh, [-3774873.6,1269.76], {'From ','B to ','B data allowance.'}, [2,3])
chk('100 Pixel', 'Pixel', fnh, 100, {'','Pixel'}) % Try it without the second option.
chk(num2bip(pow2(9,40)), fnh, pow2(9,40)) % 9 tebi
%
%% No Numbers %%
%
chk('',     fnh, [], {''},     [])
chk(' ',    fnh, [], {' '},    [])
chk('.',    fnh, [], {'.'},    [])
chk('X',    fnh, [], {'X'},    [])
chk('XY',   fnh, [], {'XY'},   [])
chk('XYZ',  fnh, [], {'XYZ'},  [])
chk('    ', fnh, [], {'    '}, [])
chk('A B ', fnh, [], {'A B '}, [])
chk('. . ', fnh, [], {'. . '}, [])
%
%% Basic Edge Cases %%
%
chk('0'  ,  fnh, 0, spl,1)
chk('0 '  , fnh, 0, spl,1)
chk('0  ' , fnh, 0, spl,1)
chk('0   ', fnh, 0, spl,1)
chk('NaN',  fnh, NaN, spl,0)
chk('NaN ', fnh, NaN, spl,0)
chk('Inf',  fnh, +Inf, spl,0)
chk('Inf ', fnh, +Inf, spl,0)
chk('+Inf', fnh, +Inf, spl,0)
chk('-Inf', fnh, -Inf, spl,0)
chk('NaN Ki', fnh, NaN, spl,0)
chk('+Inf Ki', fnh, +Inf, spl,0)
chk('-Inf Ki', fnh, -Inf, spl,0)
% Case insensitivity:
chk('2e3', fnh, 2000, spl,1)
chk('2E3', fnh, 2000, spl,1)
chk('NAN', fnh, NaN, spl,0)
chk('nan', fnh, NaN, spl,0)
chk('nAn', fnh, NaN, spl,0)
chk('+INF', fnh, +Inf, spl,0)
chk('+inf', fnh, +Inf, spl,0)
chk('-INF', fnh, -Inf, spl,0)
chk('-inf', fnh, -Inf, spl,0)
%
%% Fractional Digits %%
%
chk('1259520.000', fnh, pow2(1230,10), spl,10)
chk('1.230e+3 Ki', fnh, pow2(1230,10), spl,4)
chk('0.123e+4 Ki', fnh, pow2(1230,10), spl,3)
chk('0123e+01 Ki', fnh, pow2(1230,10), spl,3)
%
%% All Prefixes %%
%
% No space character
chk('1',   fnh, pow2(00), spl,1)
chk('1Ki', fnh, pow2(10), spl,1)
chk('1Mi', fnh, pow2(20), spl,1)
chk('1Gi', fnh, pow2(30), spl,1)
chk('1Ti', fnh, pow2(40), spl,1)
chk('1Pi', fnh, pow2(50), spl,1)
chk('1Ei', fnh, pow2(60), spl,1)
chk('1Zi', fnh, pow2(70), spl,1)
chk('1Yi', fnh, pow2(80), spl,1)
% With space character
chk('1   ', fnh, pow2(00), spl,1)
chk('1 Ki', fnh, pow2(10), spl,1)
chk('1 Mi', fnh, pow2(20), spl,1)
chk('1 Gi', fnh, pow2(30), spl,1)
chk('1 Ti', fnh, pow2(40), spl,1)
chk('1 Pi', fnh, pow2(50), spl,1)
chk('1 Ei', fnh, pow2(60), spl,1)
chk('1 Zi', fnh, pow2(70), spl,1)
chk('1 Yi', fnh, pow2(80), spl,1)
% Non-unitary
chk('9.1'  , fnh, pow2(9.1,00), spl,2)
chk('1.2Ki', fnh, pow2(1.2,10), spl,2)
chk('2.3Mi', fnh, pow2(2.3,20), spl,2)
chk('3.4Gi', fnh, pow2(3.4,30), spl,2)
chk('4.5Ti', fnh, pow2(4.5,40), spl,2)
chk('5.6Pi', fnh, pow2(5.6,50), spl,2)
chk('6.7Ei', fnh, pow2(6.7,60), spl,2)
chk('7.8Zi', fnh, pow2(7.8,70), spl,2)
chk('8.9Yi', fnh, pow2(8.9,80), spl,2)
%
% No space character
chk('1',   fnh, pow2(00), spl,1)
chk('1kibi', fnh, pow2(10), spl,1)
chk('1mebi', fnh, pow2(20), spl,1)
chk('1gibi', fnh, pow2(30), spl,1)
chk('1tebi', fnh, pow2(40), spl,1)
chk('1pebi', fnh, pow2(50), spl,1)
chk('1exbi', fnh, pow2(60), spl,1)
chk('1zebi', fnh, pow2(70), spl,1)
chk('1yobi', fnh, pow2(80), spl,1)
% With space characters
chk('1      ', fnh, pow2(00), spl,1)
chk('1  kibi', fnh, pow2(10), spl,1)
chk('1  mebi', fnh, pow2(20), spl,1)
chk('1  gibi', fnh, pow2(30), spl,1)
chk('1  tebi', fnh, pow2(40), spl,1)
chk('1  pebi', fnh, pow2(50), spl,1)
chk('1  exbi', fnh, pow2(60), spl,1)
chk('1  zebi', fnh, pow2(70), spl,1)
chk('1  yobi', fnh, pow2(80), spl,1)
% Non-unitary
chk('9.1'    , fnh, pow2(9.1,00), spl,2)
chk('1.2kibi', fnh, pow2(1.2,10), spl,2)
chk('2.3mebi', fnh, pow2(2.3,20), spl,2)
chk('3.4gibi', fnh, pow2(3.4,30), spl,2)
chk('4.5tebi', fnh, pow2(4.5,40), spl,2)
chk('5.6pebi', fnh, pow2(5.6,50), spl,2)
chk('6.7exbi', fnh, pow2(6.7,60), spl,2)
chk('7.8zebi', fnh, pow2(7.8,70), spl,2)
chk('8.9yobi', fnh, pow2(8.9,80), spl,2)
%
%% Unicode Characters %%
%
% whitespace
chk(sprintf('1\x0009Ki'), fnh, 1024, spl,1) % (U+0009) 'CHARACTER TABULATION'
chk(sprintf('1\x0020Ki'), fnh, 1024, spl,1) % (U+0020) 'SPACE'
chk(sprintf('1\x00A0Ki'), fnh, 1024, spl,1) % (U+00A0) 'NO-BREAK SPACE'
chk(sprintf('1\x2002Ki'), fnh, 1024, spl,1) % (U+2002) 'EN SPACE'
chk(sprintf('1\x2003Ki'), fnh, 1024, spl,1) % (U+2003) 'EM SPACE'
chk(sprintf('1\x2007Ki'), fnh, 1024, spl,1) % (U+2007) 'FIGURE SPACE'
chk(sprintf('1\x202FKi'), fnh, 1024, spl,1) % (U+202F) 'NARROW NO-BREAK SPACE'
chk(sprintf('1\x202FKi'), fnh, 1024, spl,1) % (U+205F) 'MEDIUM MATHEMATICAL SPACE'
% negative sign
neg = sprintf('\x2212'); % (U+2212) 'MINUS SIGN'
chk([neg,'1'], fnh, -1, spl,1)
chk([neg,'2 Ki'], fnh, pow2(-2,10), spl,1)
chk([neg,'3 Mi'], fnh, pow2(-3,20), spl,1)
chk([neg,'456e',neg,'78'], fnh, -456e-78, spl,3)
%
%% Significant Figures %%
%
chk('Inf',  fnh, Inf, spl, 0)
chk('NaN',  fnh, NaN, spl, 0)
chk('0',      fnh, 0, spl, 1)
chk('00',     fnh, 0, spl, 1)
chk('000',    fnh, 0, spl, 1)
chk('0000',   fnh, 0, spl, 1)
chk('00000',  fnh, 0, spl, 1)
chk('00000.', fnh, 0, spl, 1)
chk('0000.0', fnh, 0, spl, 1)
chk('000.00', fnh, 0, spl, 2)
chk('00.000', fnh, 0, spl, 3)
chk('0.0000', fnh, 0, spl, 4)
chk('.00000', fnh, 0, spl, 5)
chk('100000', fnh, 1e5, spl, 1)
chk('10000.', fnh, 1e4, spl, 5)
chk('1000.0', fnh, 1e3, spl, 5)
chk('100.00', fnh, 1e2, spl, 5)
chk('10.000', fnh, 1e1, spl, 5)
chk('1.0000', fnh, 1e0, spl, 5)
chk('000010.', fnh, 1e+1, spl, 2)
chk('00001.0', fnh, 1e-0, spl, 2)
chk('0000.10', fnh, 1e-1, spl, 2)
chk('000.010', fnh, 1e-2, spl, 2)
chk('00.0010', fnh, 1e-3, spl, 2)
chk('0.00010', fnh, 1e-4, spl, 2)
%
%% https://physics.nist.gov/cuu/Units/binary.html %%
%
chk('1 Ki', fnh, 1024)
chk('1 Mi', fnh, 1048576)
chk('1 Gi', fnh, 1073741824)
%
%% https://rechneronline.de/transfer/binary-prefixes.php %%
%
chk('1 gibi', fnh, 1.073741824e9) % source: 1.0737e9
%
%% https://en.wikipedia.org/wiki/Binary_prefix %%
%
chk('512 Mi',         fnh, 536870912)
chk('466 Gi',         fnh, 500363689984) % source: 500e9
chk('17.8 Mi',        fnh, 18664652.8) % source: 18613795
chk('44.63671875 Ki', fnh, 45708) % source: '44.6 Ki'
chk('15.625 Ki',      fnh, 16e3) % source: 15.6
chk('122.0703125 Ki', fnh, 125000) % source: '122 Ki'
chk('119 Mi',         fnh, 124780544) % source: 125000000
chk('6.8359375 Ki',   fnh, 56000/8) % source: '6.8 Ki'
chk('3.0 Gi',         fnh, 3221225472) % source: 3200000000
%
%% http://wolfprojects.altervista.org/articles/binary-and-decimal-prefixes/ %%
%
chk('28.4482421875 Ki', fnh, 29131) % source: '28.4 Ki'
chk('20 Mi', fnh, 20971520)
chk('1 kibi', fnh,                      1024)
chk('1 mebi', fnh,                   1048576)
chk('1 gibi', fnh,                1073741824)
chk('1 tebi', fnh,             1099511627776)
chk('1 pebi', fnh,          1125899906842624)
chk('1 exbi', fnh,       1152921504606846976)
chk('1 zebi', fnh,    1180591620717411303424)
chk('1 yobi', fnh, 1208925819614629174706176)
chk('465.6612873077392578125 Gi', fnh, 500e9) % source: '465.66 Gi'
chk('4 Gi', fnh, 4294967296)
chk('20 Mi', fnh, 20971520)
%
%% Display Results %%
%
chk()
%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%bip2num_test