%% Automatically generate an automotive scene
%
%    t_piSceneAutoGeneration
%
% Description:
%   Illustrates the use of ISETCloud, ISET3d, ISETCam and Flywheel to
%   generate driving scenes.  This example works with the PBRT-V3
%   docker container (not V2).
%
% Author: ZL
%
% See also
%   piSceneAuto, piSkymapAdd, gCloud, SUMO

%{
% Example - let's make a small example to run, if possible.  Say two
cars, no buildings.  If we can make it run in 10 minutes,
that would be good.
%
%}

%% Initialize ISET and Docker
ieInit;
if ~piDockerExists, piDockerConfig; end
if ~mcGcloudExists, mcGcloudConfig; end

%% Open the Flywheel site
st = scitran('stanfordlabs');

%% Initialize your GCP cluster

tic
gcp = gCloud('configuration','cloudRendering-pbrtv3-central-standard-32cpu-120m-flywheel');

toc
gcp.renderDepth = 1;  % Create the depth map
gcp.renderMesh  = 1;  % Create the object mesh for subsequent use
gcp.targets     =[];  % clear job list

% Print out the gcp parameters for the user
str = gcp.configList;

%% Helpful for debugging
% clearvars -except gcp st thisR_scene

%%  Example scene creation
%
% This is where we pull down the assets from Flywheel and assemble
% them into an asset list.  That is managed in piSceneAuto
tic
sceneType = 'city3';
% roadType = 'cross';
% sceneType = 'highway';
% roadType = 'cross';
roadType = 'city_cross_4lanes_002';
% roadType = 'city_cross_6lanes_001';
% roadType = {'curve_6lanes_001',...
%     'straight_2lanes_parking',...
%     'city_cross_6lanes_001',...
%     'city_cross_6lanes_001_construct',...
%     'city_cross_4lanes_002'};

trafficflowDensity = 'medium';

% dayTime = 'cloudy';

% Choose a timestamp(1~360), which is the moment in the SUMO
% simulation that we record the data.  This could be fixed or random,
% and since SUMO runs
timestamp = 122;%,20,60,90;

% Normally we want only one scene per generation.
nScene = 1;
% Choose whether we want to enable cloudrender
cloudRender = 1;
% Return an array of render recipe according to given number of scenes.
% takes about 100 seconds
%
[thisR_scene,road] = piSceneAuto('sceneType',sceneType,...
    'roadType',roadType,...
    'trafficflowDensity',trafficflowDensity,...
    'timeStamp',timestamp,...
    'nScene',nScene,...
    'cloudRender',cloudRender,...
    'scitran',st);
toc


thisR_scene.metadata.sumo.trafficflowdensity = trafficflowDensity;
thisR_scene.metadata.sumo.timestamp          = timestamp;
%% Add a skymap and add SkymapFwInfor to fwList
% 11:30/14:30/16:30
dayTime = '16:30';
[thisR_scene,skymapfwInfo] = piSkymapAdd(thisR_scene,dayTime);
road.fwList = [road.fwList,' ',skymapfwInfo];
%% Render parameters
% This could be set by default, e.g.,

% Could look like this
%  autoRender = piAutoRenderParameters;
%  autoRender.x = y;
%
% Default is a relatively low samples/pixel (256).

xRes = 1920;
yRes = 1080;
pSamples = 1024;
thisR_scene.set('film resolution',[xRes yRes]);
thisR_scene.set('pixel samples',pSamples);
% thisR_scene.set('fov',45);
thisR_scene.film.diagonal.value=15;
thisR_scene.film.diagonal.type = 'float';
thisR_scene.integrator.maxdepth.value = 5;
thisR_scene.integrator.subtype = 'bdpt';
thisR_scene.sampler.subtype = 'sobol';
thisR_scene.integrator.lightsamplestrategy.type = 'string';
thisR_scene.integrator.lightsamplestrategy.value = 'spatial';

%%
% for ii = 1:35
% lensname = 'dgauss.22deg.6.0mm.dat';
lensname = 'wide.56deg.6.0mm.dat';
% lensname = 'fisheye.87deg.12.5mm.dat';
% thisR_scene.film.diagonal.value=15; % for fisheye
thisR_scene.camera = piCameraCreate('realistic','lensFile',lensname,'pbrtVersion',3);
% thisR_scene.camera = piCameraCreate('perspective','pbrtVersion',3);

%% Add a camera to one of the cars

% To place the camera, we find a car and place a camera at the front
% of the car.  We find the car using the trafficflow information.

load(fullfile(piRootPath,'local','trafficflow',sprintf('%s_%s_trafficflow.mat',road.name,trafficflowDensity)),'trafficflow');
thisTrafficflow = trafficflow(timestamp);
nextTrafficflow = trafficflow(timestamp+1);
%

CamOrientation =270;
camPos = {'left','right','front','rear'};
% camPos = camPos{randi(4,1)};
camPos = camPos{3};
[thisCar,from,to,ori] = piCamPlace('thistrafficflow',thisTrafficflow,...
    'CamOrientation',CamOrientation,...
    'thisR',thisR_scene,'camPos',camPos,'oriOffset',0);

from = [0;3;40];
to   = [0;1.9;150];
thisVelocity = 0 ;
ori = 270;
thisR_scene.lookAt.from = from;
thisR_scene.lookAt.to   = to;
thisR_scene.lookAt.up = [0;1;0];
% Will write a function to select a certain speed, now just manually check
% thisVelocity = thisCar.speed

%% give me z axis smaller than 110;

% thisR_scene = piMotionBlurEgo(thisR_scene,'nextTrafficflow',nextTrafficflow,...
%                                'thisCar',thisCar,...
%                                'fps',60);
thisR_scene.camera.shutteropen.type = 'float';
thisR_scene.camera.shutteropen.value = 0;
thisR_scene.camera.shutterclose.type = 'float';
thisR_scene.camera.shutterclose.value = 1/150;

%% Write out the scene into a PBRT file

if contains(sceneType,'city')
    outputDir = fullfile(piRootPath,'local',strrep(road.roadinfo.name,'city',sceneType));
    thisR_scene.inputFile = fullfile(outputDir,[strrep(road.roadinfo.name,'city',sceneType),'.pbrt']);
else
    outputDir = fullfile(piRootPath,'local',strcat(sceneType,'_',road.name));
    thisR_scene.inputFile = fullfile(outputDir,[strcat(sceneType,'_',road.name),'.pbrt']);
end

% We might use md5 to has the parameters and put them in the file
% name.
if ~exist(outputDir,'dir'), mkdir(outputDir); end
% filename = sprintf('%s_v%0.1f_f%0.2fo%0.2f_%i%i%i%i%i%0.0f.pbrt',...
%      sceneType,thisVelocity,thisR_scene.lookAt.from(3),ori,clock);
filename = sprintf('%s_%s_v%0.1f_f%0.2f%s_o%0.2f_%i%i%i%i%i%0.0f.pbrt',...
                            sceneType,dayTime,thisCar.speed,thisR_scene.lookAt.from(3),camPos,ori,clock);
thisR_scene.outputFile = fullfile(outputDir,filename);

% Do the writing
piWrite(thisR_scene,'creatematerials',true,...
    'overwriteresources',false,'lightsFlag',false,...
    'thistrafficflow',thisTrafficflow);

% Upload the information to Flywheel.
gcp.fwUploadPBRT(thisR_scene,'scitran',st,'road',road);

% Tell the gcp object about this target scene
addPBRTTarget(gcp,thisR_scene);
fprintf('Added one target.  Now %d current targets\n',length(gcp.targets));

% Describe the target to the user

gcp.targetsList;
%% save gcp.targets as a txt file so that I can read from gcp
filePath_record = '/Users/zhenyiliu/Google Drive (zhenyi27@stanford.edu)/rendering_record/';
DateString=strrep(strrep(strrep(datestr(datetime('now')),' ','_'),':','_'),'-','_');
save([filePath_record,'gcp',DateString,'.mat'],'gcp');
%% This invokes the PBRT-V3 docker image
gcp.render(); 
%% Monitor the processes on GCP

[podnames,result] = gcp.Podslist('print',false);
nPODS = length(result.items);
cnt  = 0;
time = 0;
while cnt < length(nPODS)
    cnt = podSucceeded(gcp);
    pause(60);
    time = time+1;
    fprintf('******Elapsed Time: %d mins****** \n',time);
end

%{
%  You can get a lot of information about the job this way
podname = gcp.Podslist
gcp.PodDescribe(podname{1})
 gcp.Podlog(podname{1});
%}

% Keep checking for the data, every 15 sec, and download it is there

%% Download files from Flywheel
disp('*** Data downloading...');
[oi]   = gcp.fwDownloadPBRT('scitran',st);
disp('*** Data downloaded');

%% Show the rendered image using ISETCam

% Some of the images have rendering artifiacts.  These are partially
% removed using piFireFliesRemove
%

for ii =1:length(oi)
    oi_corrected{ii} = piFireFliesRemove(oi{ii});
    ieAddObject(oi_corrected{ii}); 
    oiWindow;
    oiSet(oi_corrected{ii},'gamma',0.75);
%     oiSet(scene_corrected{ii},'gamma',0.85);
    pngFigure = oiGet(oi_corrected{ii},'rgb image');
    figure;
    imshow(pngFigure);
    % Get the class labels, depth map, bounding boxes for ground
    % truth. This usually takes about 15 secs
    tic
    scene_label{ii} = piSceneAnnotation(scene_mesh{ii},label{ii},st);toc
    [sceneFolder,sceneName]=fileparts(label{ii});
    sceneName = strrep(sceneName,'_mesh','');
    irradiancefile = fullfile(sceneFolder,[sceneName,'_ir.png']);
    imwrite(pngFigure,irradiancefile); % Save this scene file

    %% Visualization of the ground truth bounding boxes
    vcNewGraphWin;
    imshow(pngFigure);
    fds = fieldnames(scene_label{ii}.bbox2d);
    for kk = 4
    detections = scene_label{ii}.bbox2d.(fds{kk});
    r = rand; g = rand; b = rand;
    if r< 0.2 && g < 0.2 && b< 0.2
        r = 0.5; g = rand; b = rand;
    end
    for jj=1:length(detections)
        pos = [detections{jj}.bbox2d.xmin detections{jj}.bbox2d.ymin ...
            detections{jj}.bbox2d.xmax-detections{jj}.bbox2d.xmin ...
            detections{jj}.bbox2d.ymax-detections{jj}.bbox2d.ymin];

        rectangle('Position',pos,'EdgeColor',[r g b],'LineWidth',2);
        t=text(detections{jj}.bbox2d.xmin+2.5,detections{jj}.bbox2d.ymin-8,num2str(jj));
       %t=text(detections{jj}.bbox2d.xmin+2.5,detections{jj}.bbox2d.ymin-8,fds{kk});
        t.Color = [0 0 0];
        t.BackgroundColor = [r g b];
        t.FontSize = 15;
    end
    end
    drawnow;

end
sceneWindow;
truesize;

%% Remove all jobs.
% Anything still running is a stray that never completed.  We should
% say more.

% gcp.JobsRmAll();

%% END

