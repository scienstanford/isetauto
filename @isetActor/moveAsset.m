function assetBranch = moveAsset(obj, scenario, actorDS)
% Move an asset in a driving simulation
%
% Currently uses Translate and Rotate
% True object motion not supported yet
%
%   D.Cardinal, Stanford, May, 2023
%
%

%% For Matlab scenes, we get a scenario along with our object

obj.printPosition(obj, scenario);

assetBranchName = [obj.name '_B'];

ourRecipe = scenario.roadData.recipe;

% Adjust for x-axis being towards the car in Ford scenes
% But not in Matlab SDS Scenes

%% For vehicles from Matlab's DSD we need to do this differently
% Time constant and coordinate reversal
aVelocity = actorDS.Velocity .* [1 1 0]; % even though coordinates aren't all reversed, velocity is?
aMove = aVelocity .* scenario.SampleTime;

%% NOTE: PBRT doesn't support animating lights (like headlights)
%        So at least for now, we disable animation of vehicles
if ~isequal(aMove, [0 0 0])
    if ~scenario.useObjectMotion || isequal(class(actorDS),'driving.scenario.Vehicle')
        assetBranch = piAssetTranslate(ourRecipe,assetBranchName,aMove);
    else % use dynamic transforms
        ourRecipe.hasActiveTransform = true;
        % We may need to clear existing motion first if using the broken
        % version of iset3d (currently fix is in the dev-motion branch)
        % ADD MOTION
        piAssetMotionAdd(ourRecipe,assetBranchName, ...
            'translation', aMove);
        % we probably also need a rotation for piWriteGeometry to work
    end
end
%% SUPPORT FOR rotating assets to a new direction
deltaYaw = obj.yaw - obj.savedYaw;
if deltaYaw ~= 0
    if ~scenario.useObjectMotion|| isequal(class(actorDS),'driving.scenario.Vehicle')
        assetBranch = piAssetRotate(ourRecipe,assetBranchName,...
            [0 0 deltaYaw]);
        obj.savedYaw = obj.yaw;
    else
        ourRecipe.hasActiveTransform = true;

        % USE MOTION
        piAssetMotionAdd(ourRecipe,assetBranchName, ...
            'rotation', [0 0 deltaYaw]);
        obj.savedYaw = obj.yaw;
        
    end
end

