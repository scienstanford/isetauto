%% ISETAuto script
%
% Related to the Ford grant
%
% This script reads a group of simulated scenes from the data stored
% on acorn. The group separates the scene into four components, each
% with a different light (headlights, streetlights, other lights,
% skymap).  We call this representation the light gruop.
%
% This is the folder on acron contaning the scene groups
%   metaFolder = '/acorn/data/iset/isetauto/Ford/SceneMetadata';
%
% See also

%%
ieInit;

%% Download a light group

% The metadata and the rendered images
user = 'wandell';
host = 'orange.stanford.edu';

% Prepare the local directory
imageID = '1113040557';
% 1114034742 - Motorcyle, people walking not very nice
% 1114091636 - People on street
% 1114011756 - Vans moving away, person
% 1113094429 - Truck and nice late afternoon
% 1112201236 - Open highway scene
% 1113042919 - Blue car, person, motorcyle, yellow bus
% 1112213036 - Lousy.
% 1113040557 - Lousy.  Truck and people

lgt = {'headlights','streetlights','otherlights','skymap'};
destPath = fullfile(iaRootPath,'local',imageID);

%% Download the four light group EXR files and make them into scenes
%{
if ~exist(destPath,'dir'), mkdir(destPath); end

% First the metadata
metaFolder = '/acorn/data/iset/isetauto/Ford/SceneMetadata';
src  = fullfile(metaFolder,[imageID,'.mat']);
ieSCP(user,host,src,destPath);
load(fullfile(destPath,[imageID,'.mat']),'sceneMeta');

% The the radiance EXR files
for ll = 1:numel(lgt)
    thisFile = sprintf('%s_%s.exr',imageID,lgt{ll});
    srcFile  = fullfile(sceneMeta.datasetFolder,thisFile);
    destFile = fullfile(destPath,thisFile);
    ieSCP(user,host,srcFile,destFile);
end
%}

%% Load up the scenes from the downloaded directory

scenes = cell(numel(lgt,1));
for ll = 1:numel(lgt)
    thisFile = sprintf('%s_%s.exr',imageID,lgt{ll});
    destFile = fullfile(destPath,thisFile);
    scenes{ll} = piEXR2ISET(destFile);
end

%% Combine the scenes

%{
%% Just show the point lights
wgts = [1 1 1 0];
scene = sceneAdd(scenes, wgts);
scene = piAIdenoise(scene);
sceneWindow(scene);

%% Just the headlights
wgts = [1 0 0 0];
scene = sceneAdd(scenes, wgts);
scene.metadata.wgts = wgts;
scene = piAIdenoise(scene);
sceneWindow(scene);

%% Just the skymap
wgts = [0 0 0 1];
scene = sceneAdd(scenes, wgts);
scene.metadata.wgts = wgts;
scene = piAIdenoise(scene);
sceneWindow(scene);
%}

%% Just the skymap
%{
wgts = [0 0 0 1];
scene = sceneAdd(scenes, wgts);
scene.metadata.wgts = wgts;
scene = piAIdenoise(scene);
sceneWindow(scene);
%}


%%  Combine them into a merged radiance scene
% head, street, other, sky
% wgts = [0.1, 0.1, 0.02, 0.001]; % night
wgts = [0.02, 0.1, 0.02, 0.00001]; % night
scene = sceneAdd(scenes, wgts);
scene.metadata.wgts = wgts;

%% Denoise and show
scene = piAIdenoise(scene);
sceneWindow(scene);

scene = sceneSet(scene,'render flag','hdr');
scene = sceneSet(scene,'gamma',1);

%{
 lum = sceneGet(scene,'luminance');
 ieNewGraphWin; mesh(log10(lum));
%}

%% If you want, crop out the headlight region of the scene for testing
%
% You can do this in the window, get the scene, and find the crop
%
% sceneHeadlight = ieGetObject('scene'); 
%
% TODO:  Add crop to the scene window pull down.
%
switch imageID
    case '1114011756'
        % Focused on the person
        rect = [659   349   934   487];  % 1114011756
        thisScene = sceneCrop(scene,rect);
    case '1114091636'
        % This is an example crop for the headlights on the green car.
        rect = [270   351   533   528];  % 1114091636
        thisScene = sceneCrop(scene,rect);
    otherwise
        error('Unknown imageID')
end

sceneWindow(thisScene);

%% We could convert the scene via wvf in various ways

[oi,wvf] = oiCreate('wvf');
[aperture, params] = wvfAperture(wvf,'nsides',3,...
    'dot mean',50, 'dot sd',20, 'dot opacity',0.5,'dot radius',5,...
    'line mean',50, 'line sd', 20, 'line opacity',0.5,'linewidth',2);

oi = oiCompute(oi, thisScene,'aperture',aperture,'crop',true);
%{
oiWindow(oi);
oi = oiSet(oi,'render flag','hdr');
oi = oiSet(oi,'gamma',1);
%}

%%  Create the ip and the default ISETAuto sensor

[ip, sensor] = piRadiance2RGB(oi,'etime',1/30,'analoggain',1/10,'quantization','12bit');
ipWindow(ip);

%% Turn off the noise and recompute

sensor = sensorSet(sensor,'noiseFlag',0);
sensor = sensorSet(sensor,'name','noise free');
sensor = sensorCompute(sensor,oi);
ip = ipCompute(ip,sensor);
ipWindow(ip);

%%  Use the RGBW sensor

sensorRGBW = sensorCreate('rgbw');
sensorRGBW = sensorSet(sensorRGBW,'match oi',oi);
sensorRGBW = sensorSet(sensorRGBW,'name','rgbw');

%{
qe = sensorGet(sensorRGBW,'spectral qe');
cond(qe)
%}

expDuration = [1/15, 1/30, 1/60];
for dd = 1:numel(expDuration)
    sensorRGBW = sensorSet(sensorRGBW,'exp time',expDuration(dd));
    sensorRGBW = sensorCompute(sensorRGBW,oi);
    ip = ipCompute(ip,sensorRGBW);  % It would be nice to not have to run the whole thing
    ip = ipSet(ip,'transform method','adaptive');
    ip = ipSet(ip,'demosaic method','bilinear');
    illE = sceneGet(scene,'illuminant energy');
    ip = ipSet(ip,'render whitept',illE, sensorRGBW);
    ip = ipCompute(ip,sensorRGBW);
    ip = ipSet(ip,'name',sprintf('RGBW-%.3f',expDuration(dd)));
    ipWindow(ip);
end

%%