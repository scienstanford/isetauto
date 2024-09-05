function [road,assetRecipe] = iaRoadCreate(varargin)
% Generate a roadtype struct for Sumo TrafficFlow generation
%
% Syntax
%
% Brief description
%
% Input
%  N/A
% Key/value pairs
%  roadtype - See piRoadTypes
%  sceneType
%  trafficflowDensity - low or high
%  sessions
%  scitran
%  cloudRender
%
% Zhenyi, 2018
% Update: Zhenyi, 2021

%%

% varargin = ieParamFormat(varargin);

p = inputParser;

p.addParameter('roadtype','city_cross_4lanes_002');
p.addParameter('sceneType','city');
p.addParameter('trafficflowDensity','medium');
p.addParameter('scitran',[]);
p.parse(varargin{:});


sceneType    = p.Results.sceneType;
trafficflowDensity = p.Results.trafficflowDensity;
roadtype        = p.Results.roadtype;
st = p.Results.scitran;

if isempty(st) && ~getpref('ISETAuto','local'), st = scitran('stanfordlabs'); end

%% generate road information
iaRoadInfo;

% load it
load(fullfile(piRootPath,'local','configuration','roadInfo.mat'),'roadinfo');
%%
vTypes={'pedestrian','passenger','bus','truck','bicycle'};

switch sceneType
    case {'city','city2','city1','city3','city4','citymix'}
        sceneType_tmp = 'city';
        interval=[0.1,0.5,0.05,0.05,0.05];
        %         if piContains(roadtype,'cross')
        %             roadname = sprintf('%s_%s_%dlanes',sceneType_tmp,roadtype,road.nlanes);
        %         else
        %         end
    case {'suburb'}
        sceneType_tmp = sceneType;
        interval=[0.05,0.1,0.01,0.01,0.03];
        %     case'residential'
        %         road.nlanes = 2;
        %         interval=[0.6,0.4,0.02,0.01,0.05];
        %     case 'highway'
        %         sceneType_tmp = sceneType;
        %         if randm ==1,road.nlanes = 6;else, road.nlanes = 8;end
        %         interval=[0,0.9,0.1,0.5,0];
        %         roadname = roadtype;
        %     case 'bridge'
        %         sceneType_tmp = sceneType;
        %         if randm ==1,road.nlanes = 6;else, road.nlanes = 8;end
        %         interval=[0,0.9,0.1,0.5,0];
        %         roadname = sceneType;
end

%% Check the road type and download road assets

if ispref('ISETAuto') && ~getpref('ISETAuto','local')
    % Lookup the session with the road information
    roadSession = st.fw.lookup('wandell/Graphics auto/assets/road');

    Road_acq = roadSession.acquisitions.findOne(sprintf('label=%s',roadtype));
    % get recipe
    assetRecipe = piFWAssetCreate(Road_acq, 'resources', false);
    %% include "others" data
    % others data include basic data which will be used for rendering
    % e.g. lens file, spd files

    data_acq = st.fw.lookup('wandell/Graphics auto/assets/data/others');
    thisResource = stFileSelect(Road_acq.files,'type','CG Resource');
    road.fwList = [data_acq.id,' ','data.zip',' ',...
        Road_acq.id,' ',...
        thisResource{1}.name];
else
    tmp = load(fullfile(getpref('ISETAuto','assetdir'),'road/sumo',roadtype,[roadtype,'.recipe.mat']));
    assetRecipe = tmp.thisR; clear tmp;
end

for ii = 1: length(roadinfo)
    if piContains(roadtype,'construct') % will change name from ***_construct_001 to ***_001_construct
        roadname=strrep(roadtype,'_construct','');
    else
        roadname = roadtype;
    end
    road.name = roadtype;
    if strcmp(roadinfo(ii).name,roadname)
        road.roadinfo =  roadinfo(ii);
        break;
    end
end

% Set the temporal sampling interval for the SUMO simulation.
switch trafficflowDensity
    case 'low'
        interval=interval*0.5;
    case 'high'
        interval=interval*1.5;
    otherwise
end
% Map key/value pairs
road.vTypes=containers.Map(vTypes,interval);
end


