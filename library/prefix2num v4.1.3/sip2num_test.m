function sip2num_test
% Test function for SIP2NUM.
%
% (c) 2011-2023 Stephen Cobeldick
%
% See Also TESTFUN_PREFIX SIP2NUM NUM2SIP BIP2NUM NUM2BIP RKM2NUM NUM2RKM

fnh = @sip2num;
chk = testfun_prefix(fnh);
spl = {'',''};
%
%% Help Examples %%
%
chk(      '1 k', fnh, 1000)
chk(     '10 k', fnh, 10000)
chk('10.0 kilo', fnh, 10000)
chk(    '10000', fnh, 10000)
chk(      '1e4', fnh, 10000)
chk('Power: 200 megawatt', fnh, 200000000)
chk('from -3.6 MV to +1.24kV potential difference.', fnh, [-3600000,1240], {'from ','V to ','V potential difference.'}, [2,3])
chk('100 meter','meter', fnh, 100, {'','meter'}) % Try it without the second option.
chk(num2sip(9e12), fnh, 9e12) % 9 tera
%
%% No Number %%
%
chk('',     fnh, [], {''},     []);
chk(' ',    fnh, [], {' '},    []);
chk('X',    fnh, [], {'X'},    []);
chk('XY',   fnh, [], {'XY'},   []);
chk('XYZ',  fnh, [], {'XYZ'},  []);
chk('    ', fnh, [], {'    '}, []);
%
%% Basic Edge Cases %%
%
chk('0'   , fnh, 0, spl,1)
chk('0 '  , fnh, 0, spl,1)
chk('0  ' , fnh, 0, spl,1)
chk('0   ', fnh, 0, spl,1)
chk('NaN',  fnh, NaN, spl,0)
chk('NaN ', fnh, NaN, spl,0)
chk('Inf',  fnh, +Inf, spl,0)
chk('Inf ', fnh, +Inf, spl,0)
chk('InfG', fnh, +Inf, spl,0)
chk('+Inf', fnh, +Inf, spl,0)
chk('-Inf', fnh, -Inf, spl,0)
chk('+Inf k', fnh, +Inf, spl,0)
chk('-Inf k', fnh, -Inf, spl,0)
chk('+Inf M', fnh, +Inf, spl,0)
chk('-Inf M', fnh, -Inf, spl,0)
chk('NaN  G', fnh, NaN, spl,0)
chk('+NaN G', fnh, NaN, spl,0)
chk('-NaN G', fnh, NaN, spl,0)
% Case insensitivity:
chk('2e3', fnh, 2000, spl,1)
chk('2E3', fnh, 2000, spl,1)
chk('NAN', fnh, NaN, spl,0)
chk('nan', fnh, NaN, spl,0)
chk('nAn', fnh, NaN, spl,0)
chk('+INF', fnh, +Inf, spl,0)
chk('+inf', fnh, +Inf, spl,0)
chk('-INF', fnh, -Inf, spl,0)
chk('-iNf', fnh, -Inf, spl,0)
%
%% Fractional Digits %%
%
chk('1230000.00', fnh, 1.23e6, spl,9)
chk('1.230e+3 k', fnh, 1.23e6, spl,4)
chk('0.123e+4 k', fnh, 1.23e6, spl,3)
chk('0123e+01 k', fnh, 1.23e6, spl,3)
chk('0123e-02 M', fnh, 1.23e6, spl,3)
chk('00001.23 M', fnh, 1.23e6, spl,3)
chk('00.00123 G', fnh, 1.23e6, spl,3)
chk('1.23e-03 G', fnh, 1.23e6, spl,3)
%
%% All Prefixes %%
%
% No space character
chk('1q', fnh, 1e-30, spl,1)
chk('1r', fnh, 1e-27, spl,1)
chk('1y', fnh, 1e-24, spl,1)
chk('1z', fnh, 1e-21, spl,1)
chk('1a', fnh, 1e-18, spl,1)
chk('1f', fnh, 1e-15, spl,1)
chk('1p', fnh, 1e-12, spl,1)
chk('1n', fnh, 1e-9 , spl,1)
chk('1µ', fnh, 1e-6 , spl,1)
chk('1m', fnh, 1e-3 , spl,1)
chk('1' , fnh, 1e+0 , spl,1)
chk('1k', fnh, 1e+3 , spl,1)
chk('1M', fnh, 1e+6 , spl,1)
chk('1G', fnh, 1e+9 , spl,1)
chk('1T', fnh, 1e+12, spl,1)
chk('1P', fnh, 1e+15, spl,1)
chk('1E', fnh, 1e+18, spl,1)
chk('1Z', fnh, 1e+21, spl,1)
chk('1Y', fnh, 1e+24, spl,1)
chk('1R', fnh, 1e+27, spl,1)
chk('1Q', fnh, 1e+30, spl,1)
% With space character
chk('1 q', fnh, 1e-30, spl,1)
chk('1 r', fnh, 1e-27, spl,1)
chk('1 y', fnh, 1e-24, spl,1)
chk('1 z', fnh, 1e-21, spl,1)
chk('1 a', fnh, 1e-18, spl,1)
chk('1 f', fnh, 1e-15, spl,1)
chk('1 p', fnh, 1e-12, spl,1)
chk('1 n', fnh, 1e-9 , spl,1)
chk('1 µ', fnh, 1e-6 , spl,1)
chk('1 m', fnh, 1e-3 , spl,1)
chk('1  ', fnh, 1e+0 , spl,1)
chk('1 k', fnh, 1e+3 , spl,1)
chk('1 M', fnh, 1e+6 , spl,1)
chk('1 G', fnh, 1e+9 , spl,1)
chk('1 T', fnh, 1e+12, spl,1)
chk('1 P', fnh, 1e+15, spl,1)
chk('1 E', fnh, 1e+18, spl,1)
chk('1 Z', fnh, 1e+21, spl,1)
chk('1 Y', fnh, 1e+24, spl,1)
chk('1 R', fnh, 1e+27, spl,1)
chk('1 Q', fnh, 1e+30, spl,1)
% Non-unitary
chk('21q', fnh, 21e-30, spl,2)
chk('19r', fnh, 19e-27, spl,2)
chk('98y', fnh, 98e-24, spl,2)
chk('87z', fnh, 87e-21, spl,2)
chk('76a', fnh, 76e-18, spl,2)
chk('65f', fnh, 65e-15, spl,2)
chk('54p', fnh, 54e-12, spl,2)
chk('43n', fnh, 43e-9 , spl,2)
chk('32µ', fnh, 32e-6 , spl,2)
chk('21m', fnh, 21e-3 , spl,2)
chk('19 ', fnh, 19e0  , spl,2)
chk('21k', fnh, 21e+3 , spl,2)
chk('32M', fnh, 32e+6 , spl,2)
chk('43G', fnh, 43e+9 , spl,2)
chk('54T', fnh, 54e+12, spl,2)
chk('65P', fnh, 65e+15, spl,2)
chk('76E', fnh, 76e+18, spl,2)
chk('87Z', fnh, 87e+21, spl,2)
chk('98Y', fnh, 98e+24, spl,2)
chk('19R', fnh, 19e+27, spl,2)
chk('21Q', fnh, 21e+30, spl,2)
%
% No space character
chk('1quecto' , fnh, 1e-30, spl,1)
chk('1ronto'  , fnh, 1e-27, spl,1)
chk('1yocto'  , fnh, 1e-24, spl,1)
chk('1zepto'  , fnh, 1e-21, spl,1)
chk('1atto'   , fnh, 1e-18, spl,1)
chk('1femto'  , fnh, 1e-15, spl,1)
chk('1pico'   , fnh, 1e-12, spl,1)
chk('1nano'   , fnh, 1e-9 , spl,1)
chk('1micro'  , fnh, 1e-6 , spl,1)
chk('1milli'  , fnh, 1e-3 , spl,1)
chk('1'       , fnh, 1e0  , spl,1)
chk('1kilo'   , fnh, 1e+3 , spl,1)
chk('1mega'   , fnh, 1e+6 , spl,1)
chk('1giga'   , fnh, 1e+9 , spl,1)
chk('1tera'   , fnh, 1e+12, spl,1)
chk('1peta'   , fnh, 1e+15, spl,1)
chk('1exa'    , fnh, 1e+18, spl,1)
chk('1zetta'  , fnh, 1e+21, spl,1)
chk('1yotta'  , fnh, 1e+24, spl,1)
chk('1ronna'  , fnh, 1e+27, spl,1)
chk('1quetta' , fnh, 1e+30, spl,1)
% With space characters
chk('1 quecto' , fnh, 1e-30, spl,1)
chk('1  ronto' , fnh, 1e-27, spl,1)
chk('1  yocto' , fnh, 1e-24, spl,1)
chk('1  zepto' , fnh, 1e-21, spl,1)
chk('1   atto' , fnh, 1e-18, spl,1)
chk('1  femto' , fnh, 1e-15, spl,1)
chk('1   pico' , fnh, 1e-12, spl,1)
chk('1   nano' , fnh, 1e-9 , spl,1)
chk('1  micro' , fnh, 1e-6 , spl,1)
chk('1  milli' , fnh, 1e-3 , spl,1)
chk('1       ' , fnh, 1e0  , spl,1)
chk('1   kilo' , fnh, 1e+3 , spl,1)
chk('1   mega' , fnh, 1e+6 , spl,1)
chk('1   giga' , fnh, 1e+9 , spl,1)
chk('1   tera' , fnh, 1e+12, spl,1)
chk('1   peta' , fnh, 1e+15, spl,1)
chk('1    exa' , fnh, 1e+18, spl,1)
chk('1  zetta' , fnh, 1e+21, spl,1)
chk('1  yotta' , fnh, 1e+24, spl,1)
chk('1  ronna' , fnh, 1e+27, spl,1)
chk('1 quetta' , fnh, 1e+30, spl,1)
% Non-unitary
chk('7.8quecto' , fnh, 7.8e-30, spl,2)
chk('8.9ronto'  , fnh, 8.9e-27, spl,2)
chk('9.1yocto'  , fnh, 9.1e-24, spl,2)
chk('8.9zepto'  , fnh, 8.9e-21, spl,2)
chk('7.8atto'   , fnh, 7.8e-18, spl,2)
chk('6.7femto'  , fnh, 6.7e-15, spl,2)
chk('5.6pico'   , fnh, 5.6e-12, spl,2)
chk('4.5nano'   , fnh, 4.5e-9 , spl,2)
chk('3.4micro'  , fnh, 3.4e-6 , spl,2)
chk('2.3milli'  , fnh, 2.3e-3 , spl,2)
chk('1.2'       , fnh, 1.2e0  , spl,2)
chk('2.3kilo'   , fnh, 2.3e+3 , spl,2)
chk('3.4mega'   , fnh, 3.4e+6 , spl,2)
chk('4.5giga'   , fnh, 4.5e+9 , spl,2)
chk('5.6tera'   , fnh, 5.6e+12, spl,2)
chk('6.7peta'   , fnh, 6.7e+15, spl,2)
chk('7.8exa'    , fnh, 7.8e+18, spl,2)
chk('8.9zetta'  , fnh, 8.9e+21, spl,2)
chk('9.1yotta'  , fnh, 9.1e+24, spl,2)
chk('8.9ronna'  , fnh, 8.9e+27, spl,2)
chk('7.8quetta' , fnh, 7.8e+30, spl,2)
%
%% Unicode Characters %%
%
% whitespace
chk(sprintf('1\x0009k'), fnh, 1000, spl,1) % (U+0009) 'CHARACTER TABULATION'
chk(sprintf('1\x0020k'), fnh, 1000, spl,1) % (U+0020) 'SPACE'
chk(sprintf('1\x00A0k'), fnh, 1000, spl,1) % (U+00A0) 'NO-BREAK SPACE'
chk(sprintf('1\x2002k'), fnh, 1000, spl,1) % (U+2002) 'EN SPACE'
chk(sprintf('1\x2003k'), fnh, 1000, spl,1) % (U+2003) 'EM SPACE'
chk(sprintf('1\x2007k'), fnh, 1000, spl,1) % (U+2007) 'FIGURE SPACE'
chk(sprintf('1\x202Fk'), fnh, 1000, spl,1) % (U+202F) 'NARROW NO-BREAK SPACE'
chk(sprintf('1\x202Fk'), fnh, 1000, spl,1) % (U+205F) 'MEDIUM MATHEMATICAL SPACE'
% negative sign
neg = sprintf('\x2212'); % (U+2212) 'MINUS SIGN'
chk([neg,'1'], fnh, -1, spl,1)
chk([neg,'2 k'], fnh, -2e+3, spl,1)
chk([neg,'3 µ'], fnh, -3e-6, spl,1)
chk([neg,'456e',neg,'78'], fnh, -456e-78, spl,3)
% micro symbol
chk(sprintf('123 \x75'),  fnh, 123e-6, spl,3) % (U+0075) 'LATIN SMALL LETTER U'
chk(sprintf('456 \xB5'),  fnh, 456e-6, spl,3) % (U+00B5) 'MICRO SIGN'
chk(sprintf('789 \x3BC'), fnh, 789e-6, spl,3) % (U+03BC) 'GREEK SMALL LETTER MU'
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
%% https://physics.nist.gov/cuu/pdf/sp811.pdf %%
%
chk('33 M',    fnh, 3.3e7  , spl, 2)
chk('9.52 m',  fnh, 0.00952, spl, 3)
chk('2.703 k', fnh, 2703   , spl, 4)
chk('58 n',    fnh, 5.8e-8 , spl, 2)
%
%% https://physics.nist.gov/cuu/Units/prefixes.html %%
%
chk('169 ',     fnh, 169, spl, 3)
chk('169000 m', fnh, 169, spl, 3)
chk('0.169 k',  fnh, 169, spl, 3)
%
%% http://problemsphysics.com/formulas/prefixes.html %%
%
chk('2 y',   fnh, 2e-24)
chk('5 z',   fnh, 5e-21)
chk('4 a',   fnh, 4e-18)
chk('5 f',   fnh, 5e-15)
chk('7 p',   fnh, 7e-12)
chk('5 n',   fnh, 5e-9 )
chk('6 µ',   fnh, 6e-6 )
chk('5 m',   fnh, 5e-3 )
chk('1.6 k', fnh, 1.6e3)
chk('19 M',  fnh, 19e6 )
chk('3 G',   fnh, 3e9  )
chk('2 T',   fnh, 2e12 )
chk('11 P',  fnh, 11e15) % source is inconsistent
chk('4 E',   fnh, 4e18 )
chk('12 Z',  fnh, 12e21)
chk('21 Y',  fnh, 21e24)
%
%% https://si-prefix.readthedocs.io/en/latest/ %%
%
chk('500.0 m', fnh, 0.5, spl, 4)
chk('13.31 m', fnh, 0.01331, spl, 4)
chk('1.33 k',  fnh, 1330, spl, 3)
chk('1 k',     fnh, 1000, spl, 1)
%
rdp = @(n,p) round(n*10.^p)*10.^-p;
rsf = @(n,s) rdp(n,s-1-floor(log10(abs(n))));
%
chk('1.00 r'  , fnh, rsf(1e-27,       3), spl,3) % source: '1.00e-27 '
chk('1.76 y'  , fnh, rsf(1.764e-24,   3), spl,3)
chk('74.09 y' , fnh, rsf(7.4088e-23,  4), spl,4)
chk('3.11 z'  , fnh, rsf(3.1117e-21,  3), spl,3)
chk('130.69 z', fnh, rsf(1.30691e-19, 5), spl,5)
chk('5.49 a'  , fnh, rsf(5.48903e-18, 3), spl,3)
chk('230.54 a', fnh, rsf(2.30539e-16, 5), spl,5)
chk('9.68 f'  , fnh, rsf(9.68265e-15, 3), spl,3)
chk('406.67 f', fnh, rsf(4.06671e-13, 5), spl,5)
chk('17.08 p' , fnh, rsf(1.70802e-11, 4), spl,4)
chk('717.37 p', fnh, rsf(7.17368e-10, 5), spl,5)
chk('30.13 n' , fnh, rsf(3.01295e-08, 4), spl,4)
chk('1.27 µ'  , fnh, rsf(1.26544e-06, 3), spl,3)
chk('53.15 µ' , fnh, rsf(5.31484e-05, 4), spl,4)
chk('2.23 m'  , fnh, rsf(0.00223223,  3), spl,3)
chk('93.75 m' , fnh, rsf(0.0937537,   4), spl,4)
chk('3.94 '   , fnh, rsf(3.93766,     3), spl,3)
chk('165.38 ' , fnh, rsf(165.382,     5), spl,5)
chk('6.95 k'  , fnh, rsf(6946.03,     3), spl,3)
chk('291.73 k', fnh, rsf(291733,      5), spl,5)
chk('12.25 M' , fnh, rsf(1.22528e+07, 4), spl,4)
chk('514.62 M', fnh, rsf(5.14617e+08, 5), spl,5)
chk('21.61 G' , fnh, rsf(2.16139e+10, 4), spl,4)
chk('907.79 G', fnh, rsf(9.07785e+11, 5), spl,5) % source: '907.78 G'
chk('38.13 T' , fnh, rsf(3.8127e+13,  4), spl,4)
chk('1.60 P'  , fnh, rsf(1.60133e+15, 3), spl,3)
chk('67.26 P' , fnh, rsf(6.7256e+16,  4), spl,4)
chk('2.82 E'  , fnh, rsf(2.82475e+18, 3), spl,3)
chk('118.64 E', fnh, rsf(1.1864e+20,  5), spl,5)
chk('4.98 Z'  , fnh, rsf(4.98286e+21, 3), spl,3)
chk('209.28 Z', fnh, rsf(2.0928e+23,  5), spl,5)
chk('8.79 Y'  , fnh, rsf(8.78977e+24, 3), spl,3)
chk('369.17 Y', fnh, rsf(3.6917e+26,  5), spl,5)
chk('15.51 R' , fnh, rsf(1.55051e+28, 4), spl,4) % source: '15.51e+27 '
chk('651.22 R', fnh, rsf(6.51216e+29, 5), spl,5) % source: '651.22e+27 '
%
%% https://en.wikipedia.org/wiki/Metric_prefix %%
%
chk('25 µ', fnh, 25e-6)
chk('5.01 m', fnh, 5.01e-3)
chk('3 M', fnh, 3e6)
%
%% Display Results %%
%
chk()
%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%sip2num_test