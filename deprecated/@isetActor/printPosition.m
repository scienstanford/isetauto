function assetBranch = printPosition(obj, scenario, actorDS)
% Place an asset in a driving simulation
%
%   D.Cardinal, Stanford, May, 2023
%

%% For Matlab scenes, we get a scenario along with our object

assetBranchName = [obj.name '_B'];
ourRecipe = obj.recipe;

ourLocation = ourRecipe.get('asset',assetBranchName,'world position');

%ourLocation = piAssetGet(thisAssetBranch, 'world coordinates');

%% For vehicles from Matlab's DSD we need to do this differently
% Time constant and coordinate reversal
cprintf('-Black', "Actor: %s at %2.1f, %2.1f, %2.1f\n", obj.name, ...
    ourLocation(1), ourLocation(2), ourLocation(3));

end
