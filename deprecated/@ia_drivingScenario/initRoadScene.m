function roadData = initRoadScene(obj, road_name, lighting)
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
sceneName = road_name;
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
        roadData.recipe.set('light',skymapNode, 'specscale', 0.01);


    case 'dusk'
        %% Set up the rendering skymap -- this is just one of many available
        skymapName = 'night.exr'; % Most skymaps are in the Matlab path already
        roadData.recipe.set('skymap',skymapName);

        skymapNode = strrep(skymapName, '.exr','_L');
        roadData.recipe.set('light',skymapNode, 'specscale', 1);


    case 'daytime'
end

% Create driving lane(s) for both directions
roadData.set('onroad car lanes',{'leftdriving','rightdriving'});

%% Place the offroad elements.  These are only animals and trees.  Not cars.
roadData.set('offroad tree names', {'tree_001','tree_002','tree_003'});
roadData.set('offroad n trees', [50, 1, 1]); % [50, 100, 150]
roadData.set('offroad tree lane', {'rightshoulder','leftshoulder'});

% from the driving simulator now
roadData.assemble();

end
