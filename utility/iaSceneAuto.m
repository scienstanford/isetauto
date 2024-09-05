function [sceneR,sceneInfo] = iaSceneAuto(parameter)
% Generate scene(s) for Autonomous driving scenarios using SUMO/SUSO
%
% Syntax
%    [sceneR,sceneInfo] = iaSceneAuto(parameter)
%
% Description
%  Assembles assets from Flywheel and SUMO into a city or suburban street
%  scene.
%
% Inputs
%   parameter - struct contaning the possible parameters below
%
% Optional key/value pairs
%   scene type     - 'city' or 'suburban'
%   road type      - See piRoadTypes
%   traffice flow density -  Traffic density (Default 'medium')
%   time stamp (Default: 50) - Ticks in the SUMO simulation.  Integer
%   scitran        - Flywheel interface object (Default is 'stanfordlabs')
%   tree density   - Not currently used
%
% Returns:
%  sceneR     - Scene recipe
%  sceneInfo  - A struct containing the list of Flywheel objects and road
%               information. To list this use road.fwList;
%
% Requires:  scitran
%
% Author:
%   Zhenyi Liu
%   Update: Zhenyi, 2021
%
% See also
%   piRoadTypes, t_piDrivingScene_demo
%

disp('*** Scene Generation...')
%% Read input parameters
sceneType          = parameter.scene.sceneType;
treeDensity        = parameter.scene.treeDensity;  % Not yet used
roadType           = parameter.scene.roadType;
trafficflowDensity = parameter.scene.trafficflowDensity;
timestamp          = parameter.scene.timestamp;
skymapTime         = parameter.scene.skymapTime;
showbirdview       = parameter.scene.showbirdview;

if ~exist(parameter.general.outputDirecotry, 'dir')
    mkdir(parameter.general.outputDirecotry);
end
%% Flywheel init
if ~getpref('ISETAuto','local')
    st = scitran('stanfordlabs');
else
    st = [];
end

%% Read a road from Flywheel that we will use with SUMO and SUSO
[sceneInfo,sceneR] = iaRoadCreate('roadtype',roadType,...
                                  'trafficflowDensity',trafficflowDensity,...
                                  'sceneType',sceneType,...
                                  'scitran',st);
disp('--> Base road is created')
%% Read a local traffic flow if available
% Find the proper trafficflow file from data folder 
tfDataPath   = fullfile(iaRootPath,'data','sumo_input','demo',...
    'trafficflow',sprintf('%s_%s_trafficflow.mat',roadType,trafficflowDensity));

localTF = fullfile(iaRootPath,'local','trafficflow');

% Copy the file to a local directory
if ~exist(localTF,'dir'), mkdir(localTF);end
copyfile(tfDataPath, localTF);
load(tfDataPath, 'trafficflow');
%{
% This is where SUMO is called, or the local file is read
tfPath   = fullfile(iaRootPath,'local',...
    'trafficflow', sprintf('%s_%s_trafficflow.mat', roadType, trafficflowDensity));
trafficflowFolder = fileparts(tfPath);

if ~exist(trafficflowFolder,'dir'), mkdir(trafficflowFolder); end

if ~exist(tfPath,'file')
    trafficflow = piTrafficflowGeneration(sceneInfo);
    save(tfPath, 'trafficflow');
    disp('-----> Traffic flow using SUMO is generated.')
elseif isempty(trafficflow)
    load(tfPath,'trafficflow');
    disp('-----> Local file of traffic flow is loaded.')
end
%}
disp('--> Traffic flow is generated')

%% SUSO Simulation of urban static objects
% Put stationary assets into the city or suburban street
if isempty(parameter.scene.susoplaced)
    disp('--> SUSO is planning...')
    
    tree_interval = rand(1)*4+2;
    if piContains(sceneType,'city')|| piContains(sceneType,'suburb')
        
        %% place objects on sidewalk,e.g. street lights, trees,etc.
        susoPlaced = iaSidewalkPlan(sceneInfo,st,trafficflow(timestamp),...
            'tree_interval',tree_interval);
        
        %% place parked cars
        parallelParking = false;
        if piContains(roadType,'parking')
            trafficflow = iaParkingPlace(sceneInfo, trafficflow,...
                'parallelParking', parallelParking);
        end
        
        %% place buildings
        
        [buildingPosList, building_list] = iaBuildingPosList(sceneType, sceneR, showbirdview, st);
        susoPlaced.building = iaSUSOPlace(building_list, buildingPosList);
        
        disp('--> SUSO Assets are placed on the road.');
    else
        disp('No SUSO assets placed.  Not city or suburb');
    end
    parameter.scene.susoplaced = susoPlaced;
    save(([iaRootPath,'/data/suso/',...
        parameter.scene.sceneType,'_',parameter.scene.roadType,'.mat']),'parameter');
    return; % tmp
else
    susoPlaced =parameter.scene.susoplaced;
end
% Add objects to scene
sceneR = iaObjectsAssemble(sceneR, susoPlaced);
%% Place vehicles/pedestrians from  SUMO traffic flow data on the road
% Put the suso placed assets on the road
if isempty(parameter.scene.sumoplaced)
    disp('--> SUMO is planning...')
    % [sumoPlaced, ~] = iaSUMOPlace(trafficflow,...
    %     'timestamp',timestamp,...
    %     'scitran',st);
    [sumoPlaced, ~] = iaSUMOAssemble(trafficflow,...
        'timestamp',timestamp);
    parameter.scene.sumoplaced = sumoPlaced;
else
    sumoPlaced = parameter.scene.sumoplaced;
end
% Add objects to scene
% sceneR = iaObjectsAssemble(sceneR, sumoPlaced);

sceneR.set('traffic flow density',trafficflowDensity);
sceneR.set('traffic timestamp',timestamp);
disp('--> Completed SUMO combined with SUSO');

%% Add skymap
% We will put a skymap in the local directory so people without
% Flywheel can see the output

[acqID, skyname] = piFWSkymapAdd(skymapTime, st);

% Add a light to the merged scene

% Delete any lights that happened to be there
sceneR   = piLightDelete(sceneR, 'all');

rotation = piRotationMatrix('y', 45, 'x', -90);

skymap   = piLightCreate('new skymap', ...
                       'type', 'infinite',...
                       'string mapname', skyname,...
                       'rotation',rotation);

% Add a light to the scene
sceneR.set('light', 'add', skymap);

skymapfwInfo = [acqID,' ',skyname];

% Add flywheel info
disp('--> Skymap added')

%% Camera render parameters
% The camera lenses are stored in data/lens
lensname      = parameter.camera.lensname;
switch parameter.camera.type
    case 'omni'
        sceneR.camera = piCameraCreate('omni','lens file',lensname);
        sceneR.set('aperture',parameter.camera.aperture);
        sceneR.set('film diagonal',parameter.camera.filmdiagonal);
    case 'pinhole'
        sceneR.camera = piCameraCreate('pinhole');
end
%
sceneR.set('film resolution',parameter.render.filmresolution);
sceneR.set('pixel samples',parameter.render.pixelsamples);   % 1024 or higher to reduce graphics noise
sceneR.set('nbounces',parameter.render.nbounces);

disp('--> Camera is created')

%% Place the camera in the scene

% To place the camera, we find a car and place the camera at the front
% of the car.  We find the car using the trafficflow information.
%{
% Choose the time stamp
thisTrafficflow    = trafficflow(timestamp);

% See end of script for how to assign the camera to a random car.
camPos             = 'front';               % Position of the camera on the car
cameraVelocity     = 0 ;            % Camera velocity (meters/sec)
CamOrientation     = 270;  
 %}
% Starts at x-axis.  -90 (or 270) to the z axis.
sceneR.lookAt = parameter.camera.lookAt;  
% To use: piCamPlace
sceneR.set('exposure time', parameter.camera.exposureTime);
disp('--> Camera is positioned')
%% 
if showbirdview
    curDir = pwd;
    cd(parameter.general.outputDirecotry)
    % show bird view of placed objects
    iaSceneAutoShow(sceneR);
    cd(curDir);
end

%% Add flywheel info
% Add suso placed                    
sceneInfo = fwInfoAppend(sceneInfo, susoPlaced);
% Add suso placed  
sceneInfo = fwInfoAppend(sceneInfo, sumoPlaced);
% Add suso skymap  
sceneInfo.fwList = [sceneInfo.fwList,' ',skymapfwInfo];

%% Save this simulation
datastring  = datestr(now,30);
simulationParamters_path = fullfile(parameter.general.outputDirecotry, ...
    strcat(parameter.general.outputName,'_',datastring,'.mat'));
save(simulationParamters_path, 'parameter');
%% Set the file names for input and output
if piContains(sceneType,'city')
    outputDir = fullfile(iaRootPath,'local',strrep(sceneInfo.roadinfo.name,'city',sceneType));
    sceneR.inputFile = fullfile(outputDir,[strrep(sceneInfo.roadinfo.name,'city',sceneType),'.pbrt']);
else
    outputDir = fullfile(iaRootPath,'local',strcat(sceneType,'_',sceneInfo.name));
    sceneR.inputFile = fullfile(outputDir,[strcat(sceneType,'_',sceneInfo.name),'.pbrt']);
end

if ~exist(outputDir,'dir'), mkdir(outputDir); end

parameter.general.outputName = strcat(parameter.general.outputName,'_',datastring,'.pbrt');

sceneR.set('outputFile', fullfile(parameter.general.outputDirecotry, parameter.general.outputName));
%%
disp('*** Driving scene is generated.')
end

%--------------------------------------------------------------------------
%% List the selected fwInfo str with road.fwList
function sceneInfo = fwInfoAppend(sceneInfo,assets)

assetFields = fieldnames(assets);
for jj = 1:length(assetFields)
    for kk = 1: length(assets.(assetFields{jj}))
        sceneInfo.fwList = [sceneInfo.fwList,' ',assets.(assetFields{jj})(kk).fwInfo];
    end
end
end




