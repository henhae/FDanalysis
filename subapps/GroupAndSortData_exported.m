classdef GroupAndSortData_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure        matlab.ui.Figure
        CancelButton    matlab.ui.control.Button
        SaveExitButton  matlab.ui.control.Button
        ButtonBottom    matlab.ui.control.Button
        ButtonDown      matlab.ui.control.Button
        ButtonUp        matlab.ui.control.Button
        ButtonTop       matlab.ui.control.Button
        UngroupButton   matlab.ui.control.Button
        GroupButton     matlab.ui.control.Button
        Tree            matlab.ui.container.Tree
    end

    
    properties (Access = private)
        handle          % Handle to calling app or (ui)figure
        outp            % name of variable in calling app or (ui)figure to put output in
    end
    
    methods (Access = private)
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, data, handle, outpVarName)
            %todo: groups übernehmen!
            
            app.handle = handle;
            app.outp = outpVarName;
            if ~any(strcmp(data.Properties.VariableNames, 'Group'))
                data.Group = ones(height(data),1);
            end
            
            for ii=1:height(data)
                if data.Group(ii) == 1
                    uitreenode(app.Tree, "Text", data.Name{ii}, "NodeData", ii);
                else
                    thisGrpName = data.GroupName{ii};
                    thisGrpIdx = arrayfun(@(x) strcmp(x.Text, thisGrpName), app.Tree.Children);
                    if any(thisGrpIdx)
                        groupNode = app.Tree.Children(thisGrpIdx);
                    else
                        groupNode = uitreenode(app.Tree, "Text", thisGrpName);
                    end                    
                    uitreenode(groupNode, "Text", data.Name{ii}, "NodeData", ii);
                end
            end
        end

        % Selection changed function: Tree
        function TreeSelectionChanged(app, event)
            selectedNodes = app.Tree.SelectedNodes;

            parentTypes = arrayfun(@(x) x.Parent.Type, selectedNodes, "UniformOutput", false);

            allSameParent = false;
            if numel(selectedNodes) > 1
                if all(strcmp(parentTypes, parentTypes{1}))
                    if strcmp(parentTypes(1),'uitree')
                        allSameParent = true;
                    else
                        if all(arrayfun(@(x) strcmp(x.Parent.Text, selectedNodes(1).Parent.Text), selectedNodes))
                            allSameParent = true;
                        end
                    end
                end

            else
                allSameParent = true;
            end

            if numel(selectedNodes) == 1 && numel(selectedNodes(1).Children) > 0
                app.Tree.Editable = "on";
            else
                app.Tree.Editable = "off";
            end
            
            
            if numel(selectedNodes) > 1 && allSameParent ...
                    && strcmp(parentTypes{1},'uitree') ...
                    && sum(arrayfun(@(x) ~isempty(x.Children), selectedNodes)) <= 1
                app.GroupButton.Enable = "on";
            else
                app.GroupButton.Enable = "off";
            end
            

            if allSameParent && strcmp(parentTypes{1}, 'uitreenode')
                app.UngroupButton.Enable = "on";
            else
                app.UngroupButton.Enable = "off";
            end

            if allSameParent
                app.ButtonBottom.Enable = "on";
                app.ButtonTop.Enable = "on";

                selNodeTexts = arrayfun(@(x) x.Text, selectedNodes, "UniformOutput",false);
                selNodeIdxs = find(arrayfun(@(x) any(strcmp(x.Text,selNodeTexts)),...
                    selectedNodes(1).Parent.Children));
                if diff(selNodeIdxs([1 end]))+1 == numel(selNodeIdxs)
                    app.ButtonDown.Enable = "on";
                    app.ButtonUp.Enable = "on";
                else
                    app.ButtonDown.Enable = "off";
                    app.ButtonUp.Enable = "off";
                end
                if selNodeIdxs(1) == 1
                    app.ButtonUp.Enable = "off";
                    app.ButtonTop.Enable = "off";
                end
                if selNodeIdxs(end) == numel(selectedNodes(1).Parent.Children)
                    app.ButtonDown.Enable = "off";
                    app.ButtonBottom.Enable = "off";
                end

            else
                app.ButtonBottom.Enable = "off";
                app.ButtonDown.Enable = "off";
                app.ButtonTop.Enable = "off";
                app.ButtonUp.Enable = "off";
            end


        end

        % Button pushed function: GroupButton
        function GroupButtonPushed(app, event)
            selectedNodes = app.Tree.SelectedNodes;

            fstIdx = find(arrayfun(@(x) strcmp(x.Text,selectedNodes(1).Text) ,app.Tree.Children));
            lastIdx = find(arrayfun(@(x) strcmp(x.Text,selectedNodes(end).Text) ,app.Tree.Children));
            hasChildren = arrayfun(@(x) ~isempty(x.Children), selectedNodes);
            if any(hasChildren)
                newGroupNode = selectedNodes(hasChildren);
                selectedNodes(hasChildren) = [];
            else
                groupNodeIdxs = find(arrayfun(@(x) ~isempty(x.Children), app.Tree.Children));
                newGroupNode = uitreenode(app.Tree, "Text", ['Group ' num2str(numel(groupNodeIdxs)+1)]);
                move(newGroupNode, selectedNodes(1), 'before');
            end            
            arrayfun(@(x) set(x, 'Parent', newGroupNode), selectedNodes);

        end

        % Button pushed function: UngroupButton
        function UngroupButtonPushed(app, event)
            selectedNodes = app.Tree.SelectedNodes;
            numNodes = numel(app.Tree.Children);
            groupNode = selectedNodes(1).Parent;
            groupNodeIdx = find(arrayfun(@(x) strcmp(x.Text, groupNode.Text) ,app.Tree.Children));
            if groupNodeIdx < numNodes
                reArrange = true;
            else
                reArrange = false;
            end

            arrayfun(@(x) set(x, 'Parent', app.Tree), selectedNodes);
            
            %new Idxs
            newNumNodes = numel(app.Tree.Children);
            if reArrange
                newIdxs = [(1:groupNodeIdx)...
                    ( (newNumNodes - numel(selectedNodes)+1): newNumNodes) ...
                    (groupNodeIdx+1:(newNumNodes - numel(selectedNodes))) ];

                app.Tree.Children = app.Tree.Children(newIdxs);
            end

%             for ii = numel(selectedNodes):-1:1
%                 move(selectedNodes(ii),groupNode, 'after');
%             end
            
            %if group is now emtpy: delete
            if numel(groupNode.Children) == 0
                delete(groupNode);
            end
        end

        % Button pushed function: ButtonTop
        function ButtonTopPushed(app, event)
            selectedNodes = app.Tree.SelectedNodes;
            parentNode = selectedNodes(1).Parent;
            fstNode = parentNode.Children(1);
            for ii = 1:numel(selectedNodes)
                move(selectedNodes(ii), fstNode, 'before')
            end
            app.TreeSelectionChanged();
        end

        % Button pushed function: ButtonUp
        function ButtonUpPushed(app, event)
            selectedNodes = app.Tree.SelectedNodes;
            parentNode = selectedNodes(1).Parent;
            fstSelNodeIdx = find(arrayfun(@(x) strcmp(x.Text,selectedNodes(1).Text),...
                    parentNode.Children));
            prevNode = parentNode.Children(fstSelNodeIdx-1);
            move(prevNode, selectedNodes(end), 'after');
            app.TreeSelectionChanged();
        end

        % Button pushed function: ButtonDown
        function ButtonDownPushed(app, event)
            selectedNodes = app.Tree.SelectedNodes;
            parentNode = selectedNodes(1).Parent;
            lastSelNodeIdx = find(arrayfun(@(x) strcmp(x.Text,selectedNodes(end).Text),...
                    parentNode.Children));
            nextNode = parentNode.Children(lastSelNodeIdx+1);
            move(nextNode, selectedNodes(1), 'before');
            app.TreeSelectionChanged();
        end

        % Button pushed function: ButtonBottom
        function ButtonBottomPushed(app, event)
            selectedNodes = app.Tree.SelectedNodes;
            parentNode = selectedNodes(1).Parent;
            for ii = 1:numel(selectedNodes)
                move(selectedNodes(ii), parentNode.Children(end), 'after')
            end
            app.TreeSelectionChanged();
        end

        % Button pushed function: SaveExitButton
        function SaveExitButtonPushed(app, event)
            idxCell = cell(numel(app.Tree.Children),1);
            isGroup = arrayfun(@(x) ~isempty(x.Children), app.Tree.Children);
            
            idxCell(isGroup) = arrayfun(@(x) arrayfun(@(x) x.NodeData, x.Children), app.Tree.Children(isGroup), "UniformOutput",false);
            idxCell(~isGroup) = arrayfun(@(x) x.NodeData, app.Tree.Children(~isGroup), "UniformOutput",false);

            noMembers = cellfun(@numel,idxCell);
            newidxCell = num2cell(cumsum(noMembers));
            newidxCell(isGroup) = cellfun(@(x,y) (x-y+1:x), ...
                newidxCell(isGroup), num2cell(noMembers(isGroup)), "UniformOutput",false);

            flatIdxs = cell2mat(idxCell);
            groupIdxs = [{cell2mat(newidxCell(~isGroup))};  newidxCell(isGroup)];
            groupNames = [{''}; arrayfun(@(x) x.Text, app.Tree.Children(isGroup), "UniformOutput", false)];
            %Gruppenindices müssen die neuen Indices sein!

            app.handle.(app.outp) = {flatIdxs, groupIdxs, groupNames};

            app.UIFigureCloseRequest;
        end

        % Callback function: CancelButton, UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.WindowStyle = 'modal';

            % Create Tree
            app.Tree = uitree(app.UIFigure);
            app.Tree.Multiselect = 'on';
            app.Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
            app.Tree.Position = [44 88 530 336];

            % Create GroupButton
            app.GroupButton = uibutton(app.UIFigure, 'push');
            app.GroupButton.ButtonPushedFcn = createCallbackFcn(app, @GroupButtonPushed, true);
            app.GroupButton.Position = [44 50 100 22];
            app.GroupButton.Text = 'Group';

            % Create UngroupButton
            app.UngroupButton = uibutton(app.UIFigure, 'push');
            app.UngroupButton.ButtonPushedFcn = createCallbackFcn(app, @UngroupButtonPushed, true);
            app.UngroupButton.Position = [164 50 100 22];
            app.UngroupButton.Text = 'Ungroup';

            % Create ButtonTop
            app.ButtonTop = uibutton(app.UIFigure, 'push');
            app.ButtonTop.ButtonPushedFcn = createCallbackFcn(app, @ButtonTopPushed, true);
            app.ButtonTop.FontSize = 28;
            app.ButtonTop.Position = [579 346 22 44];
            app.ButtonTop.Text = '⤒';

            % Create ButtonUp
            app.ButtonUp = uibutton(app.UIFigure, 'push');
            app.ButtonUp.ButtonPushedFcn = createCallbackFcn(app, @ButtonUpPushed, true);
            app.ButtonUp.FontSize = 28;
            app.ButtonUp.Position = [579 284 22 44];
            app.ButtonUp.Text = '↑';

            % Create ButtonDown
            app.ButtonDown = uibutton(app.UIFigure, 'push');
            app.ButtonDown.ButtonPushedFcn = createCallbackFcn(app, @ButtonDownPushed, true);
            app.ButtonDown.FontSize = 28;
            app.ButtonDown.Position = [579 222 22 44];
            app.ButtonDown.Text = '↓';

            % Create ButtonBottom
            app.ButtonBottom = uibutton(app.UIFigure, 'push');
            app.ButtonBottom.ButtonPushedFcn = createCallbackFcn(app, @ButtonBottomPushed, true);
            app.ButtonBottom.FontSize = 28;
            app.ButtonBottom.Position = [579 160 22 44];
            app.ButtonBottom.Text = '⤓';

            % Create SaveExitButton
            app.SaveExitButton = uibutton(app.UIFigure, 'push');
            app.SaveExitButton.ButtonPushedFcn = createCallbackFcn(app, @SaveExitButtonPushed, true);
            app.SaveExitButton.Position = [411 12 100 22];
            app.SaveExitButton.Text = 'Save & Exit';

            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.CancelButton.Position = [527 12 100 22];
            app.CancelButton.Text = 'Cancel';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = GroupAndSortData_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end