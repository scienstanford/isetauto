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
destPath = fullfile(iaRootPath,'local',imageID);
if ~exist(destPath,'dir'), mkdir(destPath); end

% First the metadata
metaFolder = '/acorn/data/iset/isetauto/Ford/SceneMetadata';
src  = fullfile(metaFolder,[imageID,'.mat']);
ieSCP(user,host,src,destPath);
load(fullfile(destPath,[imageID,'.mat']),'sceneMeta');

% Now the four light group EXR files
lgt = {'headlights','streetlights','otherlights','skymap'};
destFile = cell(4,1);
for ll = 1:numel(lgt)
    thisFile = sprintf('%s_%s.exr',imageID,lgt{ll});
    srcFile  = fullfile(sceneMeta.datasetFolder,thisFile);
    destFile{ii} = fullfile(destPath,thisFile);
    ieSCP(user,host,srcFile,destFile{ii});
end

%% We have the files.  Make some images

parameters.fnumber = 1.7;
parameters.focallength = 4.38e-3;
parameters.nsides = 20;
 
% IMX353 sensor tends to make the saturated pixels pink.
parameters.sensormodel = 'ar0132at';
parameters.pixelsize = 1.4e-6;
parameters.analoggain = 1/5; % 3 times
parameters.exposuretime = 1/60;
 
sceneMeta = load(fullfile(metaFolder, [imageID, '.mat']));
 
scenes{1} = piEXR2ISET(fullfile(sceneMeta.sceneMeta.datasetFolder,[imageID,'_headlights.exr']));
scenes{2} = piEXR2ISET(fullfile(sceneMeta.sceneMeta.datasetFolder,[imageID,'_streetlights.exr']));
scenes{3} = piEXR2ISET(fullfile(sceneMeta.sceneMeta.datasetFolder,[imageID,'_otherlights.exr']));
scenes{4} = piEXR2ISET(fullfile(sceneMeta.sceneMeta.datasetFolder,[imageID,'_skymap.exr']));
 
wgts = [0.1, 0.1, 0.02, 0.01]; % night
% wgts = [0.01, 0.001, 0.005, 10];
 
scene = sceneAdd(scenes, wgts);
 
scene = piAIdenoise(scene);

%% We could convert the scene via wvf in various ways

% [aperture, params] = wvfAperture(wvf,'nsides',0,...
%     'dot mean',50, 'dot sd',20, 'dot opacity',0.5,'dot radius',5,...
%     'line mean',50, 'line sd', 20, 'line opacity',0.5,'linewidth',2);
oi = oiCreate;
oi = oiCompute(oi, scene);
oi = oiCrop(oi,'border');

%
ip = piRadiance2RGB(oi,'etime',1/30,'analoggain',1/10);

% sensor = sensorSet(sensor, 'pixel size', 4e-6);
% sensor = sensorSet(sensor, 'exposure time', 1/30);
% sensor = sensorCompute(sensor, oi);
% ip = ipCompute(ip, sensor);
 
ipWindow(ip)

%%