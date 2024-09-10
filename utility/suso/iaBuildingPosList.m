function [buildingPosList, buildingList] = iaBuildingPosList(sceneType, sceneRecipe, showfigure, st)
% Randomly place buildings in one given region.
%
% Given the info of spare region(lenth in x axis, lenth in y axis and
% coordinate origin) and a building list including the
% building name and size. Return a settle list, record the settle positions
% and building name.
%
% Input:
%       objects: recipe of assets.      e.g. thisR
%       sceneType: type of the scene.

% input of subfunction:(generated according to Input)
%       lenx_tmp: lenth of spare region in x axis
%       leny_tmp: lenth of spare region in y axis
%       coordinate: origin coordinate(lower left point of building, when
%       face to the building).
%       type: define what kind of batch the region is.
%               including:'front','left','right','back', means the building
%               area in front/left/right/back of the road.
%
% Output:
%       buildingPosList: record how to settle buildings on the given region,
%       including building position and building name(position refer to the
%       lower left point.
%       buildingList: assets list.
%
% Parameter:
%       offset: adjust the interval between the buildings. default is 2
%
%
% Jiaqi Zhang
% 09.21.2018
% Zhenyi updated, 2021
%
% See also
%  piBuildingPlace

%% create a building list
if ~exist('st', 'var') 
    st = scitran('stanfordlabs');
end
buildingListPath = fullfile(iaRootPath,'data','suso',...
    sprintf('%s_building_list.mat',sceneType));

if ~exist(buildingListPath,'file')
    buildingList = iaAssetListCreate('session', sceneType, 'scitran', st);
    save(buildingListPath,'buildingList');
else
    load(buildingListPath,'buildingList');
end
%%
switch sceneType
    case 'city1'
        nn=1;
        for ii = 1:length(buildingList)
            if contains(buildingList(ii).name,{'_022','_023','_024','_025'})
                newBuildingList(nn) = buildingList(ii);nn=nn+1;
            end
        end
        buildingList = newBuildingList;
    case 'city2'
        nn=1;
        for ii = 1:length(buildingList)
            if contains(buildingList(ii).name,{'_026', '_027', '_028', '_029', '_030',...
                                                '_031', '_032', '_033', '_034', '_035',...
                                                '_036', '_037', '_038', '_039', '_040',...
                                                '_041', '_042', '_043', '_044','_45',...
                                                '_46', '_47', '_48', '_49', '_50',...
                                                '_51', '_52', '_53', '_54', '_55',...
                                                '_56', '_57', '_58', '_59', '_60'})
                newBuildingList(nn) = buildingList(ii);nn=nn+1;
            end
        end
        buildingList = newBuildingList;
    case 'city3'
        nn=1;
        for ii = 1:length(buildingList)
            if contains(buildingList(ii).name,{'_26', '_27', '_28', '_29', '_30',...
                                                '_31', '_32', '_33', '_34', '_36',...
                                                '_37', '_38', '_40', '_41', '_42',...
                                                '_43', '_45', '_46', '_47', '_48',...
                                                '_49', '_50', '_51', '_52'})
                newBuildingList(nn) = buildingList(ii);nn=nn+1;
            end
        end
        buildingList = newBuildingList;
    case 'city4'
        nn=1;
        for ii = 1:length(buildingList)
            if contains(buildingList(ii).name,{'_01', '_02', '_03', '_04', '_05', '_06',...
                    '_07', '_08', '_09', '_10', '_11', '_12', '_13', '_14', '_15', '_16',...
                    '_17', '_18', '_19', '_22', '_23', '_24', '_25', '_26', '_27', '_29',...
                    '_30', '_32', '_33', '_34', '_35', '_37', '_38', '_39', '_40', '_41',...
                    '_42', '_43', '_44'})
                newBuildingList(nn) = buildingList(ii);nn=nn+1;
            end
        end
        buildingList = newBuildingList;
    case 'suburb'
        nn=1;
        for ii = 1:length(buildingList)
            if contains(buildingList(ii).name,{'_010','_016','_018','_019'})
                newBuildingList(nn) = buildingList(ii);nn=nn+1;
            end
        end
        buildingList = newBuildingList;        
end

buildingPosList = struct;
for ii = 1:length(buildingList)
    building_list.size(ii, 1) = buildingList(ii).size.l;
    building_list.size(ii, 2) = buildingList(ii).size.w;
    building_list.name{ii} = buildingList(ii).name;
end

% tmp = 0;
count = 1;  % initial parameters
buildingPosList_tmp = struct;
sum = 0;
for mm = 1:length(buildingList)
    sum = buildingList(mm).size.w + sum;
end
aveW = sum/length(buildingList)+10; 

% calculate the average width of all the buildings variable aveW can 
% be used to delete unnecessary buildings in the scene

% assetList = sceneRecipe.get('asset list');
assetList = sceneRecipe.get('object names');
assetIDs = sceneRecipe.get('object');
for kk = 1:numel(assetList)
    % name = strsplit(assetList{kk}, '_');
    if contains(assetList{kk}, 'Plane') % if the object is a building region.
        count_before = count;
        % get the size of the asset
        thisAsset = sceneRecipe.get('asset parent',assetIDs(kk));
        if contains(thisAsset.name,'Plane_front'),type = 'front';
        elseif contains(thisAsset.name,'Plane_back'),type = 'back';
        elseif contains(thisAsset.name,'Plane_left'),type = 'left';
        elseif contains(thisAsset.name,'Plane_right'),type = 'right';
        else
            error('Road Asset Type does not exist');
        end
            
        lenx_tmp = thisAsset.size.l;
        leny_tmp = thisAsset.size.w;
        coordination = thisAsset.translation;
        y_up = coordination(2);
        coordination = [coordination(1),coordination(3)];
        switch type
            case 'front'
                if coordination(1)<0
                    ankor = coordination + [lenx_tmp, 1];
                else
                    ankor = coordination;
                end
            case 'back'
                if coordination(1)>0
                    ankor = coordination - [lenx_tmp, 1];
                else
                    ankor = coordination;
                end
            otherwise
                ankor = coordination;
        end
        [buildingPosList_tmp, count] = buildingPlan(building_list, ...
            lenx_tmp, leny_tmp, coordination, buildingPosList_tmp, count, type, ankor, aveW);
        
        %% change the structure of the output data
        for jj = count_before:length(buildingPosList_tmp)
            buildingPosList(jj).name = buildingPosList_tmp(jj).name;
            buildingPosList(jj).position = [buildingPosList_tmp(jj).position(1),y_up,...
                buildingPosList_tmp(jj).position(2)];
            buildingPosList(jj).rotate = buildingPosList_tmp(jj).rotate;
        end
        
        %% test algotithm. Comment this part when using.
        if showfigure
            figure(1);
            hold on;xlim([-130, 130]);ylim([-30, 280]);hold on;
            switch type
                case 'front'
                    % test algorithm for 'front' situation
                    
                    for jj = count_before:length(buildingPosList)
                        for ii = 1:size(building_list.name, 2)
                            if strcmpi(building_list.name(ii), buildingPosList(jj).name)
                                xx = building_list.size(ii, 1);
                                yy = building_list.size(ii, 2);
                            end
                        end
                        rectangle('Position',[buildingPosList(jj).position(1),buildingPosList(jj).position(3),xx,yy],...
                            'FaceColor',[0.3 0.3 0.3 0.5]);title('front');
                    end
                case 'right'
                    % test algorithm for 'right' situation
                    
                    for jj = count_before:length(buildingPosList)
                        for ii = 1:size(building_list.name, 2)
                            if strcmpi(building_list.name(ii), buildingPosList(jj).name)
                                xx = building_list.size(ii, 1);
                                yy = building_list.size(ii, 2);
                            end
                        end
                        rectangle('Position',[buildingPosList(jj).position(1),buildingPosList(jj).position(3)-xx,yy,xx],...
                            'FaceColor',[0.3 0.3 0.3 0.5]);title('right');
                    end
                case 'left'
                    % test algorithm for 'left' situation
                    
                    for jj = count_before:length(buildingPosList)
                        for ii = 1:size(building_list.name, 2)
                            if strcmpi(building_list.name(ii), buildingPosList(jj).name)
                                xx = building_list.size(ii, 1);
                                yy = building_list.size(ii, 2);
                            end
                        end
                        rectangle('Position',[buildingPosList(jj).position(1)-yy,buildingPosList(jj).position(3),yy,xx],...
                            'FaceColor',[0.3 0.3 0.3 0.5]);title('left');
                    end
                    % test algorithm for 'back' situation
                case 'back'
                    for jj = count_before:length(buildingPosList)
                        for ii = 1:size(building_list.name, 2)
                            if strcmpi(building_list.name(ii), buildingPosList(jj).name)
                                xx = building_list.size(ii, 1);
                                yy = building_list.size(ii, 2);
                            end
                        end
                        rectangle('Position',[buildingPosList(jj).position(1)-xx,buildingPosList(jj).position(3)-yy,xx,yy],...
                            'FaceColor',[0.3 0.3 0.3 0.5]);title('back');
                    end
            end
        end
        % tmp = tmp + 1; 
        % disp(tmp);

    end
    
end

end

%%
% ----------------------------
function [settle_list, count] = buildingPlan(building_list, lenx_tmp, ...
    leny_tmp, coordination, settle_list, count, type, ankor, aveW)
offset = 0.2; % adjust the interval berween the buildings. Don't too big! Or might cause problem!

%% calculate the parameter in spare region.
switch type
    case 'front'
        A = [coordination(1), coordination(2)+leny_tmp];  % ABCD are 4 vertices of spare region
        B = coordination;
        C = [coordination(1)+lenx_tmp, coordination(2)];
        D = [coordination(1)+lenx_tmp, coordination(2)+leny_tmp];
        lenx = lenx_tmp;    % lenx is the lenth of spare region in x direction
        leny = leny_tmp;    % leny is the lenth of spare region in y direction
        
    case 'right'
        A = [coordination(1), coordination(2)-leny_tmp];  % ABCD are 4 vertices of spare region
        B = coordination;
        C = [coordination(1)+lenx_tmp, coordination(2)];
        D = [coordination(1)+lenx_tmp, coordination(2)-leny_tmp];
        leny = lenx_tmp;    % lenx is the lenth of spare region in x direction
        lenx = leny_tmp;    % leny is the lenth of spare region in y direction
        
    case 'left'
        A = [coordination(1)-lenx_tmp, coordination(2)];  % ABCD are 4 vertices of spare region
        B = coordination;
        C = [coordination(1), coordination(2)+leny_tmp];
        D = [coordination(1)-lenx_tmp, coordination(2)+leny_tmp];
        leny = lenx_tmp;    % lenx is the lenth of spare region in x direction
        lenx = leny_tmp;    % leny is the lenth of spare region in y direction
        
    case 'back'
        A = [coordination(1), coordination(2)-leny_tmp];  % ABCD are 4 vertices of spare region
        B = coordination;
        C = [coordination(1)-lenx_tmp, coordination(2)];
        D = [coordination(1)-lenx_tmp, coordination(2)-leny_tmp];
        lenx = lenx_tmp;    % lenx is the lenth of spare region in x direction
        leny = leny_tmp;    % leny is the lenth of spare region in y direction
end



% selectx record the index of buildings that can be put in spare region in x direction
selectx = find(building_list.size(:,1)<=lenx);
selecty = find(building_list.size(:,2)<=leny);
sel = intersect(selectx, selecty);  % sel record the index of buildings that can be put in spare region
% disp(sel)

%% Decide if there is any building which can be put in the spare region
% if it is possiple, put it in spare region, record the position and id of
% the building in spare region. And update the new spare region, then recursion.

if ~isempty(sel)    % it is possible to put a new building on spare region
    
    building_idx = sel(randi([1,length(sel)],1,1)); % randomly get index of proper building
    id = building_list.name{building_idx}; % get name and size of the proper building
    build_x = building_list.size(building_idx, 1) + offset;
    build_y = building_list.size(building_idx, 2) + offset;
    switch type
        case 'front'
            % calculate info of spare region 1
            A1 = A;
            B1 = B + [0, build_y];
            C1 = B + [build_x, build_y];
            D1 = [B(1)+build_x, A(2)];
            next_x1 = build_x;
            next_y1 = A1(2) - B1(2);
            
            % calculate info of spare region 2
            A2 = D1;
            B2 = B + [build_x, 0];
            C2 = C;
            D2 = D;
            next_x2 = C2(1) - B2(1);
            next_y2 = D2(2) - C2(2);
            
            % record the info of new biulding, including id, x and y coordinates
            % only record the building's info that confirm our requirments
            if B(1)<0   % delete unnecessary buildings
                marginX = aveW; marginY = 2;
            else
                marginX = 2; marginY = 2;
            end
            
            if (abs(ankor(1)-B(1))<marginX)||(abs(ankor(2)-B(2))<marginY)
                
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 0;
                count = count + 1;  % count the buildings amount
            end
            
            
            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, next_y2, B2, settle_list, count, type, ankor, aveW);
            
        case 'right'
            A1 = A;
            B1 = B + [0, -build_x];
            C1 = B + [build_y, -build_x];
            D1 = [B(1)+build_y, A(2)];
            next_x1 = build_y;
            next_y1 = B1(2) - A1(2);
            
            A2 = D1;
            B2 = B + [build_y, 0];
            C2 = C;
            D2 = D;
            next_x2 = C2(1) - B2(1);
            next_y2 = C2(2) - D2(2);
            
            if abs(ankor(1)-B(1))<1%||(abs(ankor(2)-B(2))<11)
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 90;
                count = count + 1;  % count the buildings amount
            end
            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, next_y2, B2, settle_list, count, type, ankor, aveW);
            
        case 'left'
            % calculate info of spare region 1
            A1 = A;
            B1 = B + [-build_y, 0];
            C1 = B + [-build_y, build_x];
            D1 = A + [0, build_x];
            next_x1 = B1(1) - A1(1);
            next_y1 = build_x;
            
            % calculate info of spare region 2
            A2 = D1;
            B2 = B + [0, build_x];
            C2 = C;
            D2 = D;
            next_x2 = C2(1) - D2(1);
            next_y2 = C2(2) - B2(2);
            
            if abs(ankor(1)-B(1))<1%||(abs(ankor(2)-B(2))<11)
                % record the info of new biulding, including id, x and y coordinates
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 270;
                count = count + 1;  % count the buildings amount
            end
            
            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, next_y2, B2, settle_list, count, type, ankor, aveW);
        case 'back'
            % calculate info of spare region 1
            A1 = A;
            B1 = B + [0, -build_y];
            C1 = B + [-build_x, -build_y];
            D1 = [B(1)-build_x, A(2)];
            next_x1 = build_x;
            next_y1 = B1(2) - A1(2);
            
            % calculate info of spare region 2
            A2 = D1;
            B2 = B + [-build_x, 0];
            C2 = C;
            D2 = D;
            next_x2 = B2(1) - C2(1);
            next_y2 = C2(2) - D2(2);
            
            if B(1)>0   % delete unnecessary buildings
                marginX = aveW; marginY = 2;
            else
                marginX = 2; marginY = 2;
            end
            
            if (abs(ankor(1)-B(1))<marginX)||(abs(ankor(2)-B(2))<marginY)
                % record the info of new biulding, including id, x and y coordinates
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 180;
                count = count + 1;  % count the buildings amount
            end
            
            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, next_y2, B2, settle_list, count, type, ankor, aveW);
            
    end
else
    % it is not possible to put a new building on spare region, sign out the recursion
end

end
