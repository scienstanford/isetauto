function analyzeData(scenario)
%ANALYZEDATA Show results of run
%
% So far we have velocities, but we don't have distance
%
%{
% Here is what we get:
logFrame.targetLocation = targetLocation;
logFrame.vehicleLocation = vehicleLocation;
logFrame.vehicleVelocity = vehicleVelocity;
logFrame.targetVelocity = targetVelocity;
logFrame.simulationTime = scenario.SimulationTime;
logFrame.targetDistance;
logFrame.detectionResults;
%}

% set these as needed when we first find one!
foundPedPlot = [];
warnPedPlot = [];
crashedPlot = [];
textPedPlot = {};
stoppedPlot = [];

ourData = scenario.logData;
simulationTime = [];
targetDistance = [];
vehicleVelocity = {};

%% Calculate distance to target
for ii = 1:numel(ourData)
    vehicleVelocity{ii} = ourData(ii).vehicleVelocity;

    targetDistance(ii) = ourData(ii).targetDistance;
    simulationTime(ii) = ourData(ii).simulationTime;

    % Calculate vehicle closing speed
    vehicleClosingVelocity{ii} = vehicleVelocity{ii} - ourData(ii).targetVelocity; %#ok<*AGROW>
    vehicleClosingSpeed(ii) = sum(vehicleClosingVelocity{ii} .^ 2) ^.5; %#ok<AGROW>

    % decide what we want to report about detection status...
    % ... ourData(ii).detectionResults has bboxes, labels, and scores

    % We show the confidence # every time it is > 0
    if ourData(ii).pedLikelihood > 0
        textPedPlot{end+1} = [simulationTime(ii), targetDistance(ii), ourData(ii).pedLikelihood];
    end

    % The next few we only show once
    if isempty(foundPedPlot) && ~isempty(ourData(ii).foundPed)
        foundPedPlot = [simulationTime(ii), vehicleClosingSpeed(ii)];
    end
    if isempty(warnPedPlot) && ~isempty(ourData(ii).warnPed)
        warnPedPlot = [simulationTime(ii), vehicleClosingSpeed(ii)];
    end
    if isempty(crashedPlot) && ~isempty(ourData(ii).crashed)
        crashedPlot = [simulationTime(ii), vehicleClosingSpeed(ii)];
    end

    % Once we stop, we're "safe"
    if isempty(stoppedPlot) && vehicleClosingSpeed(ii) <= 0
        stoppedPlot = [simulationTime(ii), vehicleClosingSpeed(ii)];
    end
end

%% Write out a video of our run if we recorded one
if numel(scenario.ourVideo) > 0
    open(scenario.v);
    writeVideo(scenario.v, scenario.ourVideo);
    close(scenario.v);
end

%% Show basic statistics and plot of speed vs. distance
figStats = figure( 'NumberTitle','off','Name',['PAEB with Headlight: ', scenario.headlampType, ', Initial Speed: ', num2str(scenario.initialSpeed), ' m/s']); 

xlim([0,scenario.StopTime]);

yyaxis left;
ylim([0,scenario.initialSpeed]);
plot(simulationTime, vehicleClosingSpeed);
ylabel('Speed (m/s)');

% Add text annotations
% Ideally we want to show more than one if they overlap
if ~isempty(warnPedPlot)
    text(warnPedPlot(1), warnPedPlot(2),"Alert!");
end
if ~isempty(foundPedPlot)
    % offset if we are already warning
    if ~isempty(warnPedPlot) && isequal(warnPedPlot(1),foundPedPlot(1))
        text(foundPedPlot(1)+.3, foundPedPlot(2),"Brake!");
    else
        text(foundPedPlot(1), foundPedPlot(2),"Brake!");
    end
end
if ~isempty(crashedPlot)
    text(crashedPlot(1), crashedPlot(2),"Crash!");
elseif ~isempty(stoppedPlot)
    text(stoppedPlot(1), stoppedPlot(2),"Stopped!");
end

yyaxis right;
ylim([0,max(targetDistance)]);
plot(simulationTime, targetDistance);
ylabel('Distance (m)');



for ii = 1:numel(textPedPlot)
    try
        % textPedPlot is time, distance, value
        text(textPedPlot{ii}(1), textPedPlot{ii}(2), sprintf("%2.2f",textPedPlot{ii}(3)));
    catch
        warning('problem plotting text');
    end
end

grid on;
legend('Vehicle Speed','Distance to Pedestrian');
title('Vehicle Speed & Distance to Pedestrian over Time', 'FontSize',12);

% We want xlabel to have multiple lines
captionLine1 = sprintf('Start -- Speed: %2.1f (m) Distance: %2.1f (m)', scenario.initialSpeed(),targetDistance(1));
captionLine2 = sprintf('Thresholds: %.2f, %.2f, Sensor: %s', scenario.alertThreshold, scenario.predictionThreshold ,scenario.sensorModel);
captionLine3 = 'Notations are confidence level & actions taken';

xlabel({'Time (s)', '', captionLine1, captionLine2, captionLine3}, 'FontSize', 12);

end

