function  logFrameData(scenario, scene, detectionResults)
% Keep a record of vehicle & target info as we run
% to use for later analysis. Typically called as part of .advance()
%

logFrame = [];

% Find positions here
ourRecipe = scenario.roadData.recipe;

% egoVehicle seems to be a DS Vehicle, targetObject is an IA actor
assetBranchName = [convertStringsToChars(scenario.egoVehicle.Name) '_B'];
vehicleLocation = ourRecipe.get('asset',assetBranchName,'world position');
vehicleVelocity = scenario.egoVelocity;

assetBranchName = [convertStringsToChars(scenario.targetObject.name) '_B'];
targetLocation = ourRecipe.get('asset',assetBranchName,'world position');
targetVelocity = scenario.targetObject.velocity;

logFrame.targetLocation = targetLocation;
logFrame.vehicleLocation = vehicleLocation;
logFrame.vehicleVelocity = vehicleVelocity;
logFrame.targetVelocity = targetVelocity;
logFrame.simulationTime = scenario.SimulationTime;

scenario.logData = [scenario.logData logFrame];

end
