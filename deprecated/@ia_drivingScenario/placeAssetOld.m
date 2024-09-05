function placeAsset(scenario, assetName, position, rotation)
%IAPLACEASSET Quick way to manually place assets in auto scenes
%   Caveat: There might already be some code for this in ISET3d
%           but I couldn't find it
%   Related: It might actually be general enough to put in ISET3d, but
%            wanted to get the ball rolling for Auto stuff
%
%   D.Cardinal, Stanford, May, 2023
%

%% For Matlab scenes, we get a scenario object

assetBranchName = [assetName '_B'];
assetFileName = [assetName '.pbrt'];

assetRecipe = piRead(assetFileName);

% Adjust for x-axis being towards the car in Ford scenes
% But not in Matlab SDS Scenes!

%% For vehicles from Matlab's DSD we need to do this differently
if ~isempty(position)
    % position is where we want to be relative to car in x and y
    % and relative to ground in z
    assetTranslation(1) = cameraLocation(1) - position(1);
    assetTranslation(2) = cameraLocation(2) + position(2);
    assetTranslation(3) = position(3); 
    assetBranch = piAssetTranslate(assetRecipe,assetBranchName, assetTranslation);
end
if ~isempty(rotation)
    assetBranch = piAssetRotate(assetRecipe,assetBranchName,rotation);
end

scenario.roadData.recipe = piRecipeMerge(scenario.roadData.recipe, assetRecipe);

end
