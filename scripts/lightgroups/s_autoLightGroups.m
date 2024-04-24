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
%
% See also

%% Download a light group

% The metadata and the rendered images
user = 'wandell';
host = 'orange.stanford.edu';

% Prepare the local directory
imageID = '1114091636';
% 1114091636 - People on street
% 1114011756 - Vans moving away, person
% 1113094429

lgt = {'headlights','streetlights','otherlights','skymap'};
destPath = fullfile(iaRootPath,'local',imageID);

%% Download the four light group EXR files and make them into scenes

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

%% Load up the scenes from the downloaded directory

scenes = cell(numel(lgt,1));
for ll = 1:numel(lgt)
    thisFile = sprintf('%s_%s.exr',imageID,lgt{ll});
    destFile = fullfile(destPath,thisFile);
    scenes{ll} = piEXR2ISET(destFile);
end

%% Combine the scenes

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

%%  Combine them into a merged radiance scene

wgts = [0.1, 0.1, 0.02, 0.001]; % night
scene = sceneAdd(scenes, wgts);
scene.metadata.wgts = wgts;
scene = piAIdenoise(scene);
sceneWindow(scene);
scene = sceneSet(scene,'render flag','hdr');
scene = sceneSet(scene,'gamma',2.1);

%{
 lum = sceneGet(scene,'luminance');
 ieNewGraphWin; mesh(log10(lum));
%}
%% We could convert the scene via wvf in various ways

wvf = wvfCreate;
[aperture, params] = wvfAperture(wvf,'nsides',3,...
    'dot mean',50, 'dot sd',20, 'dot opacity',0.5,'dot radius',5,...
    'line mean',50, 'line sd', 20, 'line opacity',0.5,'linewidth',2);

oi = oiCreate('wvf');
oi = oiCompute(oi, scene,'aperture',aperture,'crop',true);
% oiWindow(oi);

%
[ip, sensor] = piRadiance2RGB(oi,'etime',1/30,'analoggain',1/10);
% sensor = sensorSet(sensor, 'pixel size', 4e-6);
% sensor = sensorSet(sensor, 'exposure time', 1/30);
% sensor = sensorCompute(sensor, oi);
% ip = ipCompute(ip, sensor);
 
ipWindow(ip);


%%
sensor = sensorSet(sensor,'noiseFlag',0);
sensor = sensorSet(sensor,'name','noise free');
sensor = sensorCompute(sensor,oi);
ip = ipCompute(ip,sensor);
ipWindow(ip);

%%  The RGB filters differ a lot and thus the rendering differs

sensor2 = sensorCreate('rgbw');
sensor2 = sensorSet(sensor2,'match oi',oi);
sensor2 = sensorSet(sensor2,'name','rgbw');

% Match the color filters
%{
% I do not understand why, but when I do this the transformation gets
% way off.
F = sensorGet(sensor,'filter transmissivities');
F2 = sensorGet(sensor2,'filter transmissivities');
F2(:,1:3) = F(:,1:3)*1;
wave = sensorGet(sensor,'wave');
ir = ieReadSpectra('infrared2',wave);
F2 = diag(ir)*F2;

sensor2 = sensorSet(sensor2,'filter spectra',F2);
sensorPlot(sensor2,'spectral qe')

% Try tracking this through.  
T = ieColorTransform(sensor2,'XYZ','D65','mcc');
%}

sensor2 = sensorSet(sensor2,'exp time',16*1e-3);
sensor2 = sensorCompute(sensor2,oi);
% sensorWindow(sensor2);

ip = ipCompute(ip,sensor2);
%{
tList = ipGet(ip,'each transform');
tList{1}
tList{2}
tList{3}
cTrans = ipGet(ip,'combined transform')

% We want D65 times the sensors times this to be 1,1,1
% Not that close.
wave = sensorGet(sensor2,'wave');
d65 = ieReadSpectra('D65',wave);
spectralQE = sensorGet(sensor2,'spectral qe');
d65'*spectralQE*cTrans

%}
ipWindow(ip);

%%