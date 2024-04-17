function trafficflow = newpiSumoRead(varargin)
%% Parse a Sumo exported xml file, return a struct of objects with location information.
%
% We use a terminal command "sumo -c xxx.cfg --fcd-output <FILENAME>" to
% export contains location and speed along with other information for every 
% vehicle in the network at every time step.
% fcd is floating car data.
% 
% Input: there are two possible inputs.
%       'flowFile','xxx.xml': full path of .xml file.(records info. of vihecles and persons)
%       'lightFile','xxx.xml': full path of .xml file.(records info. of traffic lights)
% 
% Output: a structure with information of the objects(vehicles/people/trafficlight status) 
% in the scene.
%   
% Output structure:
%
%   scene---|---timestamp: the time stamp of traffic simulation
%           |                 |---class:vehicle/pedestrian
%           |---objects--car--|---name: sumo assigned ID
%           |             |   |---type: police/emergency/...
%           |             |   |---pos : 3d position;
%           |             |   |---speed : m/s
%           |             |   |---orientation:The angle of the vehicle in 
%           |             |               navigational standard (0-360 
%           |             |               degrees, going clockwise with 0 
%           |             |               at the 12'o clock position)
%           |             |
%           |     pedestrian--|---class:pedestrian
%           |             |   |---name: sumo assigned ID
%           |             |   |---type: []
%           |             |   |---pos : 3d position;
%           |             |   |---speed : m/s
%           |             |   |---orientation:same as 'car' class
%           |             |
%           |            bus---same as 'car' class
%           |             |
%           |             |
%           |           truck---same as 'car' class
%           |             |
%           |             |
%           |           bicycle---same as 'car' class
%           |             |
%           |             |
%           |         motorcycle---same as 'car' class
%           |
%           |           |--Name: trafficlights' name
%           |---light---|
%                       |--State: green/yellow/red
%
% Now, we have 6 classes totally.
% P.S. In Sumo, pedestrian class doesn't have 'type', type of pedestrian is empty.
% Jiaqi Zhang, VISTALAB, 2018

% Traffic lights supported
% by Jiayue, 2024

%% Parse input parameters
p = inputParser;
p.addParameter('flowFile',[]);
p.addParameter('lightFile',[]);

p.parse(varargin{:});
inputs = p.Results;

flowFile = inputs.flowFile;
lightFile = inputs.lightFile;

%%
if ~isempty(flowFile)
[~,~,e]= fileparts(flowFile);
if ~isequal(e,'.xml'), error('Only xml file supported');end
end
if ~isempty(lightFile)
[~,~,e]= fileparts(lightFile);
if ~isequal(e,'.xml'), error('Only xml file supported');end
end
%% Get all the information of vehicles and persons and store them as a struct

pyScriptPath=fullfile(piRootPath,'data','sumo_input','xml2json.py');
genJsonCmd="python "+pyScriptPath+" -f "+flowFile+" -t "+lightFile;
outputCmd=" -o vehicleState.json";
sysCmd=genJsonCmd+outputCmd;
system(sysCmd)
trafficflow=jsonread('vehicleState.json');


    