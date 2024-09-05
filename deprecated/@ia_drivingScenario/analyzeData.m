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
%}

ourData = scenario.logData;
simulationTime = [];
targetDistance = [];
vehicleVelocity = {};

%% Calculate distance to target
for ii = 1:numel(ourData)
    vehicleVelocity{ii} = ourData(ii).vehicleVelocity;

    targetRawDistance{ii} = max(0, ourData(ii).targetLocation - ourData(ii).vehicleLocation(1));
    targetDistance(ii) = sum(targetRawDistance{ii} .^2) ^.5;

    simulationTime(ii) = ourData(ii).simulationTime;

    % Calculate vehicle closing speed
    vehicleClosingVelocity{ii} = vehicleVelocity{ii} - ourData(ii).targetVelocity; %#ok<*AGROW>
    vehicleClosingSpeed(ii) = sum(vehicleClosingVelocity{ii} .^ 2) ^.5; %#ok<AGROW>
end

%% Write out a video of our run
open(scenario.v);
writeVideo(scenario.v, scenario.ourVideo);
close(scenario.v);

%% Show basic statistics and plot of speed vs. distance
figure('Name',['Initial Speed: ', num2str(scenario.initialSpeed)]); 
yyaxis left;
ylabel('Speed');
plot(simulationTime, vehicleClosingSpeed);
yyaxis right;
xlabel('time (s)');
ylabel('Distance');
plot(simulationTime, targetDistance);
legend('Vehicle Speed','Distance to Pedestrian');

title('Vehicle Speed & Distance to Pedestrian over Time', ...
    ['Start Speed:',num2str(scenario.initialSpeed()),', Start Distance: ',num2str(targetDistance(1)), ...
     ', Threshold: ', num2str(scenario.predictionThreshold), ', Sensor: ',scenario.sensorModel], ... 
     'FontSize',10);

end

