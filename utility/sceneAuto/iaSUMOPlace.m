function [sumoPlaced,assets] = iaSUMOPlace(trafficflow,varargin)
% Place assets with the Sumo trafficflow information
%
% Syntax
%  [assetsPosList,assets] = piTrafficPlace(trafficflow,varargin)
%
% Description
%   SUMO generates trafficflow at a series of timesteps. We choose one
%   or multiple timestamps, find the number and class of vehicles for
%   this/these timestamp(s) on the road. Download assets with respect
%   to the number and class.  The types of objects placed are:
%
%      cars, buses, pedestrians, bikes, trucks
%
% Inputs:
%   trafficflow - Struct with data generated by SUMO
%
% Optional Key value pairs
%   nScene
%   time stamp
%   traffic light (Default: 'red')
%   resources
%   scitran
%
% Returns
%   assetsPosList - Positions of the placed objects
%   assets -
%
%
% Author: Zhenyi Liu (ZL)
%
% See also
%

%% Parse parameterss
p = inputParser;

varargin =ieParamFormat(varargin);
p.addParameter('nScene',1);
p.addParameter('timestamp',[]);
p.addParameter('scitran',[]);
p.addParameter('trafficlight','red');

p.parse(varargin{:});

nScene       = p.Results.nScene;
timestamp    = p.Results.timestamp;
trafficlight = p.Results.trafficlight;
st = p.Results.scitran;

if isempty(st), st = scitran('stanfordlabs'); end

%% Download asssets with respect to the number and class of Sumo output.
ncars   = 0;
nped    = 0;
nbuses  = 0;
ntrucks = 0;
nbikes  = 0;

if isfield(trafficflow(timestamp).objects,'car') || ...
        isfield(trafficflow(timestamp).objects,'passenger')
    ncars = numel(trafficflow(timestamp).objects.car);
end

if isfield(trafficflow(timestamp).objects,'pedestrian')
    nped = numel(trafficflow(timestamp).objects.pedestrian);
end

if isfield(trafficflow(timestamp).objects,'bus')
    nbuses = numel(trafficflow(timestamp).objects.bus);
end

if isfield(trafficflow(timestamp).objects,'truck')
    ntrucks = numel(trafficflow(timestamp).objects.truck);
end

if isfield(trafficflow(timestamp).objects,'bicycle')
    nbikes = numel(trafficflow(timestamp).objects.bicycle);
end

% Description of the assets
assets = iaVehicleListCreate('ncars',ncars,...
    'nped',nped,...
    'nbuses',nbuses,...
    'ntrucks',ntrucks,...
    'nbikes',nbikes,...
    'scitran',st);

%% Classified mobile object positions.

% Buildings and trees are static objects, placed separately
sumoPlaced = assets;

assetClassList = fieldnames(assets);
for hh = 1: numel(assetClassList)
    
    assetClass = assetClassList{hh};
    order      = randperm(numel(trafficflow(timestamp).objects.(assetClass)));
    
    for jj = 1:numel(trafficflow(timestamp).objects.(assetClass))
        TFobjects_shuffled.(assetClass)(jj) = trafficflow(timestamp).objects.(assetClass)(order(jj));% target assets
    end
    index = 1;
%--------------------------------------------------------------------------
% In order to correctly add motion blur to the final rendering, we
% need to find out the position and rotation of the object on
% the next timestamp. We compare the object name of this 
% timestamp (Start transfromation) with the object name of 
% next timestamp (End transfromation).
%
% Example of a sumo car: 
% 
%            pos: [3×1 double]
%    orientation: 71.7100
%           name: 'passenger152_passenger'
%          slope: 0
%           type: 'passenger'
%          class: 'car'
%--------------------------------------------------------------------------

    for jj = 1:numel(TFobjects_shuffled.(assetClass))
        TFobjects_shuffled.(assetClass)(jj).motion=[];
        try
            for ii = 1:numel(trafficflow(timestamp+1).objects.(assetClass))
                if strcmp(TFobjects_shuffled.(assetClass)(jj).name, ...
                        trafficflow(timestamp+1).objects.(assetClass)(ii).name)
                    TFobjects_shuffled.(assetClass)(jj).motion.pos         = trafficflow(timestamp+1).objects.(assetClass)(ii).pos;
                    TFobjects_shuffled.(assetClass)(jj).motion.orientation = trafficflow(timestamp+1).objects.(assetClass)(ii).orientation;
                    TFobjects_shuffled.(assetClass)(jj).motion.slope       = trafficflow(timestamp+1).objects.(assetClass)(ii).slope;
                end
            end
        catch
            fprintf('% not found in next timestamp \n',assetClass);
        end
        
        if isempty(TFobjects_shuffled.(assetClass)(jj).motion)
            % there are cases when a car is going out of boundary or
            % some else reason, sumo decides to kill this car, so in
            % these cases, the motion info remains empty so we should
            % estimate by speed information;
            from        = TFobjects_shuffled.(assetClass)(jj).pos;
            distance    = TFobjects_shuffled.(assetClass)(jj).speed;
            orientation = TFobjects_shuffled.(assetClass)(jj).orientation;
            to(1)       = from(1)+distance*cosd(orientation);
            to(2)       = from(2);
            to(3)       = from(3)-distance*sind(orientation);
            
            % assign
            TFobjects_shuffled.(assetClass)(jj).motion.pos         = to;
            TFobjects_shuffled.(assetClass)(jj).motion.orientation = TFobjects_shuffled.(assetClass)(jj).orientation;
            TFobjects_shuffled.(assetClass)(jj).motion.slope       = TFobjects_shuffled.(assetClass)(jj).slope;
        end
    end
    for ii = 1: numel(assets.(assetClass))
        nInstance    = assets.(assetClass)(ii).count;
        
        position     = cell(nInstance,1);
        rotationY    = cell(nInstance,1); % rotationY is RotY
        slope        = cell(nInstance,1); % Slope is RotZ
        motionPos    = cell(nInstance,1);
        motionRotY   = cell(nInstance,1); % RotY for next frame
        motioinSlope = cell(nInstance,1); % RotZ for next frame
        
        for gg = 1:nInstance
            position{gg}  = TFobjects_shuffled.(assetClass)(index).pos;
            rotationY{gg} = TFobjects_shuffled.(assetClass)(index).orientation-90;
            slope{gg}     = TFobjects_shuffled.(assetClass)(index).slope;
            
            if isempty(slope{gg})
                slope{gg}=0;
            end
            
            motionPos{gg}    = TFobjects_shuffled.(assetClass)(index).motion.pos;
            motionRotY{gg}   = TFobjects_shuffled.(assetClass)(index).motion.orientation-90;
            motioinSlope{gg} = TFobjects_shuffled.(assetClass)(index).motion.slope;
            
            if isempty(motioinSlope{gg})
                motioinSlope{gg}=0;
            end
            index = index+1;
        end
        
        % Add position to the asset
        sumoPlaced.(assetClass)(ii).position = position;
        sumoPlaced.(assetClass)(ii).rotation = [];
        for rr = 1:numel(rotationY)
            sumoPlaced.(assetClass)(ii).rotation = piRotationMatrix('y',rotationY{rr});
            % use this when we have a road with slope
%           assetsPosList.(assetClass)(ii).rotation = piRotationMatrix('y',rotationY{rr}, 'z', slop{rr});
        end
        
        % Add Motion
        sumoPlaced.(assetClass)(ii).motion.position = motionPos;
        sumoPlaced.(assetClass)(ii).motion.rotation = [];
        for rr = 1:numel(rotationY)
            sumoPlaced.(assetClass)(ii).motion.rotation = piRotationMatrix('y',motionRotY{rr});
            % use this when we have a road with slope
%           assetsPosList.(assetClass)(ii).rotation = piRotationMatrix('y',motionRotY{rr}, 'z', motioinSlope{rr});
        end
    end
    
end
end
