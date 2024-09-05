function [points, rot] = rrMapPlace(obj,varargin)
% Generate a position list for assets on the map
% Input:
%
% laneTypes:
%   'leftdriving': left lane/lanes.
%   'rightdriving': right lane/lanes.
%   'leftshoulder': shoulder of left lane.
%   'rightshoulder': shoulder of right lane.
%   'leftsidewalk': left sidewalk lane.
%   'rightsidewalk': right sidewalk lane.
%
% pos:
%   'onroad': generate points on lane.
%   'offroad':generate points on offroad
%
% 'pointnum':
%    number of points. This can be a single number or an array.
%'layerWidth':
%    offroad sub-areas divided by pointnum input.
%'minDistanceToRoad':
%    mininum distance to the road which an asset is allowed to
%    place.
%l
% We will use the diagram below to show three parameters above:
%
%    pointnum = [100, 50, 30]
%    layerWidth is denoted by LW.
%    minDistanceToRoad is denoted by MDR
%
%    |< LW  >|< LW  >|< LW  >|<MDR>|--------|
%    |       |       |       |<MDR>|--------|
%    |30     |50     |100    |<MDR>|--road--|
%    |objects|objects|objects|<MDR>|--------|
%    |       |       |       |<MDR>|--------|
%    (The other side of the road is symmetric)
%
%    04-02: multiple lanes are supported, we can specify lanenum, lanenum
%    counts from north to south.
%
%    We can gradually reduce the number of assets with the
%    increase of distance to the road, this is mainly for
%    saving memory sapce and rendering time.
%
% Output:
%    points: a list of positions defined by [x, y, z]
%    rot   : a list of rotations defined by radian.
%
%%
p = inputParser;
p.addParameter('lanetypes','');
p.addParameter('pos','onroad');
p.addParameter('pointnum',0,@isnumeric);
p.addParameter('layerWidth',5,@isnumeric);
p.addParameter('mindistancetoroad',2,@isnumeric);
p.addParameter('posOffset',0); % allow an offset to add randomness (meter)
p.addParameter('rotOffset',0); % allow an offset to add randomness (radian)
p.addParameter('laneid',-1,@isnumeric)
p.addParameter('uniformsample',false,@islogical);

p.parse(varargin{:});

pos  = p.Results.pos;
laneTypes = p.Results.lanetypes;
minDistanceToRoad = p.Results.mindistancetoroad;
layerWidth = p.Results.layerWidth;
pointnum   = p.Results.pointnum;
posOffset  = p.Results.posOffset;
rotOffset  = p.Results.rotOffset;
laneID     = p.Results.laneid;
uniformSample = p.Results.uniformsample;

sumofpoints=sum(pointnum);
% convert to cell
laneTypesTmp{1} = laneTypes;
laneTypes = laneTypesTmp;
% lane

% When lane Id is not specified, we spread the cars on all lanes
if laneID<=0
    if isempty(laneTypes)  % For all driving lanes
        laneTypes=[{'leftdriving'}, repmat({'leftdriving'}, 1 , numel(obj.road.leftdrivingID)-1), repmat({'rightdriving'}, 1, numel(obj.road.rightdrivingID))];
        laneIDlist=[(1:numel(obj.road.leftdrivingID)) (1:numel(obj.road.rightdrivingID))];
        pointnumOneLane = ceil(sumofpoints/(numel(obj.road.leftdrivingID) + numel(obj.road.rightdrivingID)));
        pointnum=ones([1, numel(laneIDlist)])*pointnumOneLane;
    else
        switch laneTypes{1}
            case 'leftdriving'
                laneTypes = [repmat({'leftdriving'}, 1 , numel(obj.road.leftdrivingID))];
                laneIDlist = 1:numel(obj.road.leftdrivingID);
                numarray = abs(normrnd(rand(1, numel(obj.road.leftdrivingID)),0));
                pointnum = ceil(pointnum * numarray/sum(numarray));
            case 'leftshoulder'
                laneTypes = {'leftshoulder'};
                laneIDlist = 1;
            case 'rightdriving'
                laneTypes = [repmat({'rightdriving'}, 1 , numel(obj.road.rightdrivingID))];
                laneIDlist = 1:numel(obj.road.rightdrivingID);
                numarray = abs(normrnd(rand(1, numel(obj.road.rightdrivingID)),0));
                pointnum = ceil(pointnum * numarray/sum(numarray));
            case 'rightshoulder'
                laneTypes = {'rightshoulder'};
                laneIDlist = 1;
            case 'leftsidewalk'
                laneTypes = {'leftsidewalk'};
                laneIDlist = 1;
            case 'rightsidewalk'
                laneTypes = {'rightsidewalk'};
                laneIDlist = 1;
            otherwise
                disp('wrong lane type')
        end

    end
end

% On road objects does not distributed on different layers, so we sum the
% number of points here, and sum is used for onroad case.

%

points = []; % [x, y, z]
dir = []; % [rotx, roty, rotz]

all_points = [];
all_dirs   = [];

for ll = 1:numel(laneTypes)
    % choose a lane type
    laneType = cell2mat(laneTypes(ll));
    laneID = laneIDlist(ll);
    switch laneType
        case 'leftdriving'
            lanecoordinates = obj.road.leftDrivingCoordinates;
        case 'leftshoulder'
            lanecoordinates = obj.road.leftShoulderCoordinates;
        case 'rightdriving'
            lanecoordinates = obj.road.rightDrivingCoordinates;
        case 'rightshoulder'
            lanecoordinates = obj.road.rightShoulderCoordinates;
        case 'leftsidewalk'
            lanecoordinates = obj.road.leftSidewalkCoordinates;
        case 'rightsidewalk'
            lanecoordinates = obj.road.rightSidewalkCoordinates;
        otherwise
            disp('wrong lane type')
    end

    if ~isempty(lanecoordinates{laneID})
        xi=lanecoordinates{laneID}(:,1);yi=lanecoordinates{laneID}(:,2);

        %%
        % randomly generate points in the driving lane or by the road shoulder
        switch pos
            case 'onroad'
                for i=1:pointnum(ll)
                    n1=randi(numel(xi)-1);
                    x1=xi(n1);y1=yi(n1);
                    x2=xi(n1+1);y2=yi(n1+1);
                    k=(y2-y1)/(x2-x1);
                    points(i,1)=x1+rand*(x2-x1);
                    points(i,2)=y1+k*(points(i,1)-x1);
                    [dir(i),~] = cart2pol(x2-x1,y2-y1);

                    points(i,1) = points(i,1) + normrnd(0, posOffset);
                    points(i,2) = points(i,2) + normrnd(0, posOffset);

                    dir(i) = dir(i) + normrnd(0, rotOffset);
                end

            case 'offroad'
                switch laneType
                    case 'leftshoulder'
                        if ~uniformSample
                            j=1;
                            for layer=1:numel(pointnum)
                                for i=1:pointnum(layer)
                                    n1=randi(numel(xi)-1);
                                    x1=xi(n1);y1=yi(n1);x2=xi(n1+1);y2=yi(n1+1);k=(y2-y1)/(x2-x1);
                                    x3=x1+rand*(x2-x1);y3=y1+k*(x3-x1);
                                    dd=minDistanceToRoad+layerWidth*(layer-1)+layerWidth*rand;
                                    points(j,1)=x3-dd*k/sqrt(k*k+1);points(j,2)=y3+dd/sqrt(k*k+1);
                                    [dir(j),~]=cart2pol(x2-x1,y2-y1);
                                    points(j,1) = points(j,1) + normrnd(0, posOffset);
                                    points(j,2) = points(j,2) + normrnd(0, posOffset);
                                    dir(j) = dir(j) + normrnd(0, rotOffset);

                                    j=j+1;
                                end
                            end
                        else
                            j=1;
                            for layer=1:numel(pointnum)
                                placement_intervals = floor((numel(xi)/pointnum(layer)));
                                for ii = 1: pointnum(layer)
                                    pointIdx = ii+placement_intervals*(ii-1);
                                    x1 = xi(pointIdx);y1 = yi(pointIdx);
                                    x2 = xi(pointIdx+1);y2 = yi(pointIdx+1);
                                    k=(y2-y1)/(x2-x1);
                                    dd=minDistanceToRoad+layerWidth*(layer-1)+layerWidth;
                                    points(j,1)=x1-dd*k/sqrt(k*k+1);points(j,2)=y1+dd/sqrt(k*k+1);
                                    [dir(j),~] = cart2pol(x2-x1,y2-y1);
                                    dir(j) = pi/2 - dir(j);
                                    j=j+1;

                                end
                            end
                        end
                    case 'rightshoulder'
                        if ~uniformSample
                            j=1;
                            for layer=1:numel(pointnum)
                                for i=1:pointnum(layer)
                                    n1=randi(numel(xi)-1);
                                    x1=xi(n1);y1=yi(n1);x2=xi(n1+1);y2=yi(n1+1);k=(y2-y1)/(x2-x1);
                                    x3=x1+rand*(x2-x1);y3=y1+k*(x3-x1);
                                    dd=minDistanceToRoad+layerWidth*(layer-1)+layerWidth*rand;
                                    points(j,1)=x3+dd*k/sqrt(k*k+1);points(j,2)=y3-dd/sqrt(k*k+1);
                                    [dir(j),~]=cart2pol(x2-x1,y2-y1);

                                    points(j,1) = points(j,1) + normrnd(0, posOffset);
                                    points(j,2) = points(j,2) + normrnd(0, posOffset);
                                    dir(j) = dir(j) + normrnd(0, rotOffset);

                                    j=j+1;
                                end
                            end
                        else
                            j=1;
                            for layer=1:numel(pointnum)
                                placement_intervals = floor((numel(xi)/pointnum(layer)));
                                for ii = 1: pointnum(layer)
                                    pointIdx = ii+placement_intervals*(ii-1);
                                    x1 = xi(pointIdx);y1 = yi(pointIdx);
                                    x2 = xi(pointIdx+1);y2 = yi(pointIdx+1);
                                    k=(y2-y1)/(x2-x1);
                                    dd=minDistanceToRoad+layerWidth*(layer-1)+layerWidth;
                                    points(j,1)=x1+dd*k/sqrt(k*k+1);points(j,2)=y1-dd/sqrt(k*k+1);
                                    [dir(j),~] = cart2pol(x2-x1,y2-y1);
                                    dir(j) = dir(j) - pi/2;
                                    j=j+1;
                                end
                            end
                        end
                end
            otherwise
                disp('unsupported position, only [rightshoulder, leftshoulder] are supported now');
        end
        all_points=[all_points;points];
        all_dirs=[all_dirs;dir(:)];
    else
        fprintf("Empty lane? \n");
    end

end

dir=reshape(all_dirs,[length(all_dirs),1]);
points=all_points;
%%
%find z label from obj file
geometryOBJ = obj.road.geometryOBJ;
face_IDs = zeros(size(points,1),1);points(:,3)=0;

rot = zeros(size(dir));

cal_vns = zeros(size(points,1),3);
if ~isempty(geometryOBJ)
    dirs=[sin(dir),cos(dir)];dirs(:,3)=0;
    for j=1:size(points,1)

        face_IDs(j) = find_face(points(j,:),geometryOBJ);
        face_ID = face_IDs(j);
        %Fist coordinate from the face
        geometryOBJ.v((geometryOBJ.f.v(face_ID,1)),:);
        % surface normal
        cal_vn = cross(geometryOBJ.v((geometryOBJ.f.v(face_ID,1)),:)-geometryOBJ.v((geometryOBJ.f.v(face_ID,2)),:),geometryOBJ.v((geometryOBJ.f.v(face_ID,1)),:)-geometryOBJ.v((geometryOBJ.f.v(face_ID,3)),:));
        cal_vns(j,:) = cal_vn;
        Z_point = roots([cal_vn(3),(points(j,1)-geometryOBJ.v((geometryOBJ.f.v(face_ID,1)),1))*cal_vn(1)+(points(j,2)-geometryOBJ.v((geometryOBJ.f.v(face_ID,1)),2))*cal_vn(2)-geometryOBJ.v((geometryOBJ.f.v(face_ID,1)),3)*cal_vn(3)]);
        points(j,3) = Z_point;

        Z_dir = -(dirs(j,1)*cal_vn(1)+dirs(j,2)*cal_vn(2))/cal_vn(3);
        dirs(j,3) = Z_dir;


        % cartesian to spherical
        cal_vnrot(1,1) = cart2pol(cal_vn(1,2),cal_vn(1,3));
        cal_vnrot(1,2) = cart2pol(cal_vn(1,1),cal_vn(1,3));
        cal_vnrot(1,3) = cart2pol(cal_vn(1,1),cal_vn(1,2));

        % convert vector to rotation
        %     rot(j,1) = cart2pol(dirs(j,2),dirs(j,3));
        %     rot(j,1) = pi/2 - cal_vnrot(1,2);
        %     rot(j,1) = pi/2 - cal_vnrot(1,1);
        %     rot(j,2) = pi/2 - cal_vnrot(1,2);
        % %     rot(j,3) = cart2pol(dirs(j,1), dirs(j,2))-pi/2;
        %     rot(j,3) = dir(j);
        rot(j,1) = cal_vnrot(1,1) - pi/2;
        if contains(laneType,'leftdriving') && strcmp(pos, 'onroad')
            rot(j,2) = cal_vnrot(1,2) - pi/2;
            rot(j,3) = pi + dir(j); % for car
        else
            rot(j,2) = pi/2 - cal_vnrot(1,2);
            rot(j,3) = dir(j);
        end
    end
else

    if contains(laneType,'leftdriving') && strcmp(pos, 'onroad')
        rot = dir + pi;
    else
        rot = dir;
    end

end
    function face_ID = find_face(point,geometryOBJ)
        face_ID = 0;
        for count = 1:length(geometryOBJ.f.v)
            tri_id = geometryOBJ.f.v(count,:);
            tri = [geometryOBJ.v(tri_id(1),:);geometryOBJ.v(tri_id(2),:);geometryOBJ.v(tri_id(3),:)];
            tri(:,3) = 0;
            intriangle = ifintriangle(point,tri);
            if intriangle ==1
                face_ID = count;
                %         disp('found a triangle');
                break;
            end
        end

        function y = ifintriangle(Points, Triangle)
            y=[];
            for m = 1:size(Points,1)
                P = Points(m,:);
                A = Triangle(1,:);B = Triangle(2,:);C = Triangle(3,:);
                y = [y,(cross_2(P-A,B-A)*cross_2(C-A,B-A)>0) & (cross_2(P-B,C-B)*cross_2(A-B,C-B)>0) & (cross_2(P-C,A-C)*cross_2(B-C,A-C)>0)];
            end

            function y = cross_2(x1,x2)
                y = x1(1)*x2(2)-x2(1)*x1(2);
            end
        end

    end

% pick specified number of positions and rotations
if size(points, 1) > 0
    randomIndices = randsample(size(points, 1), sumofpoints);
    points = points(randomIndices,:);
    rot = rot(randomIndices,:);
end
end


