%% Simulation turn advance
function running = advance(scenario)

persistent originalOutputFile;

% Need to place vehicles and actors now that we hopefully have yaw data
% Just do this once:
if scenario.needToPlaceVehicles == true
    scenario.placeVehicles();
    scenario.needToPlaceVehicles = false;
end
if scenario.needToPlaceActors == true
    scenario.placeActors();
    scenario.needToPlaceActors = false;
end

% Set our interval for use in computing motion
ourTimeStep = scenario.SampleTime;

% We may want to skip initial frame since it doesn't have yaw
% correct
if scenario.justStarting ~= true
    % First we show where we are (were) before moving
    % If we want to run in parallel recipe needs to have a different
    % outfile for each thread, but we don't need a new one
    % for each iteration, to the extent it matters
    
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

    % organize this more rationally...
    if isequal(scenario.deNoise, 'exr_all')
        scene = piRender(ourRecipe, 'do_denoise', 'exr_all');
    elseif isequal(scenario.deNoise, 'exr_albedo')
        scene = piRender(ourRecipe, 'do_denoise', 'exr_albedo');
    elseif isequal(scenario.deNoise, 'exr_radiance')
        scene = piRender(ourRecipe, 'do_denoise', 'exr_radiance');
    elseif isequal(scenario.deNoise, 'scene')
        scene = piRender(ourRecipe);
        scene = piAIdenoise(scene,'quiet', true, 'batch', true);
    else % no denoise or denoise later after rgb
        scene = piRender(ourRecipe);
    end

    if isempty(scene)
        error("Failed to render scene. dockerWrapper.reset() might help\n");
    end

    % add to our scene list for logging
    scenario.sceneList{end+1} = scene;

    % show preview if desired unless we are in an official experiment
    if ~ia_drivingScenario.inExperiment && scenario.previewScenes
        scene = sceneSet(scene, 'display mode', 'hdr');
        % try sceneshowimage
        % Note: Faster but leads to un-labeled Window sprawl until we
        %       add some more pieces
        %sceneShowImage(scene, 3);
        sceneWindow(scene);
    end

    % Create an image with a camera, and run a detector on it
    image = scenario.imageAndDetect(scene);
    scenario.logFrameData(scene, scenario.detectionResults); % update our logging data structure

    % Here we want to create a movie/video
    % presumably one frame at a time
    addToVideo(scenario, scene, image);
else
    originalOutputFile = scenario.roadData.recipe.outputFile;
    scenario.justStarting = false;
end

% Move Actors based on their velocity
% e.g. both the egoVehicle & the lookAt from/to
% Assume that egoVehicle is #1
for ii = 1:numel(scenario.roadData.actorsIA)
    ourActor = scenario.roadData.actorsIA{ii};

    % assume we are looking for ped 001
    if isempty(scenario.targetObject) && isequal(ourActor.name, 'pedestrian_001')
        scenario.targetObject = ourActor;
    end
    
    if ourActor.hasCamera
        ourActorDS = scenario.roadData.actorsDS{ii};
        if scenario.needEgoVelocity

            scenario.egoVelocity = ourActorDS.Velocity;
            if ia_drivingScenario.initialSpeed() > 0
                scenario.egoVelocity(1) = ia_drivingScenario.initialSpeed();
                ourActorDS.Velocity(1) = ia_drivingScenario.initialSpeed();
            else
                scenario.initialSpeed(abs(ourActorDS.Velocity(1)));
            end
            scenario.needEgoVelocity = false;
        end
        
        % if we have a pedestrian, begin braking
        if  scenario.foundPed == true

            cprintf('*Red','Recognized pedestrian\n');
            % braking should move closer to abs()
            % for now just decelerate in forward/back
            ourActorDS.Velocity = scenario.egoVelocity + ...
                (ourActor.brakePower * scenario.stepTime);
            scenario.egoVelocity(1) = max(ourActorDS.Velocity(1), 0);
            ourActorDS.Velocity(1) = scenario.egoVelocity(1);

        end

        % Move camera
        adjustedVelocity = scenario.egoVelocity;
        scenario.roadData.recipe.lookAt.from = ...
            scenario.roadData.recipe.lookAt.from + ...
            (adjustedVelocity .* ourTimeStep);
        % NEED to make this follow Yaw!
        scenario.roadData.recipe.lookAt.to = ...
            scenario.roadData.recipe.lookAt.from + [200 0 0];
        cprintf('*Green', 'Camera from: %2.1f to: %2.1f\n', ...
            scenario.roadData.recipe.lookAt.from(1), ...
            scenario.roadData.recipe.lookAt.to(1));
    end
    % Debug statements with current info
    currentActor = scenario.roadData.actorsDS{ii};
    assetBranchName = strcat(currentActor.Name, '_B');
    [~, currentAsset] = piAssetFind(scenario.roadData.recipe, 'name', assetBranchName);
    % I think we get a cell array from Find in case there is more than one?
    %{ 
    % Unfortunately this doesn't seem to work except for lights!
    currentRotation = piAssetGet(currentAsset{1}, 'worldrotation');
    %}
    cprintf('*Blue', "DSVelocity %s : %2.2f, %2.2f, %2.1f", ...
        currentActor.Name, ...
        currentActor.Velocity(1), ...
        currentActor.Velocity(2), ...
        currentActor.Velocity(3));
    cprintf('*Blue', ", DSyaw: %2.1f\n", currentActor.Yaw);
    % Also move our Actors by time step * velocity
    % move asset per velocity inherited from DS
    ourActor.yaw = currentActor.Yaw;
    ourActor.moveAsset(scenario, ...
        currentActor);
end
% run super-class method
running = advance@drivingScenario(scenario);

% If scenario has ended, analyze results
if ~running
    scenario.analyzeData();
end
end


