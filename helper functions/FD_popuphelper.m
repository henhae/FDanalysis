function output = FD_popuphelper(popupname, varargin)
% This function starts a UIfigure defined by a class and returns its
% output.
% popupname needs to hold name of class defining a UIfigure
% handle. varargin may hold input for the UIfigure.
% The class to be invoked needs:
%   - a property named 'output' 
%   - a delete function , which outputs the class object
% If using a AppDesigner app, export the final mlapp-file to m-file and just add
% an output value to the delete function
    if ~ischar(popupname)
        error('String expected as input value.');
    end
    if ~exist(popupname, 'file')
        error([popupname ' does not exist.']);
    end
    if ~exist(popupname, 'class')
        error([popupname ' is not a valid class.']);
    end
    
    %TODO: enable more input values (e.g. Name-Value pairs): concat string with varargin{1}
    %varargin{2} etc...
    
    if nargin == 1
        popupobj = eval(popupname);
        ps = properties(popupobj);            
            figh = popupobj.(ps{find(contains(ps, 'UIFigure'),1)});
    elseif nargin == 2
        if ishandle(varargin{1})
            popupobj = eval(popupname);
            
            ps = properties(popupobj);            
            figh = popupobj.(ps{find(contains(ps, 'UIFigure'),1)});
            
            figh.Position(1:2) = varargin{1}.Position(1:2) + varargin{1}.Position(3:4)/2 - figh.Position(3:4)/2;
        else
            popupobj = eval([popupname '(varargin{1})' ]);
        end
    elseif nargin == 3
        if ishandle(varargin{1})
            popupobj = eval([popupname '(varargin{2})' ]);
            ps = properties(popupobj);            
            figh = popupobj.(ps{find(contains(ps, 'UIFigure'),1)});
            figh.Position(1:2) = varargin{1}.Position(1:2) + varargin{1}.Position(3:4)/2 - figh.Position(3:4)/2;
        else
            error('Input error: Input #1 needs to be Figure handle.')
        end
    else
        error('More than two input arguments for the popup is not supported.');
    end
    uiwait(figh);
    
    output = popupobj.output;
end