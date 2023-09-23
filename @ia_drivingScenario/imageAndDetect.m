function [image, crashed] = imageAndDetect(scenario, scene)
% image our scene through a camera of our choosing,
% and then run an object detector on it
% (YOLOv4 by default, but could be any compatible detector)

% We only want to fire up the detector once if we can
% as it takes some time to initialize
persistent yDetect; % Our (YOLO) detector
persistent detectionThreshhold; % for declaring a match

if isempty(yDetect)
    yDetect = yolov4ObjectDetector("csp-darknet53-coco");
    detectionThreshhold = scenario.predictionThreshold; % How confident do we need to be
end

crashed = false; % default state

% Now generate results through a sensor
useSensor = scenario.sensorModel;
shutterspeed = 1/30; % typical of auto video cameras
fNumber = 1.4;
analogGain = 10; % off of native ISO

% We probably want to return the IP or something besides the
% annotated image...
% I think we need to do this slightly differently...
ip = piRadiance2RGB(scene,'etime',shutterspeed,'sensor',useSensor, ...
    'fNumber', fNumber, 'analoggain', analogGain);

% Experiment with denoising after image capture
if isequal(scenario.deNoise, 'rgb')
    ip = piRGBDenoise(ip);
end

% Detect object classes that our detector is trained on
rgb = ipGet(ip, 'srgb');
[bboxes,scores,labels] = detect(yDetect,rgb);

% See if we have found a person (e.g. pedestrian)
% NOTE: We don't (yet) distinguish between multiple pedestrians
peds = ismember(labels,'person'); % Any person?

% If we have found a pedestrian set the flag, but don't unset it
if ~isempty(peds) && (isempty(scenario.foundPed) || scenario.foundPed == false)
    scenario.foundPed = max(scores(peds)) > detectionThreshhold; 
end

if scenario.foundPed
    cprintf('*Red', 'Identified Pedestrian...\n');
    scenario.roadData.actorsIA{scenario.roadData.targetVehicleNumber}.braking = true;
end

% Should have both label & score here:
rgb = insertObjectAnnotation(rgb,"rectangle",bboxes,labels, 'FontSize', 16);

% Return detection results, along with other data
scenario.detectionResults.bboxes = bboxes;
scenario.detectionResults.scores = scores;
scenario.detectionResults.labels = labels;

% Calculate distance to pedestrian. 
targetRawDistance = scenario.targetObject.positionDS - scenario.egoVehicle.Position;
pedMeters = sum(targetRawDistance .^2) ^.5;
roadMeters = targetRawDistance(1); % even if the ped isn't in the center of the car, we still hit them

caption = sprintf("Time: %2.1f Speed: %2.1f Dist: %2.1f", ...
    scenario.SimulationTime, ...
    scenario.egoVelocity(1), ...
    roadMeters);

% check for being too close, or for perhaps even already hit the pedestrian
if pedMeters <= .3 || roadMeters <= .2
    caption = strcat(caption, " ***CRASH*** ");
    crashed = true;
end

if scenario.foundPed % cheat & assume we are actor 1
    image = insertText(rgb,[0 0],strcat(caption, " -- BRAKING"),'FontSize',24, 'TextColor','red');
else
    image = insertText(rgb,[0 0],caption,'FontSize',24);
end


end
