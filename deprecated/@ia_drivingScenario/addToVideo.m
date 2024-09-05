function addToVideo(scenario, scene, image)

% Save out our scene list each frame, so we have it for later
saveName = fullfile(iaDirGet('local'),'demo_scenes.mat');
scenesToSave = scenario.sceneList;

%% NOTE: This is really expensive. Should probably change to do at end
save(saveName, 'scenesToSave', "-v7.3");

dRGB = double(image); % version for movie
scenario.ourVideo(scenario.frameNum) = im2frame(dRGB);

% plot time versus distance
%ieNewGraphWin
%plot(runData(:,1),runData(:,2))

% for quick viewing use mmovie
%movie(ourVideo, 10, 1);

% This creates a "checkpoint" video every frame
% but certainly wasteful -- else we just do it at the end
%{
open(scenario.v);
writeVideo(scenario.v, scenario.ourVideo);
close(scenario.v);
%}

scenario.frameNum = scenario.frameNum + 1;

end
