% method that does the actual PBRT rendering of the recipe for an auto
% simulation. It is usually called from .advance as the simulation
% progresses
function scene = renderRecipe(scenario, originalOutputFile)

    ourRecipe = scenario.roadData.recipe;
    [pp, nn, ee] = fileparts(originalOutputFile);
    ourRecipe.outputFile = fullfile(pp, [nn '-' sprintf('%03d', scenario.frameNum) ee]);

    % Auto scenes only have radiance in their metadata!
    % We should start adding the others by default, so this section will be
    % moot...
    ourRecipe.metadata.rendertype = {'radiance','depth','albedo'}; % normal

    % This should be redundant?
    ourRecipe.set('rendertype', {'depth', 'radiance', 'albedo'});

    piWrite(ourRecipe);

    %% We now have lots of denoising options
    % 'scene' is the "current" way, with piAIDenoise()
    % The others use the version of the denoiser that operates
    % directly on the .exr file and can use additional channels
    % of information.

    if scenario.addSphere

        % delete skymap
        ourRecipe.set('skymap','delete');

        sphere = piAssetLoad('sphere');
        assetSphere = piAssetSearch(sphere.thisR,'object name','Sphere');

        % Move to the starting pedestrian distance
        %  0 for testing,  34 for "real" in 4s * 17m/s scenario
        piAssetTranslate(sphere.thisR,assetSphere,[34 -2 .5]);

        % Default sphere is huge, scale it to use in scene
        piAssetScale(sphere.thisR,assetSphere,[.002 .002 .002]);

        % Mirror should give us most accurate light reading
        piMaterialsInsert(sphere.thisR,'name','mirror'); 
        piMaterialsInsert(sphere.thisR,'name','glossy-white'); 

        sphere.thisR.set('asset', assetSphere, 'material name', 'mirror');

        ourRecipe = piRecipeMerge(ourRecipe,sphere.thisR, 'node name',sphere.mergeNode,'object instance', false);
        piWrite(ourRecipe);
        scenario.addSphere = false;
    end

    % Update Docker container if needed
    scenario.dockerInUse = getDocker(ourRecipe, scenario.dockerInUse);

    % Allow for various NR options
    if isequal(scenario.deNoise, 'exr_all')
        scene = piRender(ourRecipe, 'do_denoise', 'exr_all', ...
            'mean luminance',-1,'dockerWrapper', scenario.dockerInUse);
    elseif isequal(scenario.deNoise, 'exr_albedo')
        scene = piRender(ourRecipe, 'do_denoise', 'exr_albedo',...
            'mean luminance',-1,'dockerWrapper', scenario.dockerInUse);
        % sceneWindow(scene);
    elseif isequal(scenario.deNoise, 'exr_radiance')
        scene = piRender(ourRecipe, 'do_denoise', 'exr_radiance',...
            'mean luminance',-1,'dockerWrapper', scenario.dockerInUse);
    elseif isequal(scenario.deNoise, 'scene')
        scene = piRender(ourRecipe,'mean luminance',-1,'dockerWrapper', scenario.dockerInUse);
        scene = piAIdenoise(scene,'quiet', true, 'batch', true);
    else % no denoise or denoise later after rgb
        scene = piRender(ourRecipe, 'mean luminance',-1,'dockerWrapper', scenario.dockerInUse);
    end

    if isempty(scene)
        dockerWrapper.reset();
        warning("Failed to render scene. Trying dockerWrapper.reset().\n");
    else
        % add to our scene list for logging
        scenario.sceneList{end+1} = scene;
    end

    
end

% Set up correct docker image
% isetdocker in -tiny ignores the docker container we pass and uses presets
% so for now we have to clear out the container
% This function is also in our motion validation script (de-dup?)
function useDocker = getDocker(thisR, dockerInUse)

% Only reset when switching!
% Need to add code that works with both iset3D and iset3D-tiny!!
usingTiny = contains(piRootPath,'-tiny','IgnoreCase',true);

% If we have -tiny in our path, use isetdocker
if usingTiny

    if thisR.hasActiveTransform
        % Need to use a cpu version of pbrt for this case
        % switch if needed
        if isempty(dockerInUse) || isequal(dockerInUse.device, 'gpu')
            reset(isetdocker);
            dockerCPU = isetdocker('preset','orange-cpu');
            useDocker = dockerCPU;
        else
            useDocker = dockerInUse;
        end
    else % can use GPU
        if isempty(dockerInUse) || ~isequal(dockerInUse.device, 'gpu')
            dockerGPU = isetdocker('preset','remoteorange');
            useDocker = dockerGPU;
        else % we already have a GPU version
            useDocker = dockerInUse;
        end
    end
else % otherwise use dockerWrapper from ISET3d

    if thisR.hasActiveTransform % need CPU
        if isempty(dockerInUse) || dockerInUse.gpuRendering
            % Need CPU for object motion
            useDocker = dockerWrapper('verbosity',2,'gpuRendering',0, ...
                'remoteImage','digitalprodev/pbrt-v4-cpu');
        else
            useDocker = dockerInUse;
        end
    else % can use GPU
        if isempty(dockerInUse) || ~dockerInUse.gpuRendering
            useDocker = dockerWrapper('verbosity',2,'gpuRendering',1, ...
                'remoteImage', 'digitalprodev/pbrt-v4-gpu-ampere-ti');
        else
            useDocker = dockerInUse;
        end
    end
end
end
