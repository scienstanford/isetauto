%% Automatically assemble a daytime city road scene
%
% Dependencies
%   ISET3d, ISETAuto, ISETonline, and ISETCam
%   Prefix:  ia- means isetauto
%            pi- means iset3d-v4
%
%   ISET3d: Takes a PBRT file, parses 3D information including lights,
%   materials, textures and meshes. Modify the properties and render it.
%
%   ISETAuto: Assembles an ISET3d OBJECT into a complex driving scene.
%
%   ISETCam: Converts scene radiance or optical irradiance data to an RGB
%   image with a physically based sensor model and ISP pipeline. The 
%   resulting image is then rendered as an sRGB approximation.
%
%   ISETOnline:  Looks up the road data using the database.
%
% Zhenyi, 2024

%% Initialize ISET and Docker
ieInit; clear all
if ~piDockerExists, piDockerConfig; end

%% (Optional) isetdb() setup
% setup stanford server (n.b. ideally in user startup file)
% setpref('db','server','acorn.stanford.edu'); 
% setpref('db','port',49153);
% 
% % Opens a connection to the server
% sceneDB = isetdb();
scenetype = 'city2';
roadtype = 'city_cross_4lanes_002';

SceneParameter = ISETAuto_default_parameters;
SceneParameter.scene.sceneType = scenetype;
SceneParameter.scene.roadType = roadtype;

tic
[sceneR, sceneInfo] = iaSceneAuto(SceneParameter);
toc

assetDir = '/Volumes/SSDZhenyi/Ford Project/PBRT_assets';addpath(genpath(assetDir));
tmp = load(fullfile(assetDir,'road','sumo',roadtype,[roadtype,'.recipe.mat']));
roadRecipe = tmp.thisR;

roadData = roadgen('road directory',[scenetype,'_',roadtype],...
    'road recipe',roadRecipe,...
    'asset directory', assetDir);

roadData.set('onroad car names',{'car_001','car_002','car_003','car_058'});% 

roadData.set('offroad tree names', {'tree_001','tree_002','tree_003'});

roadData.set('offroad n trees', [50, 1, 1]);

% the roadData object comes with a base ISET3d recipe for rendering
thisR = roadData.recipe;

thisR.set('outputfile',fullfile(piDirGet('local'),'daytime_demo/daytime_demo.pbrt'));

%% Now we can assemble the scene using ISET3d methods
assemble_tic = tic(); % to time scene assembly
% remove bikerack
roadData.road.scene.susoplaced = rmfield(roadData.road.scene.susoplaced,'bikerack');
roadData.road.scene.timestamp = 80;

% fieldnames(roadData.road.scene.susoplaced)
% susoplaced = roadData.road.scene.susoplaced;
% roadData.road.scene.susoplaced = [];
% % Debug
% roadData.road.scene.susoplaced.building = susoplaced.building;

roadData.assemble();
fprintf('---> Scene assembled in %.f seconds.\n',toc(assemble_tic));

% TBD: Add scene visualization
% sceneData.rrDraw('points',points, 'dir',dirs); % visualization function is to fix

%% Optionally specify a lens for our camera
% lensfile  = 'wide.40deg.6.0mm.json';    % 30 38 18 10
% fprintf('Using lens: %s\n',lensfile);

% We can randomly pick a car, and place the camera on it.  
% These are the types of cameras so far:
%
%   'front', 'back', 'left, 'right'
camera_type = 'front';

%% For this demo we'll actually set our camera to be on an F150
%  later in the script, so we don't set camera properties here
% branchID = roadData.cameraSet('camera type', camera_type); 
% direction = thisR.get('object direction');
% thisR.set('object distance', 0.95);

%% Set the recipe parameters
%  We want to render both the scene radiance and a depth map
thisR.set('film render type',{'radiance','depth'});

% Set the render quality parameters
% For publication 1080p by as many as 4096 rays per pixel are used
thisR.set('film resolution',[1920 1080]/2); % Divide by 4 for speed
thisR.set('pixel samples',64);            % 256 for speed
thisR.set('max depth',5);                  % Number of bounces
thisR.set('sampler subtype','pmj02bn');    
thisR.set('fov',60);                       % Field of View

%% For camera placement simulation we want a specific model of car
%  so that we know the actual dimensions

% In this case we look for a Ford F150 (car_058) in the scene
% NOTE: If there is no F150, you may need to generate a new scene
branchID = roadData.cameraSet('camera type', camera_type,...
                                'car name','car_001'); 

% Set up the rendering skymap -- this is just one of many available
skymapPath = '/Users/zhenyi/git_repo/dev/iset3d/data/skymaps/sky-noon_009.exr'; % Most skymaps are in the Matlab path already
thisR.set('skymap',skymapPath);

% skymapName = fileparts(skymapPath);
% skymapNode = strrep(fileparts(skymapName), '.exr','_L');

thisR.set('light','sky-noon_009', 'specscale', 0.001);
%% Render the scene, and maybe an OI (Optical Image through the lens)
% thisR.set('object distance', 0.95);
% scene = piWRS(thisR,'render flag','hdr');

% piWrite(thisR);
% 
% scene = piRender(thisR, 'docker',isetdocker);
% sceneWindow(scene);

recipeList = iaLightsGroup(thisR, 'sky-noon_009');
recipeList{1}.lookAt.from = [10 50 120];
recipeList{1}.lookAt.to = [-20 1.5 120];
recipeList{1}.lookAt.up = [0 1 0];
recipeList{1}.lights = [];
piWrite(recipeList{1});

% setpref('ISETDocker','device','gpu');
scene = piRender(recipeList{1}, 'docker',isetdocker);
sceneWindow(scene);



%% Process the scene through a sensor to the ip 
%
% This isn't great because the sensor is not explicit.
ip = piRadiance2RGB(scene,'etime',1/300,'analoggain',1/5);

rgb = ipGet(ip, 'srgb');
ieNewGraphWin;
imshow(rgb);

%% Re-render the scene with a modified pitch angle for the camera 

% Unclear why this would change thisR.  But it does. 
branchID = roadData.cameraSet('camera type', camera_type,...
                                'car name','car_058',...
                                'branch ID',branchID,...
                                'cam rotation',piRotationMatrix( 'zrot',-90,'yrot',0,'xrot',88)); 

% direction = thisR.get('object direction');
scene = piWRS(thisR,'render flag','hdr');

%piWrite(thisR);
%scene = piRender(thisR);
%sceneWindow(scene);

%% Calculate the camera's response, currently with a fixed exposure
% time of 1/30s.
ip = piRadiance2RGB(scene,'etime',1/30,'analoggain',1/5);

rgb = ipGet(ip, 'srgb');
ieNewGraphWin;
imshow(rgb);

% Now get an sRGB approximation of the resulting image and show it
% rgb = ipGet(ip, 'srgb');figure;imshow(rgb);

%% We can also move the camera to the front grille
%
% The front grille position can be found in blender file
branchID = roadData.cameraSet('camera type', camera_type,...
                                'car name','car_058',...
                                'branch ID',branchID,...
                                'cam position', [0.87955; 0; 1.0298]); 

scene = piWRS(thisR,'render flag','hdr','name','Front grille');

%% Convert scene through oi and sensor to ip

ip = piRadiance2RGB(scene,'etime',1/30,'analoggain',1/5);
rgb = ipGet(ip, 'srgb');
ieNewGraphWin; imshow(rgb); 
title('Front Grille');

%% Compare with a simulated fisheye lens
thisR.camera = piCameraCreate('omni','lensfile','fisheye.87deg.3.0mm.json');
oi = piWRS(thisR,'render flag','hdr');

% piWrite(thisR);
% oi = piRender(thisR);
% oiWindow(oi);

ip = piRadiance2RGB(oi,'etime',1/100,'analoggain',1);
rgb = ipGet(ip, 'srgb');
ieNewGraphWin; imshow(rgb); 
title('fisheye');

% fprintf("This is probably where the current demo ends.\n");
% pause;

%% END
% 
% [objectslist,instanceMap] = piRenderLabel(thisR);
% OBJInfo = iaGetOBJInfo(thisR, scene, instanceMap.metadata);
% coord   = iaGet3DCoord(scene);
% 
% % convert this to world coordinates
% direction = thisR.get('object direction');
% 
% if direction(1)<0
%     world_pos =  thisR.lookAt.from(:) - coord(:);
% else
%     world_pos =  thisR.lookAt.from(:) + coord(:);
% end
% 
% [~,T1] = thisR.set('asset', OBJInfo.name, 'world position', world_pos);
% piWrite(thisR);
% scene = piRender(thisR);sceneWindow(scene);
%% create light group
% skyName = erase(skymapName,'.exr');
% recipeList = iaLightsGroup(thisR, skyName);
% %%
% for rr = 1:numel(recipeList)
%     piWrite(recipeList{rr});
%     scene_lg{rr} = piRender(recipeList{rr}, 'meanluminance',0);
% end
%{
 thisR.set('film resolution',[1536 864]/2);
 scene = ieGetObject('scene');
 scene = piAIdenoise(scene); ieReplaceObject(scene); sceneWindow;
%}

%{
oi = oiCreate;
oi = oiCompute(oi,scene);
oi = oiCrop(oi,'border');

sensor = sensorCreate('MT9V024');
sensor = sensorSet(sensor,'pixel size constant fill factor',1.5*1e-6);
sensor = sensorSet(sensor,'fov',sceneGet(scene,'fov'),oi);
sensor = sensorSet(sensor,'auto exposure',true);
% sensor = sensorSet(sensor,'exposure time',0.016);
sensor = sensorCompute(sensor,oi);
sensorWindow(sensor);

ip = ipCreate;
ip = ipCompute(ip, sensor);
ipWindow(ip);
%}


%% Label the objects using the CPU


%{
 ieNewGraphWin;
 imagesc(instanceMap);colormap(ax2,"colorcube");axis off;title('Pixel Label');
%}

%% Show the various images
%{
ieNewGraphWin([],'upperleftbig');

% We should be able to use the sensor image for finding the objects.
% But not yet.
imgscene = sceneGet(scene,'rgb');
% imgscene = ipGet(ip,'srgb');

subplot(2,2,1);
imshow(imgscene);title('Radiance')
ax1 = subplot(2,2,2);
imagesc(scene.depthMap);colormap(ax1,"gray");title('Depth');axis off
set(gca, 'Visible', 'off');
ax2=subplot(2,2,3);
imagesc(instanceMap);colormap(ax2,"colorcube");axis off;title('Pixel Label');
subplot(2,2,4);
imshow(imgscene);title('Bounding Box');

%% Add the bounding boxes, which requires the cocoapi method

nBox=1;
nImage = 1;
Annotation=[];
[h,w,~] = size(imgscene);

datasetFolder = fullfile(piRootPath,'local','dataset_demo');

% write out object ID for segmentation map;
if ~exist(fullfile(datasetFolder,'additionalInfo'),'dir')
    mkdir(fullfile(datasetFolder,'additionalInfo'))
end
seg_FID = fopen(fullfile(datasetFolder,'additionalInfo',[num2str(imageID),'.txt']),'w+');

fprintf(seg_FID,'sceneName: %s\nSkymap: %s\nCameraType: %s\n',sceneName, ...
    erase(skymapName,'.exr'), camera_type);
fprintf(seg_FID,'Object ID:\n');

for ii = 1:numel(objectslist)
    name = objectslist{ii};
    name = erase(name,{'ObjectInstance ', '"', '_m'});
    fprintf(seg_FID, '%d %s \n',ii, name);
    if contains(lower(name), {'car'})
        label = 'vehicle';
        catId = 3;
        r = 0.1; g= 0.5; b = 0.1;
    elseif contains(lower(name),'deer')
        label = 'Deer';
        catId = 9;
        r = 1; g= 0.1; b = 0.1;
    else
        continue;
    end
    [occluded, truncated, bbox2d, segmentation, area] = piAnnotationGet(instanceMap,ii,0);
    if isempty(bbox2d), continue;end
    pos = [bbox2d.xmin bbox2d.ymin ...
            bbox2d.xmax-bbox2d.xmin ...
            bbox2d.ymax-bbox2d.ymin];

    rectangle('Position',pos,'EdgeColor',[r g b],'LineWidth',1);
    tex=text(bbox2d.xmin+2.5,bbox2d.ymin-8,label);
    tex.Color = [1 1 1];
    tex.BackgroundColor = [r g b];
    tex.FontSize = 12;

    Annotation_coco{nBox} = struct('segmentation',segmentation,'area',area,'iscrowd',0,...
        'image_id',sprintf('%d',imageID),'bbox',pos,'category_id',catId,'id',0,'ignore',0); %#ok<SAGROW>
    fprintf('Class %s, instanceID: %d \n', label, ii);
    nBox = nBox+1;
end
truesize;

%%  Save the images


%{
% We are going to put the rgb image, depth map, pixel label, and
% bounding box in COCO format using this directory.  You can use these
% image data again later.
datasetFolder = fullfile(iaRootPath,'local','nightdrive','dataset');
if ~exist(datasetFolder,'dir'), mkdir(datasetFolder); end


if ~exist(fullfile(datasetFolder,'rgb'),'dir')
    mkdir(fullfile(datasetFolder,'rgb'))
end
if ~exist(fullfile(datasetFolder,'segmentation'),'dir')
    mkdir(fullfile(datasetFolder,'segmentation'))
end
if ~exist(fullfile(datasetFolder,'depth'),'dir')
    mkdir(fullfile(datasetFolder,'depth'))
end
if ~exist(fullfile(datasetFolder,'rendered'),'dir')
    mkdir(fullfile(datasetFolder,'rendered'))
end
imgName = sprintf('%d.png',imageID);

% Image_coco = struct('file_name',imgName,'height',h,'width',w,'id',sprintf('%d',imageID));
%
% % write files out
% save(fullfile(datasetFolder, sprintf('%d_image.mat',imageID)),'Image_coco');
% save(fullfile(datasetFolder, sprintf('%d_anno.mat',imageID)), 'Annotation_coco');

imgFilePath  = fullfile(datasetFolder,'rgb',imgName);
imwrite(radiance,imgFilePath);

imwrite(uint16(instanceMap),fullfile(datasetFolder,'segmentation',imgName));
imwrite(uint16(scene.depthMap),fullfile(datasetFolder,'depth',imgName));
outputFolder = roadData.recipe.get('outputdir');
movefile(fullfile(outputFolder,sprintf('renderings/%d.exr',imageID)),fullfile(datasetFolder,'rendered/'));
%}
% fprintf('****** Scene%d Generated! ******\n',nScene);

% end
%}
%}
%% End
