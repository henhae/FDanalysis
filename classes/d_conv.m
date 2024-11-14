%dictionary convenience function
%possibly redundant in future Matlab releases when dictionaries get more
%handling functions

classdef d_conv 

methods (Static)

    %For dictionaries with only strings as keys (TODO: Include function to
    %convert other entries (numeric scalars etc) to strings and throw error
    %for non-convertibles.

    %get all entries whose key contains the given string
    function out = lookupStrPart(d, str)
        keysCell = d_conv.keysStrPart(d,str);
        out = lookup(d, keysCell);
    end

    %get all keys that contain the given string
    function out = keysStrPart(d, str)
        keysCell = keys(d);
        keyIDs = contains(keysCell, str);
        out = keysCell(keyIDs);
    end

    %check if at least one key exists that contains the given string
    function out = isKeyStrPart(d, str)
        keysCell = keys(d);
        out = any(contains(keysCell, str));
    end

end

end