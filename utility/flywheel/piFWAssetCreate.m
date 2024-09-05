function [recipe, acqId, resourcesName] = piFWAssetCreate(acq, varargin)
% Create a flywheel asset (depracted)
%
% Syntax:
%  recipe = piFWAssetCreate(acq, varargin)
% 
% Required:
%  acq    - a Flywheel acquisition container which stores an asset and the
%           recipe and CG resources (textures, meshes) necessary to render
%           the asset 
% 
% Optional key/val pairs
%  resources  - true:  download reciepe and CG resources  
%               false: download recipe only
%  dstDir     - destination directory where CG resources will be saved,
%        default directory is created at isetauto/local.
%
% Return:
%  recipe    - asset recipe
% 

%%
p = inputParser;
p.addParameter('resources',false,@islogical);
p.addParameter('dstDir','',@ischar);

p.parse(varargin{:});

resourcesFlag = p.Results.resources;
dstDir = p.Results.dstDir;
% create destination directory
if isempty(dstDir)
    dstDir = fullfile(iaRootPath, 'local', 'FWAssets', acq.label);
end
if ~exist(dstDir,'dir'), mkdir(dstDir);end
%%  We download the json file for the recipe
for ii = 1:length(acq.files)
    if ieContains(acq.files{ii}.name, 'recipe')
        recipe_path = fullfile(dstDir, acq.files{ii}.name);
        % if we have already downloaded this file, do not download again.
        if ~exist(recipe_path,'file')
            acq.downloadFile(acq.files{ii}.name, recipe_path);
            fprintf('%s is downloaded.\n',acq.files{ii}.name);
        end
        break;
    end
end

% Read and convert the json recipe into a ISET3d recipe
if endsWith(recipe_path,'.mat')
    tmp = load(recipe_path);
    recipe = tmp.thisR;
else
    recipe = piJson2Recipe(recipe_path);
end
recipe.assets = recipe.assets.uniqueNames;
%% Download CG Resource file
dstFile = fullfile(dstDir, 'tmp.zip');
for ii = 1:length(acq.files)
    if strcmpi(acq.files{ii}.type,'CG Resource')
        acqId =acq.id;
        resourcesName = acq.files{ii}.name;
        if resourcesFlag && ...
                ~exist(fullfile(dstDir, 'scene/PBRT/pbrt-geometry'),'dir')
            acq.downloadFile(acq.files{ii}.name, dstFile);
            unzip(dstFile, dstDir);
            % addpath(genpath(dstDir))
            delete(dstFile);
        end
        break;
    end
end

end