function parameter = ISETAuto_default_parameters
%% ISETAuto Parameters
parameter = struct();

parameter.general.outputName      = 'sceneAuto_demo';
parameter.general.outputDirecotry = fullfile(iaRootPath, 'local','sceneAuto_demo');
parameter.general.option          = 'all';% options include sumo/suso/all
%% scene
% Available sceneTypes: city1, city2, city3, city4, citymix, suburb
parameter.scene.sceneType          = 'suburb';
% To see the available roadTypes use iaRoadTypes
parameter.scene.roadType           = 'city_cross_4lanes_002';
parameter.scene.treeDensity        = 'random';
parameter.scene.trafficflowDensity = 'low'; % Available trafficflowDensity: low, medium, high
% Choose a timestamp(1~360), which is the moment in the SUMO
% simulation we will use.
parameter.scene.timestamp          = 100;
parameter.scene.skymapTime         = '16:30';  
parameter.scene.susoplaced         = [];
parameter.scene.sumoplaced         = [];
parameter.scene.roadRecipe         = [];
% The time of day of the sky
parameter.scene.skyMap.time        = '16:30';
parameter.scene.skyMap.rotation    = [-90, 45, 0]; % [rotx, roty, rotz]
parameter.scene.showbirdview       = true; % the birdview figure is plotted and saved.
%% camera
parameter.camera.type         = 'omni';
parameter.camera.lensname     = 'wide.56deg.6.0mm.json';
parameter.camera.lookAt.from  = [0;3;40];   % X,Y,Z world coordinates
parameter.camera.lookAt.to    = [0;1.9;150];% Where the camera is pointing in the scene
parameter.camera.lookAt.up    = [0;1;0]; 
parameter.camera.filmdiagonal = 10;
parameter.camera.aperture     = 1;
parameter.camera.exposureTime = 1/200; % for motion blur
%% render
% Set the rendering and film resolution properties in the recipe.
% Here are some suggestions about time and quality.
%
%   High quality parameters
%       film resolution:  [1280 720]
%       pixel samples:    2048
%       film diagonal:    10 (mm)
%       nbounces:         10    (indoor scenes use 50, or even more)
%       aperture:         1 (mm)
%
%  Fast low quality - mainly reduced the number of pixel samples.
%       film resolution   [1280 720]
%       pixel samples     64
%       film diagonal     10
%       nbounces          10
%       aperture          1
parameter.render.filmresolution = [1280 720];
parameter.render.pixelsamples   = 16;
parameter.render.nbounces       = 10;
%%
%% write out the default parameter json file:
filename = fullfile(iaRootPath,'utility/simulation_settings/sceneAuto_default_Parameters.json');
jsonwrite(filename,parameter);
disp('*** scene paramters are generated.')
end