%% SIP2NUM and BIP2NUM Examples
% The function <https://www.mathworks.com/matlabcentral/fileexchange/53886
% |SIP2NUM|> converts the input string (containing a number with optional
% SI prefix) into a numeric, for example "1 k" -> 1000. The function
% can detect and convert multiple numbers in the string, both with and
% without SI prefixes. |SIP2NUM| returns the numeric values, the
% string parts split by the detected numbers and prefixes, and the
% detected number of significant digits in for each detected number.
%
% The development of |SIP2NUM| was motivated by the need for a well-written
% function to provide this conversion: many of the functions available
% on FEX do not conform to the SI standard, use buggy conversion
% algorithms, or are painfully inefficient. |SIP2NUM| has been tested
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
% In many cases |SIP2NUM| can be called with just a string value:
sip2num('1.2 k')
sip2num("3.45 Giga")
sip2num("6.7 µV and 89 mOhm")
%% 2nd Output: Split Strings
% |SIP2NUM| also returns the string parts split by the detected numbers:
[num,spl] = sip2num("We applied 23 MV for 5 ms.")
%% 3rd Output: Significant Digits
% |SIP2NUM| returns the significant digits of the detected numbers:
[num,~,sgf] = sip2num("Write 987.6 kV or 0.99 MV ?")
%% 4th Output: Debug Aid
% The fourth output contains the raw detected numbers and prefixes. The
% 1st column contains the numbers/coefficients, the 2nd the prefixes:
[num,~,~,dbg] = sip2num("1.23 megawatt vs. 1.23 MW vs. 1.23e6 watts")
%% 2nd Input: Specify Units
% Some units may be mistaken for prefixes, in which case the second input
% argument should be specified so that the units are identified correctly:
[num,spl,~,dbg] = sip2num("100 meter") % 'm' is falsely identified as a prefix
[num,spl,~,dbg] = sip2num("100 meter","meter") % specify the units to get the correct value
%% 2nd Input: Symbol or Full Name
% By default |SIP2NUM| will try to match either the prefix symbol or the
% full prefix name. The optional second input argument selects whether to
% match only prefix symbols or only prefix names:
[num,spl] = sip2num("100 milli",false) % symbols only
[num,spl] = sip2num("100 milli",true)  % names only
[num,spl] = sip2num("100 m",true) % cannot match name -> matches number only
%% Micro Symbol
% For convenience |SIP2NUM| identifies three different "micro" characters:
sip2num("1 u") % ASCII        (U+0075) 'LATIN SMALL LETTER U'
sip2num("1 µ") % ISO 8859-1   (U+00B5) 'MICRO SIGN'
sip2num(sprintf("1 \xB5"))  % (U+00B5) 'MICRO SIGN'
sip2num(sprintf("1 \x3BC")) % (U+03BC) 'GREEK SMALL LETTER MU'
%% Space Character
% For convenience |SIP2NUM| identifies many different space characters, .e.g:
sip2num(sprintf("1\x0020n")) % (U+0020) 'SPACE'
sip2num(sprintf("1\x00A0n")) % (U+00A0) 'NO-BREAK SPACE'
sip2num(sprintf("1\x2007n")) % (U+2007) 'FIGURE SPACE'
sip2num(sprintf("1\x202Fn")) % (U+202F) 'NARROW NO-BREAK SPACE'
sip2num(sprintf("1\x205Fn")) % (U+205F) 'MEDIUM MATHEMATICAL SPACE'
%% Bonus: |BIP2NUM| Binary Prefix Function
% The submission includes the bonus function |BIP2NUM|: this converts a
% string with ISO 80000 <https://en.wikipedia.org/wiki/Binary_prefix binary prefixes>
% instead of SI prefixes. Binary prefixes are used for computer memory.
%
% <html>
% <table>
%   <tr>
%     <th>Magnitude</th>
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
%     <th>Name</th>
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
%     <th>Symbol</th>
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
% The function |BIP2NUM| has exactly the same arguments as |SIP2NUM|:
bip2num("1.25 kibibytes",true)
%% Reverse Conversion: Numeric to String
% The functions <https://www.mathworks.com/matlabcentral/fileexchange/33174
% |NUM2SIP| and |NUM2BIP|> convert from numeric into text:
num2bip(1280)
num2sip(1250)