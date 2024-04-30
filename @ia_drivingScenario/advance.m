%% Simulation turn advance
function running = advance(scenario)

persistent originalOutputFile;
persistent keepRunning; % turn off when we have one frame left
crashed = false; % default state
running = true;

% Need to place vehicles and actors now that we hopefully have yaw data
% Just do this once:
if scenario.needToPlaceVehicles == true
    scenario.placeVehicles();

    % placeVehicles adds headlamps, including for our ego vehicle
    % Since we want to replace those we need to delete them
    ourLights = piAssetSearch(scenario.roadData.recipe,'lightname', scenario.egoVehicle.Name);
    for ii=numel(ourLights):-1:1 % maybe count down
        lightName = scenario.roadData.recipe.get('asset',ourLights(ii),'name');
        scenario.roadData.recipe.set('light', lightName, 'delete');
    end

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
if scenario.justStarting ~= true && scenario.dataOnly == false

    % NOTE: If we only want a metric scene, we need to run through
    % advancing, but don't need to render the scene or capture images
    % HOWEVER: Still working on how to implement

    % First we show where we are (were) before moving
    % If we want to run in parallel recipe needs to have a different
    % outfile for each thread, but we don't need a new one
    % for each iteration, to the extent it matters

    % Add an option here to for lightgroup support
    if exist('scenario.useLightGroups') && scenario.useLightGroups
        warning('not supported');
        % make a cell array of per light group recipes
        recipeList = iaLightsGroup(scenario.roadData.recipe);
    else
        scene = scenario.renderRecipe(originalOutputFile); % do the hard work of rendering

        % show preview if desired
        if scenario.previewScenes

            % We use HDR with oncoming lights, but Standard
            % is more "accurate" for dark scenes
            %scene = sceneSet(scene, 'display mode', 'hdr');

            % Can also use sceneshowimage
            % Note: Faster but leads to un-labeled Window sprawl until we
            %       add some more pieces
            %sceneShowImage(scene, 3);
            %sceneWindow(scene);
        end

        % Create an image with a camera, and run a detector on it
        [image, crashed] = scenario.imageAndDetect(scene);

        % Here we want to create a movie/video
        addToVideo(scenario, scene, image, crashed);

        % We may also want to write out scene/OI files
        if scenario.writeSceneFiles

        end

        scenario.logFrameData(scene, scenario.detectionResults); % update our logging data structure
    end
    % only collect trajectory data
elseif scenario.dataOnly && ~scenario.justStarting
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

    scene = [];
    frameData = scenario.logFrameData(scene, scenario.detectionResults); % update our logging data structure

    fprintf('***************************\n');
    fprintf("MAX REACTION TIME: %2.3f\n",scenario.maxIDTime);
    fprintf('***************************\n');
else

    originalOutputFile = scenario.roadData.recipe.outputFile;
    scenario.justStarting = false;
end

% Move Actors based on their velocity
% e.g. both the egoVehicle & the lookAt from/to
% Assume that egoVehicle is #1
for ii = 1:numel(scenario.roadData.actorsIA)
    ourActor = scenario.roadData.actorsIA{ii};

    % look for our "target" object
    if isempty(scenario.targetObject) && isequal(ourActor.name, scenario.targetName)
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

        % If we might have a ped, turn a headlight on high
        % (Currently always the right headlamp)
        if scenario.warnPed == true
            % Find right headlight -- should put in headlamp class!
            pLightRight = piAssetSearch(scenario.roadData.recipe,'lightname', 'Right Headlight');
            % Set the mask on it to high beam
            maskFile = ['skymaps','/', 'headlamp_highbeam.exr'];
            scenario.roadData.recipe.set('light',pLightRight,'filename',maskFile);
            piWrite(scenario.roadData.recipe);
        end

        % if we are confident we have a pedestrian, begin braking
        if scenario.foundPed == true

            cprintf('*Red','Recognized pedestrian\n');
            % braking should move closer to abs()
            % for now just decelerate in forward/back

            deceleration = (ourActor.brakePower * scenario.stepTime);
            ourActorDS.Velocity = scenario.egoVelocity + deceleration;
            scenario.egoVelocity(1) = max(ourActorDS.Velocity(1), 0);
            ourActorDS.Velocity(1) = scenario.egoVelocity(1);

            % We also need to lower the Speed in DSD's scenario
            % Not clear if Speed is always m/s or m/interval
            vehicleWaypoints = scenario.egoVehicle.MotionStrategy.Waypoints;
            vehicleSpeed = scenario.egoVehicle.MotionStrategy.Speed;

            % I think we only want to change the speed for future
            % waypoints, otherwise we "rewrite history."
            % For example:
            ourLocation = scenario.egoVehicle.Position(1);
            waypointsFuture = vehicleWaypoints(:,1)>ourLocation;
            vehicleSpeed(waypointsFuture) = ...
                max(vehicleSpeed(vehicleWaypoints(:,1)>ourLocation) ...
                + deceleration(1), 0); % can't go backwards

            % Braking shouldn't ever cause backward motion
            % And if we don't have a positive speed, DSD freaks out
            newSpeed = max(vehicleSpeed + -1 * sum(deceleration.^2)^.5,0.01);
            scenario.egoVehicle.trajectory(vehicleWaypoints, newSpeed);


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
    cprintf('*Blue', "DSVelocity %s : %2.2f, %2.2f, %2.1f", ...
        currentActor.Name, ...
        currentActor.Velocity(1), ...
        currentActor.Velocity(2), ...
        currentActor.Velocity(3));

    % Print yaw if needed for debugging
    %cprintf('*Blue', ", DSyaw: %2.1f\n", currentActor.Yaw);

    % Also move our Actors by time step * velocity
    % move asset per velocity inherited from DS
    ourActor.yaw = currentActor.Yaw;
    ourActor.moveAsset(scenario, ...
        currentActor);
end

% stop on crash or after processing final frame
if crashed || (~isempty(keepRunning) && ~keepRunning)
    running = false;
    clear keepRunning; % otherwise it persists to next run!
else
    % run super-class method
    keepRunning = advance@drivingScenario(scenario);
end

% If scenario has ended, analyze results
if ~running
    scenario.analyzeData();
end
end


