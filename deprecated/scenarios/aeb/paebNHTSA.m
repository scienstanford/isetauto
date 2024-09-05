function ourScene = paebNHTSA(testScenario, varargin)
%IA_PAEBNHTSA Load NHTSA test scenario into a recipe
% ?? Should there be a "meta-recipe" like we have for bio?
%
% D. Cardinal, Stanford University, June, 2023

% There are "base" scenarios that are run with different speeds
% and different lighting. We can probably make those either
% varargs or properties

% lightLevel; % .2 lux or daylight
% vehicleSpeed; % 10-60 kph
% pedestrianSpeed; % 5-8 kph
% pedestrianVariant; % man or child

varargin = ieParamFormat(varargin);
p = inputParser;

p.addRequired('testscenario', @ischar);

% Baseline settings
p.addParameter('roadname','road_020'); % choose from available road scenes

% Settings used by all NHTSA PAEB test cases
p.addParameter('carspeed',17); % m/s, 17 == 60kph
p.addParameter('lighting','nighttime'); % or daytime
p.addParameter('mannequin', 'man'); % or child
p.addParameter('testdurationinitial', 4); % seconds to target without brakes
p.addParameter('overlap', .25); % how far pedestrian is timed to cross car
p.addParameter('pedestrian','pedestrian_002');

%% Additional settings
p.addParameter('cartype', 'car_004'); % Shelby
p.addParameter('carname', 'Shelby');

%% Additional complicating factors
% Here is where we would place additional vehicles or obstacles

p.parse(testScenario, varargin{:});

%% Set up the road itself and the lighting
ourScene = initRoadScene(p.Results.roadname, p.Results.lighting);

%% This is our test vehicle
carSpeed = p.Results.carspeed;
testDuration = p.Results.testdurationinitial;
targetDistance = testDuration * carSpeed; % tests start 4 seconds away

ourCar = actor();
ourCar.position = [0 0 0]; % e.g. uss
ourCar.rotation = [0 0 180]; % facing forward
ourCar.assetType = p.Results.cartype;
ourCar.name = p.Results.carname;

ourCar.velocity = [carSpeed 0 0]; % moving forward at 10 m/s
ourCar.hasCamera = true; % move camera with us
ourCar.place(ourScene.recipe);

% Add our car to the actors in our scenario and set as target vehicle
ourScene.targetVehicleNumber = numel(ourScene.actors) + 1;
ourScene.actors{end+1} = ourCar;

switch testScenario
    case 'pedRoadsideRight' % stationary at .25 across car
        % Add a pedestrian on the right side of our lane at the .25 mark
        ourScene.recipe = iaPlaceAsset(ourScene.recipe, p.Results.pedestrian, [carSpeed * testDuration 1 0], [0 0 90]);

    case 'pedRoadsideLeft'

    case 'pedBehindCars'
        % etc
end

switch p.Results.mannequin
    case 'man'
    case 'child'
        % need to scale
        pedBranchName = [p.Results.pedestrian '_B'];
        piAssetScale(ourScene.recipe, pedBranchName, [.5 .5 .5]);

end

end

function roadData = initRoadScene(road_name, lighting)
%% (Optional) isetdb() setup (using existing prefs)
sceneDB = isetdb();

%% Find the road starter scene/asset and load it
% If fullpath to the asset is not given, we will find it in our database
% We have quite a few generated roads. Currently they are usually 400m long

% Create the road data object that we will populate with vehicles
% and other objects for eventual assembly into our scene
% We can find it either in our path, or the sceneDB
roadData = roadgen('road directory',road_name, 'asset directory', sceneDB);

% fix output .pbrt file path & name
sceneName = 'PAEB_Roadside';
roadData.recipe.set('outputfile',fullfile(piDirGet('local'),sceneName,[sceneName,'.pbrt']));

%% Fix lighting
% There is some weird light in this scene that we need to remove:
roadData.recipe.set('light','all','delete');

switch lighting
    case 'nighttime'
        %% Set up the rendering skymap -- this is just one of many available
        skymapName = 'night.exr'; % Most skymaps are in the Matlab path already
        roadData.recipe.set('skymap',skymapName);

        % Really dark -- NHTSA says down to .2 lux needs to work
        % So we should calculate what that means for how we scale the skymap
        skymapNode = strrep(skymapName, '.exr','_L');
        roadData.recipe.set('light',skymapNode, 'specscale', 0.001);

    case 'daytime'
end

% Create driving lane(s) for both directions
roadData.set('onroad car lanes',{'leftdriving','rightdriving'});

%% Place the offroad elements.  These are only animals and trees.  Not cars.
roadData.set('offroad tree names', {'tree_001','tree_002','tree_003'});
roadData.set('offroad n trees', [50, 1, 1]); % [50, 100, 150]
roadData.set('offroad tree lane', {'rightshoulder','leftshoulder'});

end
