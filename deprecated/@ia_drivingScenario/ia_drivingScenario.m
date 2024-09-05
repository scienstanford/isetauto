classdef ia_drivingScenario < drivingScenario
    %IA_DRIVINGSCENARIO our custom version of a Matalb driving scenario
    % It's a sub-class of drivingScenario from the Matlab Driving toolbox
    % It extends the class by integrating it with ISETAuto, ISET3d, and
    % ISETCam

    % D. Cardinal, Stanford University, June, 2023
    properties

        %% "Scene/Scenario" settings
        %  These determine the base case (fixed variables)
        %  Currently they are mostly specified in the .mat file
        %  created by the drivingScenarioDesigner, that was used
        %  to create our parent function

        % Here we set those that Matlab doesn't include, or over-ride
        % others as needed
        lighting = 'nighttime';

        %% General settings that don't affect the results
        scenarioName = 'LabTest'; % default
        frameRate = 3; % playback speed in frames per second
        
        %% Simulation specific parameters
        % Main parameters to determine quality versus speed
        % In the true "metric" case these probably need to be different
        % (e.g. real frame rates, sceneResolution > cameraResolution
        %       lots of rays, and no de-noising)

        stepTime = .2; % time per image frame/step
        scenarioQuality = 'quick'; % default
        deNoise = 'exr_albedo'; % can use 'exr_radiance', 'exr_albedo', 'scene', or ''

        % For debugging raise the camera and look down
        debug = false; % if true, then of course detection isn't realistic

        %% TestRig specific parameters
        sensorModel = 'MT9V024SensorRGB'; % one of our automotive sensors

        %% Housekeeping parameters
        roadData = []; % our ISETAuto road data struct
        % We get these from our superclass
        %waypoints; % in meters
        %speed; % meters/second
        numActors = 0;

        % SOME SCENES ARE REVERSED, some not
        % Should see if we can figure out a way to decide automatically
        coordinateMapping = [1 1 1]; % [-1 -1 1];

        % We don't get Pose information on Actors and Vehicles until
        % after we start up the scenario. So we need to create a collection
        % of them as they are initialized, for later placement.
        vehicleCount = 1;
        actorCount = 1;

        % The first time through .advance we need to place
        % our version of vehicles and actors based on their position
        % in the DSD baseline.
        needToPlaceVehicles = true;
        needToPlaceActors = true;
        vehiclesToBePlaced = {};
        actorsToBePlaced = {};
        needRoads = true;
        justStarting = true; % allows us to skip first frame
        needEgoVelocity = true; % need to set it when we first get one
        egoVelocity = [0 0 0]; % set once we have a car
        egoVehicle = [];
        targetObject = [];
        foundPed = false;

        frameNum = 1; % to start
        logData = [];

        cameraOffset = [0 0 2]; % needs to be changed later
        predictionThreshold = .95; % default is .95, lower for testing;
        detectionResults = []; %Updated as we drive

        v = [];
        % video structure with frames for creating clips
        ourVideo = struct('cdata',[],'colormap',[]);

        sceneList = {};
        previewScenes = true; % over-ridden in experiments

    end

    methods(Static)
        % in its own file
        iaCoordinates = dsToIA(dsCoordinates);
        iaYaw = dsToIAYaw(dsYaw);

        % Basically just definining a class-level variable
        % We should set it from the ego vehicle's first speed #
        function iSpeed = initialSpeed(inputSpeed)
            persistent pSpeed;
            if isempty(pSpeed), pSpeed = 0; end % ignore if 0
            if nargin
                pSpeed = inputSpeed;
            end
            iSpeed = pSpeed;
        end
        % Basically just definining a class-level variable
        function result = inExperiment(truefalse)
            persistent isTrue;
            if isempty(isTrue), isTrue = false; end % ignore if 0
            if nargin
                isTrue = truefalse;
            end
            result = isTrue;
        end
    end

    methods
        function ds = ia_drivingScenario(varargin)

            %% Initialize ISET before running
            % We can't do it here or we lose what we've already started
            %ieInit;

            % Let the Matlab driving scenario (superclass) set things up first
            % ds now contains a "blank slate" scenario
            ds = ds@drivingScenario(varargin{:});
            ds.SampleTime = ds.stepTime; % use our time interval
        end

        %% How far away do we need to stop braking
        % this is a function of initial velocity, braking power, and target
        % distance, possibly including the car's reaction time
        function meters = minimumBrakingDistance(obj)

            %{ 
            %Here is a canonical industry formula for stopping distance:
            The AASHTO stopping distance formula is as follows:

                s = (0.278 × t × v) + v² / (254 × (f + G))

                where:

                    s – Stopping distance in meters;
                    t – Perception-reaction time in seconds;
                    v – Speed of the car in km/h;
                    G – Grade (slope) of the road, expressed as a decimal. Positive for an uphill grade and negative for a downhill road; and
                    f – Coefficient of friction between the tires and the road. It is assumed to be 0.7 on a dry road and between 0.3 and 0.4 on a wet road.
            
                    NOTE: kmh/3.6 = m/s
            %}

            % Semi-constants (at least for now)
            % set a reaction time for the car (need to research actuals)
            reactionTime = .1; % seconds
            friction = .7; % dry road
            grade = 0; % level road

            startingSpeed = obj.initialSpeed;

            % industry formula is "generic" and doesn't include brake power
            % so this is moot for now
            %brakingEffect = -7; % m/s Should be per vehicle??

            % calculate stopping distance
            startVelocity = startingSpeed * 3.6;
            meters = (0.278 * reactionTime * startVelocity) + startVelocity ^ 2 / (254 * (friction + grade));

        end

        %% We only use the road to tell us which of our road scenes
        % to load (based on the road name)
        % Here is the default call used by the ds superclass:
        % road(scenario, roadCenters, 'Heading', headings, 'Lanes', laneSpecification, 'Name', 'road_020');
        function road(scenario, segments, varargin)
            p = inputParser;
            p.addParameter('Name', 'road_020'); % over-ridden
            p.KeepUnmatched = true; % we don't parse all args here
            p.parse(varargin{:});

            if scenario.needRoads == true
                roadName = p.Results.Name;
                % LOAD ROAD DATA/SCENE into ISETAuto
                % We need to specify our own lighting
                % Road data is our IA data we stash in the driving scenario
                % We only want to init once!
                scenario.roadData = scenario.initRoadScene(roadName, 'nighttime');
                scenario.needRoads = false;

                % Set up video here because it doesn't like the constructor
                % VideoWriter variables
                %scenario.scenarioName = 'LabDemo';
                %scenario.scenarioQuality = 'quick';
                if isunix   
                    videoFormat = 'Motion JPEG AVI';
                else
                    videoFormat = 'MPEG-4';
                end
                scenario.v = VideoWriter(strcat(scenario.scenarioName, "-", scenario.scenarioQuality),videoFormat);
                scenario.v.FrameRate = scenario.frameRate; % 15-30 for high fidelity

                % Set output rendering quality
                iaQualitySet(scenario.roadData.recipe, 'preset', scenario.scenarioQuality);
                road@drivingScenario(scenario, segments, varargin{:});
            end
        end
        % The name is what we use to know what vehicle to add
        % We can also use other assets by name
        %{
        % This is a sample call used by matlab
        egoVehicle = vehicle(scenario, ...
            'ClassID', 1, ...
            'Position', [-95.8 -4.9 0], ...
            'Mesh', driving.scenario.carMesh, ...
            'Name', 'car_004');
        waypoints = [-95.8 -4.9 0;
            -78.3 -6.2 0;
            -65.7 -6 0;
            -45.2 -5.6 0];
        speed = [17;17;17;17];
        trajectory(egoVehicle, waypoints, speed);
        %}

        % Scenario is our Object
        % We'll assume first vehicle is egoVehicle
        function vehicleDS = vehicle(scenario, varargin)

            p = inputParser;
            p.addParameter('ClassID',1); % don't know if we need this
            p.addParameter('Name','car_004', @ischar);
            p.addParameter('Position', [0 0 0]);

            % DS Doesn't pass yaw. Sigh.
            %p.addParameter('Yaw', 0); % rotation on road
            p.KeepUnmatched = true;
            p.parse(varargin{:});


            % Add Vehicle asset to our @Recipe
            ourVehicle = isetActor();
            if scenario.debug % raise camera
                scenario.cameraOffset = [.9 0 8];
            else
                % this should be per actor, but here for now for ease of
                % editing
                scenario.cameraOffset = [0 0 2];
            end


            % This is the Matlab (DS) position (x & y reversed from ISETauto)
            ourVehicle.positionDS = p.Results.Position;

            % what about pitch, roll, yaw?
            %ourCar.rotation = [0 0 180]; % facing forward
            ourVehicle.assetType = p.Results.Name;
            ourVehicle.name = p.Results.Name;

            ourVehicle.velocity = [0 0 0]; % set separately

            % call with egoVehicle if we have the sensors?
            vehicleDS = vehicle@drivingScenario(scenario, varargin{:});

            % Set first vehicle as ego vehicle
            if isempty(scenario.egoVehicle)
                scenario.egoVehicle = vehicleDS;
                ourVehicle.hasCamera = true;
            end

            % We don't get poses right away from DSD, so we might
            % need to stack these up and execute on advance

            addActor(scenario, vehicleDS, ourVehicle);

            % Start a queue of vehicles to be placed once we know
            % their Pose (mostly Yaw)
            scenario.vehiclesToBePlaced{scenario.vehicleCount} = {ourVehicle, vehicleDS};
            scenario.vehicleCount = scenario.vehicleCount + 1;

        end

        %% Non-vehicle actors (e.g. Pedestrians, Animals, etc.)
        % These an also be animated using Waypoints
        %{
        actor(scenario, ...
            'ClassID', 4, ...
            'Length', 0.24, ...
            'Width', 0.45, ...
            'Height', 1.7, ...
            'Position', [-30.6 -5.6 0], ...
            'RCSPattern', [-8 -8;-8 -8], ...
            'Mesh', driving.scenario.pedestrianMesh, ...
            'Name', 'pedestrian_001');
        %}

        %% Create an actor struct for DSD to use
        function actorDS = actor(scenario, varargin)
            p = inputParser;
            p.addParameter('ClassID',4); % don't know if we need this
            p.addParameter('Name','pedestrian_001', @ischar);
            p.addParameter('Position', [0 0 0]);
            p.addParameter('Length', .24);
            p.addParameter('Height', 1.7);
            p.addParameter('Width', .45);

            p.KeepUnmatched = true;
            p.parse(varargin{:});

            ourActor = isetActor();

            % ADD NON_VEHICLE ASSET OR AT LEAST SET PARAMETER
            ourActor.positionDS = p.Results.Position;
            ourActor.assetType = p.Results.Name;
            ourActor.name = p.Results.Name;

            ourActor.velocity = [0 0 0]; % set separately

            % We place later, after we know the Pose
            %ourActor.place(scenario);
            actorDS = actor@drivingScenario(scenario, varargin{:});
            addActor(scenario, actorDS, ourActor);

            % Start a queue of actors to be placed once we know
            % their Pose (mostly Yaw)
            scenario.actorsToBePlaced{scenario.actorCount} = {ourActor, actorDS};
            scenario.actorCount = scenario.actorCount + 1;

        end

        % For potential future use, right now we just call superclass
        function trajectory(scenario, egoVehicle, waypoints, speed)
            trajectory@drivingScenario(scenario, egoVehicle, waypoints, speed);
        end

        % We need to keep track of actors so we can animate them
        % NOTE: Haven't integrated Pose with non-vehicle actors yet
        function addActor(scenario, actorDS, actorIA)
            if scenario.numActors == 0
                scenario.roadData.actorsDS = {};
                scenario.roadData.actorsIA = {};
                scenario.numActors = 1;
            else
                scenario.numActors = scenario.numActors + 1;
            end
            scenario.roadData.actorsDS{scenario.numActors} = actorDS;
            scenario.roadData.actorsIA{scenario.numActors} = actorIA;
        end


        function placeVehicles(scenario)

            % get poses needed for Yaw calcs
            gotPoses = actorPoses(scenario);
            %relativePoses = targetPoses(scenario.egoVehicle);

            % find yaw ourselves
            allPoses = gotPoses;

            for ii = 1:numel(scenario.vehiclesToBePlaced)
                ourVehicle = scenario.vehiclesToBePlaced{ii};
                ourPose = allPoses(ourVehicle{2}.ActorID);

                if isfield(ourPose,'Yaw')
                    ourVehicle{1}.yaw = ourPose.Yaw;
                else
                    ourVehicle{1}.yaw = 0;
                end

                % Now we can place the vehicle
                ourVehicle{1}.place(scenario);
            end
        end

        % Maybe this can be combined with placeVehicles?
        function placeActors(scenario)

            % get poses needed for Yaw calcs
            gotPoses = actorPoses(scenario);
            %relativePoses = targetPoses(scenario.egoVehicle);

            % find yaw ourselves
            allPoses = gotPoses;

            for ii = 1:numel(scenario.actorsToBePlaced)
                ourActor = scenario.actorsToBePlaced{ii};
                ourPose = allPoses(ourActor{2}.ActorID);

                if isfield(ourPose,'Yaw')
                    ourActor{1}.yaw = ourPose.Yaw;
                else
                    ourActor{1}.yaw = 0;
                end

                % Now we can place the vehicle
                ourActor{1}.place(scenario);
            end
        end
    end
end

