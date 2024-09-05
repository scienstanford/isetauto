function assetBranch = placeAsset(obj, scenario)
% Place an asset in a driving simulation
% 
%   D.Cardinal, Stanford, May, 2023
%

%% For Matlab scenes, we get a scenario along with our object

assetBranchName = [obj.name '_B'];
assetFileName = [obj.name '.pbrt'];

assetRecipe = piRead(assetFileName);

% Adjust for x-axis being towards the car in Ford scenes
% But not in Matlab DSD Scenes!
aPosition = obj.positionIA;
aRotation = obj.rotation;
aYaw = obj.yaw;

if isempty(aYaw), aYaw = 0; end % default

%% For vehicles from Matlab's DSD we need to do this differently
if ~isempty(aPosition)
    % Unfortunately there is no such thing as a Set for coordinates
    %piAssetSet(assetRecipe, assetBranchName, 'world coordinates', ...
       % aPosition);
    % HOWEVER, we might be able to cheat because asset recipes put
    % the asset at 0 0 0, so we can try translation
    piAssetTranslate(assetRecipe,assetBranchName,aPosition);    
end
if ~isempty(aRotation)
    piAssetRotate(assetRecipe,assetBranchName,aRotation);
end

% Adjust for reversed directions, maybe 
useYaw = obj.yaw;
if obj.yaw ~= 0
piAssetRotate(assetRecipe,assetBranchName,...
        [0 0 useYaw]); % what if yaw is right sometimes?
    obj.savedYaw = obj.yaw;
end
scenario.roadData.recipe = piRecipeMerge(scenario.roadData.recipe, assetRecipe);

end
