function obj = assemble(obj,varargin)
% Assemble the assets specified in the road class
%
% Synopsis:
%    roadgen.assemble;
%
% Brief description:
%   We use the road parameters to place the cars, animals and so forth
%   into the scene
%
%   We generate random points on /off the road, on the road, the points are
%   used to place cars or other objects defined by users. off the road we
%   place trees for now, we will add building or other type of objects later.
%
% TODO:
%   Add motion

%% Initialize the onroad and offset components

obj.road.useTF = true; % tmp

obj.initialize();
%% Generate object lists on the road

if isfield(obj.road, 'scene')
    % load traffic flow data
    tfDataPath   = fullfile(iaRootPath,'data','sumo_input','demo',...
        'trafficflow',sprintf('%s_%s_trafficflow.mat',obj.road.scene.roadType,obj.road.scene.trafficflowDensity));
    localTF = fullfile(iaRootPath,'local','trafficflow');
    if ~exist(localTF,'dir'), mkdir(localTF);end
    copyfile(tfDataPath, localTF);
    load(tfDataPath, 'trafficflow');
    disp('[INFO]: Using SUMO Trafficflow.')
    thisTF = trafficflow(obj.road.scene.timestamp);
    assetNames = fieldnames(thisTF.objects);
    obj.road.useTF = true;
    obj.road.trafficflow = thisTF;
else
    obj.road.useTF = false;
    assetNames = fieldnames(obj.onroad);
end

% For each type of asset on the road
for ii = 1:numel(assetNames)
    OBJClass = assetNames{ii};
    if ~obj.road.useTF
        onroadOBJ = obj.onroad.(OBJClass);
        namelist = [];

        % Initialize and then place the objects in each lane.
        positions = cell(size(onroadOBJ.lane, 1));
        rotations = cell(size(onroadOBJ.lane, 1));
        objIdList = cell(size(onroadOBJ.lane, 1));
        % Depending on the asset name
        switch assetNames{ii}
            % below could use refactoring into a function
            case {'car','bus', 'truck', 'biker','bicycle'}

                for jj = 1:numel(onroadOBJ.lane)
                    if ~isfield(onroadOBJ,'number') || onroadOBJ.number(jj) == 0, continue; end
                    [positions{jj}, rotations{jj}] = obj.rrMapPlace(...
                        'laneType',onroadOBJ.lane{jj},'pos','onroad',...
                        'pointnum',onroadOBJ.number(jj));
                    % Create a object list, number of assets is smaller then
                    % the number of objects requested. so object instancing are
                    % needed.
                    objIdList{jj} = randi(numel(onroadOBJ.namelist), onroadOBJ.number(jj), 1);
                    namelist = vertcat(namelist,objIdList{jj});
                end

            case {'animal', 'pedestrian'}
                for jj = 1:numel(onroadOBJ.lane)
                    if onroadOBJ.number(jj) == 0, continue; end
                    [positions{jj}, rotations{jj}] = obj.rrMapPlace(...
                        'laneType',onroadOBJ.lane{jj},'pos','onroad',...
                        'pointnum',onroadOBJ.number(jj),'rotOffset',pi*0.25);

                    objIdList{jj} = randi(numel(onroadOBJ.namelist), onroadOBJ.number(jj), 1);
                    namelist = vertcat(namelist,objIdList{jj});
                end

        end
    else
        % randomly pick 5 unique objects to save rendering time.
        assetInfo = assetlib;
        assetlibNames = keys(assetInfo);

        if strcmp(OBJClass,'bicycle')
            AssetNames = assetlibNames(contains(assetlibNames,'biker'));
        else
            AssetNames = assetlibNames(contains(assetlibNames,OBJClass));
        end
        % set the number of unique assets as a parameter in the future.
        namelist = AssetNames(sort(randperm(numel(AssetNames),5)));

        objIdList{1} = randi(numel(namelist), numel(thisTF.objects.(OBJClass)), 1);
        for tt = 1:numel(thisTF.objects.(OBJClass))
            positions_tmp(tt,:) = thisTF.objects.(OBJClass)(tt).pos(:);
            rotations_tmp(tt,:) = deg2rad([-90;thisTF.objects.(OBJClass)(tt).orientation-90;0]);
        end
        obj.onroad.(OBJClass).namelist = namelist;
        positions = {positions_tmp};
        rotations = {rotations_tmp};
        clear positions_tmp rotations_tmp
    end

    namelist = unique(namelist);

    for nn = 1:numel(obj.onroad.(OBJClass).namelist)
        thisName = obj.onroad.(OBJClass).namelist{nn};
        if strcmp(OBJClass,'bicycle')
            obj = addOBJ(obj, 'biker', thisName);
        else
            obj = addOBJ(obj, OBJClass, thisName);
        end
    end

    obj.onroad.(OBJClass).placedList.objIdList = objIdList;
    obj.onroad.(OBJClass).placedList.positions = positions;
    obj.onroad.(OBJClass).placedList.rotations = rotations;
end
%}
% Generate objects off the road
if ~obj.road.useTF
    assetNames_off = fieldnames(obj.offroad);
    for ii = 1:numel(assetNames_off)
        OBJClass = assetNames_off{ii};
        offroadOBJ = obj.offroad.(OBJClass);
        namelist = [];
        positions = cell(size(offroadOBJ.lane, 1));
        rotations = cell(size(offroadOBJ.lane, 1));
        objIdList = cell(size(offroadOBJ.lane, 1));

        switch assetNames_off{ii}
            case {'animal', 'pedestrian'}
                for jj = 1:numel(offroadOBJ.lane)
                    if offroadOBJ.number(jj) == 0, continue; end
                    [positions{jj}, rotations{jj}] = obj.rrMapPlace(...
                        'laneType',offroadOBJ.lane{jj},'pos','offroad',...
                        'pointnum',offroadOBJ.number(jj),'rotOffset',pi*0.25);

                    objIdList{jj} = randi(numel(offroadOBJ.namelist), offroadOBJ.number(jj), 1);
                    namelist = vertcat(namelist,objIdList{jj});
                end
            case {'tree', 'rock', 'grass', 'streetlight'}
                OBJClass = assetNames_off{ii};
                offroadOBJ = obj.offroad.(OBJClass);
                namelist = [];

                scale = cell(size(offroadOBJ.lane, 1));
                if ~strcmp(OBJClass, 'streetlight')
                    for jj = 1:numel(offroadOBJ.lane)
                        if offroadOBJ.number(jj) == 0, continue; end
                        [positions{jj}, rotations{jj}] = obj.rrMapPlace(...
                            'laneType',offroadOBJ.lane{jj},'pos','offroad',...
                            'pointnum',offroadOBJ.number,'posOffset',1);

                        scale{jj} = rand(size(positions{jj},1),1)+0.5;

                        objIdList{jj} = randi(numel(offroadOBJ.namelist), size(positions{jj},1), 1);
                        namelist = vertcat(namelist,objIdList{jj});
                    end
                else
                    for jj = 1:numel(offroadOBJ.lane)
                        [positions{jj}, rotations{jj}] = obj.rrMapPlace(...
                            'laneType',offroadOBJ.lane{jj},'pos','offroad',...
                            'pointnum',offroadOBJ.number(jj),'posOffset',0.1,...
                            'uniformsample',true, 'mindistancetoroad',-2);
                        objIdList{jj} = randi(numel(offroadOBJ.namelist), size(positions{jj},1), 1);
                        namelist = vertcat(namelist,objIdList{jj});
                    end
                end
        end

        namelist = unique(namelist);
        for nn = 1:numel(namelist)
            thisName = offroadOBJ.namelist{namelist(nn)};
            obj = addOBJ(obj, OBJClass, thisName);
        end

        obj.offroad.(OBJClass).placedList.objIdList = objIdList;
        obj.offroad.(OBJClass).placedList.positions = positions;
        obj.offroad.(OBJClass).placedList.rotations = rotations;

    end


    %% Add objects
    % check overlap, remove overlapped objects
    obj = obj.overlappedRemove();
else
    % Add buildings, trees, and other stationary objects using a different
    % method.
    assetInfo = assetlib;
    assetlibNames = keys(assetInfo);
    treeNames = assetlibNames(contains(assetlibNames,'tree'));
    susoPlaced = obj.road.scene.susoplaced;
    susoNames = fieldnames(susoPlaced);

    for ss = 1:numel(susoNames)
        OBJClass = susoNames{ss};
        % set the number of unique assets as a parameter in the future.
        if strcmp(OBJClass,'tree')
            % use new assets for trees
            namelist = treeNames(sort(randperm(numel(treeNames),numel(susoPlaced.(OBJClass)))));
        else
            namelist =[];
        end
        % objIdList_tmp{1} = [];
        index = 1;
        for nn = 1:numel(susoPlaced.(OBJClass))
            if ~strcmp(OBJClass,'tree')
                namelist{nn} = susoPlaced.(OBJClass)(nn).name;
            end
            % objIdList{end+1} = randi(numel(susoPlaced.(OBJClass)), numel(susoPlaced.(OBJClass)(nn).position), 1);
            for ll = 1:numel(susoPlaced.(OBJClass)(nn).position)
                objIdList_tmp(index) = nn;
                positions_tmp(index,:) = susoPlaced.(OBJClass)(nn).position{ll}(:);
                if strcmp(OBJClass,'tree')
                    rotations_tmp(index,:) = deg2rad([-90;susoPlaced.(OBJClass)(nn).rotation{ll}(1,2);0]);
                else
                    rotations_tmp(index,:) = deg2rad([0;susoPlaced.(OBJClass)(nn).rotation{ll}(1,2);0]);
                end
                index = index+1;
            end
        end
        obj.offroad.(OBJClass).namelist = namelist;
        objIdList = {objIdList_tmp};
        positions = {positions_tmp};
        rotations = {rotations_tmp};
        clear positions_tmp rotations_tmp objIdList_tmp

        namelist = unique(namelist);
        for nn = 1:numel(namelist)
            thisName = obj.offroad.(OBJClass).namelist{nn};
            if strcmp(OBJClass,'tree')
                obj = addOBJ(obj, OBJClass, thisName);
            else
                if strcmp(OBJClass,'building')
                    recipeFile = fullfile(obj.assetdirectory, obj.road.scene.sceneType, thisName, [thisName,'.recipe.mat']);
                else
                    recipeFile = fullfile(obj.assetdirectory, 'others', thisName, [thisName,'.recipe.mat']);
                end
                tmp = load(recipeFile);
                assetRecipe  = tmp.thisR; 
                assetRecipe.set('input file',strrep(recipeFile,'.recipe.mat','.pbrt'));
                inputFolder = assetRecipe.get('input dir');
                unzip(strrep(recipeFile,'.recipe.mat','.cgresource.zip'),inputFolder);
                % The legacy recipes are missing certain fields, we update
                % them before merging into the main recipe.
                [assetRecipe,OBJInstanceName] = piObjectInstanceConvert(assetRecipe);
                % if contains(obj.offroad.(OBJClass).namelist, erase(OBJInstanceName,'_m_B'))
                %     warning('Duplicated ojbects:%s',OBJInstanceName);
                %     continue;
                % end
                if ~contains(OBJInstanceName,namelist{nn})
                    obj.offroad.(OBJClass).namelist{nn} = erase(OBJInstanceName,'_m_B');
                end
                obj = addOBJ(obj, OBJClass, thisName, assetRecipe);
                                
                clear tmp;
            end
        end

        obj.offroad.(OBJClass).placedList.objIdList = objIdList;
        obj.offroad.(OBJClass).placedList.positions = positions;
        obj.offroad.(OBJClass).placedList.rotations = rotations;
    end
end
disp('[INFO]: AssetsList is generated');

%% Place assets
% on road
assetNames_onroad = fieldnames(obj.onroad);
obj = obj.assetPlace(assetNames_onroad,'onroad');
% off road
assetNames_offroad = fieldnames(obj.offroad);

assetNames_offroad(contains(assetNames_offroad,'bikerack'))=[];
obj = obj.assetPlace(assetNames_offroad,'offroad');
disp('[INFO]: Assets Placed.')
%%
% skyname = obj.skymap;
% Delete any lights that happened to be there
% obj.recipe = piLightDelete(obj.recipe, 'all');
%
% rotation(:,1) = [0 0 0 1]';
% rotation(:,2) = [45 0 1 0]';
% rotation(:,3) = [-90 1 0 0]';

% skymap = piLightCreate('new skymap', ...
%     'type', 'infinite',...
%     'string mapname', skyname,...
%     'specscale',2.2269e-04);
% to fix, add rotation

% obj.recipe.set('light', skymap, 'add');
% disp('--> Skymap added');

end

function obj = addOBJ(obj, OBJClass, thisName, thisAssetRecipe)

id = piAssetFind(obj.recipe.assets, 'name',[thisName,'_m_B']); % check whether it's there already

if isempty(id)

    % First check to see if we already have the asset
    % if exist([thisName '.mat'], 'file')
    %     recipeFile = [thisName '.mat'];
    % elseif exist([thisName '.pbrt'], 'file')
    %     pbrtFile = [thisName '.pbrt'];
    %     % We might get a non-existent directory or a database connection
    if ~exist('thisAssetRecipe','var')
        if ~ischar(obj.assetdirectory) || ~isfolder(obj.assetdirectory)
            assetDB = isetdb;
            thisAsset = assetDB.docFind('assetsPBRT', ...
                sprintf("{""name"": ""%s""}", thisName));

            pbrtFile = fullfile(thisAsset.folder, [thisName,'.pbrt']);
            recipeFile = fullfile(thisAsset.folder, [thisName,'.mat']);
        else
            pbrtFile = fullfile(obj.assetdirectory, OBJClass, thisName, [thisName,'.pbrt']);
            recipeFile = fullfile(obj.assetdirectory, OBJClass, thisName, [thisName,'.mat']);
        end

        if exist(recipeFile,'file')
            thisAssetRecipe = load(recipeFile);
            thisAssetRecipe = thisAssetRecipe.recipe;
        else
            thisAssetRecipe = piRead(pbrtFile);
        end
    end

    obj.recipe = piRecipeMerge(obj.recipe, thisAssetRecipe, 'objectInstance',true);
end

end


