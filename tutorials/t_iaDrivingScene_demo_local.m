%% Automatically assemble an automotive scene and render locally
%
%    t_piDrivingScene_demo
%
% Dependencies
%    ISETAuto, ISET3d, ISETCam and scitran
%    Prefix: ia- means isetauto
%            pi- means pbrt2iset(iset3d)
%
% Description:
%   Generate driving scenes using the gcloud (kubernetes) methods.  The
%   scenes are built by sampling roads from the Flywheel database. To be
%   able to render locally, number of assets are reduced to be able to run
%   on a local computer (with less cores and memory).
%
% Author: Zhenyi Liu;
%
% See also
%   piSceneAuto, piSkymapAdd, gCloud

%%  Initialize ISETcam
ieInit;
% We need Docker
if ~piDockerExists, piDockerConfig; end

%%  Example scene creation
SceneParameter = ISETAuto_default_parameters;

prefGroupName = 'ISETAuto';
% rmpref(prefGroupName); % clean up
setpref(prefGroupName, 'local', true);
setpref(prefGroupName, 'assetdir', '/Volumes/SSDZhenyi/Ford Project/PBRT_assets');
%% Initialize the recipe for the type of driving conditions
%--------------------------------------------------------------------------
% This takes around 150 seconds the first time.  If you run it
% multiple times, it will be shorter. 
%--------------------------------------------------------------------------
sceneLists = {'city1','suburb','city2','city3','city4'};
roadLists = {'city_cross_4lanes_002','city_cross_6lanes_001','curve_6lanes_001','straight_2lanes_parking'};
for ss = 1:5
    for rr = 1:4
        SceneParameter.scene.sceneType = sceneLists{ss};
        SceneParameter.scene.roadType = roadLists{rr};
        tic
        [sceneR, sceneInfo] = iaSceneAuto(SceneParameter);
        toc
    end
end
%% Assign predefined automotive related materials to the scene
% assign
iaAutoMaterialGroupAssign(sceneR);  
%% remove some assets for faster rendering (to do)
% set distance filter
distanceRange = [30, 50]; % remove objects outside this range
%% Write the recipe for the scene we generated
piWrite(sceneR);

% If you want to see the file, use
%  edit(thisR.outputFile)
disp('*** Scene written');
%%
oi = piRender(sceneR);

%% Show the OI and some metadata

oiWindow(oi);

% Save a png of the OI, but after passing through a sensor
fname = fullfile(iaRootPath,'local',[oi.name,'.png']);
% piOI2ISET is a similar function, but frequently changed by Zhenyi for different experiments, 
% so this function is better for a tutorial.
img = piSensorImage(oi,'filename',fname,'pixel size',2.5);
%{
ieNewGraphWin
imagesc(ieObject.metadata.meshImage)
%}
