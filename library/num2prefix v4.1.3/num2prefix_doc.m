%% NUM2SIP and NUM2BIP Examples
% The function <https://www.mathworks.com/matlabcentral/fileexchange/33174
% |NUM2SIP|> converts a numeric scalar to a character vector with a number
% value and an <https://en.wikipedia.org/wiki/Metric_prefix SI prefix>
% (aka "metric prefix"), for example 1000 -> '1 k'.
% Optional arguments control the number precision, select the
% prefix symbol or prefix name, and if trailing zeros are kept or not.
%
% The development of |NUM2SIP| was motivated by the need for a well-written
% function to provide this conversion: many of the functions available
% on FEX do not conform to the SI standard, use buggy conversion
% algorithms, or are painfully inefficient. |NUM2SIP| has been tested
% against a large set of test cases, including many edge-cases and for
% all of the optional arguments. Feedback and bug reports are welcome!
%
% <html>
% <table>
%   <tr>
%     <th scope="row">Magnitude</th>
%     <td>10^-30</td>
%     <td>10^-27</td>
%     <td>10^-24</td>
%     <td>10^-21</td>
%     <td>10^-18</td>
%     <td>10^-15</td>
%     <td>10^-12</td>
%     <td>10^-9</td>
%     <td>10^-6</td>
%     <td>10^-3</td>
%     <td>10^0</td>
%     <td>10^+3</td>
%     <td>10^+6</td>
%     <td>10^+9</td>
%     <td>10^+12</td>
%     <td>10^+15</td>
%     <td>10^+18</td>
%     <td>10^+21</td>
%     <td>10^+24</td>
%     <td>10^+27</td>
%     <td>10^+30</td>
%   </tr>
%   <tr>
%     <th scope="row">Name</th>
%     <td>quecto</td>
%     <td>ronto</td>
%     <td>yocto</td>
%     <td>zepto</td>
%     <td>atto</td>
%     <td>femto</td>
%     <td>pico</td>
%     <td>nano</td>
%     <td>micro</td>
%     <td>milli</td>
%     <td></td>
%     <td>kilo</td>
%     <td>mega</td>
%     <td>giga</td>
%     <td>tera</td>
%     <td>peta</td>
%     <td>exa</td>
%     <td>zetta</td>
%     <td>yotta</td>
%     <td>ronna</td>
%     <td>quetta</td>
%   </tr>
%   <tr>
%     <th scope="row">Symbol</th>
%     <td>q</td>
%     <td>r</td>
%     <td>y</td>
%     <td>z</td>
%     <td>a</td>
%     <td>f</td>
%     <td>p</td>
%     <td>n</td>
%     <td>µ</td>
%     <td>m</td>
%     <td></td>
%     <td>k</td>
%     <td>M</td>
%     <td>G</td>
%     <td>T</td>
%     <td>P</td>
%     <td>E</td>
%     <td>Z</td>
%     <td>Y</td>
%     <td>R</td>
%     <td>Q</td>
%   </tr>
% </table>
% </html>
%
%% Basic Usage
% In many cases |NUM2SIP| can be called with just a numeric value:
num2sip(1000)
num2sip(1.2e+3)
num2sip(456e+7)
%% 2nd Input: Significant Figures
% By default |NUM2SIP| rounds to five significant figures. The optional
% second input argument specifies the number of significant figures.
% Note that |NUM2SIP| correctly rounds upwards to the next prefix:
num2sip(987654321,4)
num2sip(987654321,3)
num2sip(987654321,2)
num2sip(987654321,1)
%% 3rd Input: Symbol or Full Prefix
% By default |NUM2SIP| uses the prefix symbol. The optional third input
% argument selects between the prefix symbol and the full prefix name.
num2sip(1e6,[],false) % default
num2sip(1e6,[],true)
%% 3rd Input: Fixed Prefix
% By default |NUM2SIP| selects the most appropriate prefix. The optional
% third input argument lets the user specify the prefix. For convenience
% the "micro" symbol may be provided as |'u'| or (U+00B5) or (U+03BC).
num2sip(1e-2,[],'u')
num2sip(1e-4,[],'u')
num2sip(1e-6,[],'u')
num2sip(1e-8,[],'u')
%% 4th Input: Trailing Zeros
% By default |NUM2SIP| removes trailing zeros. The optional fourth input
% argument selects between removing and keeping any trailing zeros:
num2sip(1e3,3,[],false) % default
num2sip(1e3,3,[],true)
%% 4th and 2nd Inputs: Decimal Places
% By default the second input control the significant figures used in the
% output (following the design of MATLAB's inbuilt |NUM2STR| and |MAT2STR|).
% Set the fourth input to 'DP' and the second input instead controls the
% number of decimal places (including trailing zeros):
num2sip(123456789,4,[],'dp')
%% 2nd Output: Values Without a Prefix
% If the magnitude of the input value is outside the prefix range, then no
% prefix is used and the value is returned in exponential notation. The
% second output is a logical scalar which indicates if a prefix was used:
[str,isp] = num2sip(6e54)
[str,isp] = num2sip(3210)
%% 3rd and 4th Outputs: Coefficient and Prefix
% The third and fourth outputs return the numeric coefficient and the
% corresponding prefix. If no prefix is used (i.e. 2nd output |isp| is 
% |FALSE| ), then the prefix is an empty char.
[str,~,cof,pfx] = num2sip(123456789)
%% Values Without a Prefix
% If the magnitude of the input value is outside the prefix range, then no
% prefix is used and the value is returned in exponential notation:
num2sip(9e-87)
num2sip(6e+54)
%% Correct Rounding Up
% Unlike many functions available online, |NUM2SIP| correctly selects the
% next prefix when the value rounds up to the next power of one thousand:
num2sip(0.99e6,   3,[],true)
num2sip(0.999e6,  3,[],true)
num2sip(0.9999e6, 3,[],true)
%% Micro Symbol
% By default |NUM2SIP| uses the "micro" symbol from ISO 8859-1, i.e. Unicode
% (U+00B5) 'MICRO SIGN'. Simply edit the Mfile to select an alternative
% "micro" symbol, e.g. ASCII |'u'| or (U+03BC) 'GREEK SMALL LETTER MU'.
num2sip(5e-6) % default = (U+00B5) 'MICRO SIGN'
%% Space Character
% The standard for the International System of Quantities (ISQ)
% <https://en.wikipedia.org/wiki/International_System_of_Quantities
% ISO/IEC 80000> (previously ISO 31) specifies that
% <https://www.bipm.org/documents/20126/41483022/SI-Brochure-9-concise-EN.pdf
% _"a single space is always left between the number and the unit"_>.
% Note that this applies even when there is no SI prefix to the unit.
% |NUM2SIP| correctly includes the space character in all cases (by default
% using (U+00A0) 'NO-BREAK SPACE'):
sprintf('%sV',num2sip(1e-3))
sprintf('%sV',num2sip(1e+0))
sprintf('%sV',num2sip(1e+3))
sprintf('%sV',num2sip(1e99))
%% Bonus: |NUM2BIP| Binary Prefix Function
% The submission includes the bonus function |NUM2BIP|: this converts
% a numeric scalar to a prefixed string using the ISO 80000 defined
% <https://en.wikipedia.org/wiki/Binary_prefix binary prefixes> instead of
% SI metric prefixes. Binary prefixes are used for computer memory.
%
% <html>
% <table>
%   <tr>
%     <th scope="row">Magnitude</th>
%     <td>2^+10</td>
%     <td>2^+20</td>
%     <td>2^+30</td>
%     <td>2^+40</td>
%     <td>2^+50</td>
%     <td>2^+60</td>
%     <td>2^+70</td>
%     <td>2^+80</td>
%   </tr>
%   <tr>
%     <th scope="row">Name</th>
%     <td>kibi</td>
%     <td>mebi</td>
%     <td>gibi</td>
%     <td>tebi</td>
%     <td>pebi</td>
%     <td>exbi</td>
%     <td>zebi</td>
%     <td>yobi</td>
%   </tr>
%   <tr>
%     <th scope="row">Symbol</th>
%     <td>Ki</td>
%     <td>Mi</td>
%     <td>Gi</td>
%     <td>Ti</td>
%     <td>Pi</td>
%     <td>Ei</td>
%     <td>Zi</td>
%     <td>Yi</td>
%   </tr>
% </table>
% </html>
%
% The function |NUM2BIP| has exactly the same arguments as |NUM2SIP|:
num2bip(1280,4,true,true)
%% Reverse Conversion: String to Numeric
% The functions <https://www.mathworks.com/matlabcentral/fileexchange/53886
% |SIP2NUM| and |BIP2NUM|> convert from text into numeric:
bip2num('1.25 Ki')
sip2num('1.25 k')