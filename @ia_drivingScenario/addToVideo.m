function addToVideo(scenario, scene, image, crashed)

% Save out our scene list each frame, so we have it for later
saveName = fullfile(scenario.sceneFileDir,'scene_OIs.mat');
scenesToSave = scenario.sceneList;

%% NOTE: This is really expensive. Should probably change to do at end
if scenario.writeSceneFiles
    save(saveName, 'scenesToSave', "-v7.3");
end

dRGB = double(image); % version for movie
dRGB(isnan(dRGB)) = 0; % weed out NaNs that we're getting for some reason
scenario.ourVideo(scenario.frameNum) = im2frame(dRGB);

% last frame doesn't always show, so provide a couple extras
if crashed || scenario.SimulationTime >= scenario.StopTime
    scenario.frameNum = scenario.frameNum + 1;
    scenario.ourVideo(scenario.frameNum) = im2frame(dRGB);
    scenario.frameNum = scenario.frameNum + 1;
    scenario.ourVideo(scenario.frameNum) = im2frame(dRGB);
end

% plot time versus distance
%ieNewGraphWin
%plot(runData(:,1),runData(:,2))

% for quick viewing use mmovie
%movie(ourVideo, 10, 1);

% This creates a "checkpoint" video every frame
% but certainly wasteful -- else we just do it at the end
open(scenario.v);
writeVideo(scenario.v, scenario.ourVideo);
close(scenario.v);

scenario.frameNum = scenario.frameNum + 1;

end
