%% Lidar numbers


SOL = 3*1e8; % meters per second

%% Coarse scale calculation

% Time to go and return for an object between 1 and 300 meters
% 
distance = logspace(0,2.5,20);   % Meters

% Time for round trip
t0 = 2*distance/SOL;
t0microSec = t0*1e6;

ieNewGraphWin;
plot(distance, t0microSec)
xlabel('Distance in meters')
ylabel('Round trip time (microseconds');

grid on
title('Coarse scale');

%% The longest distance takes about 2 microseconds for the round trip.

%% Fine scale

% Time to go and return for an object between 1 and 300 meters
% 
distance = logspace(-1,1,20);   % Meters

% Time for round trip
t0 = 2*distance/SOL;
t0microSec = t0*1e9;

ieNewGraphWin;
plot(distance, t0microSec)
xlabel('Distance in meters')
ylabel('Round trip time (nanoseconds');

grid on
title('Fine scale');

