classdef isetActor < handle & matlab.mixin.Copyable
    %ACTOR Dynamic Elements in our scenes
    %   Place and animate assets for running scenarios
    %
    %   Initially written to support ISETAuto "native" scenarios
    %   Now we need to deal with scenarios imported from Matlab SDS
    %
    % D. Cardinal, Stanford University, June, 2023
    %
    properties
        name = '';
        recipe = [];
        assetType;
        branchID;

        % coordinate systems are different between DS & IA
        positionDS = [];
        positionIA = [];
        rotation = [];
        velocity = [];
        yaw = 0; % rotation on road
        savedYaw = 0; % so we can rotate by the increment

        % brakePower needs to be enhanced to support turns
        brakePower = [-7 0 0]; % -.7g, typical braking power

        % Whether we need to move the camera along with us
        hasCamera = false;
        braking = false;
    end

    methods
        function obj = isetActor()

        end

        %%  For DSD scenarios we get a scenario
        %  that has scenario.roadData.recipe
        function egoVehicle = place(anActor,scenario)
            % Coordinate systems are different
            anActor.positionIA = ia_drivingScenario.dsToIA( ...
                anActor.positionDS);

            % placeAsset redoes the recipeMerge, which is of course an
            % error from the vehicle placement queue
            anActor.placeAsset(scenario);
            anActor.recipe = scenario.roadData.recipe;

            % If we have the camera, move it
            if anActor.hasCamera
                anActor.recipe.lookAt.from = ...
                    anActor.positionIA + scenario.cameraOffset;

                % We need to rotate our camera view to match anActor.yaw
                % Just the first time. After this we do it in .advance
                useYaw = ia_drivingScenario.dsToIAYaw(anActor.yaw);
                rotationMatrix = makehgtform('zrotate',deg2rad(-1 * useYaw));
                % assume "in the distance" on x is the default, but then
                if scenario.debug
                    fromTo = [-200 0 -25];
                else
                    fromTo = [-200 0 0];
                end
                anActor.recipe.lookAt.to = ...
                    anActor.recipe.lookAt.from + fromTo * rotationMatrix(1:3, 1:3);

                % We almost always want "up" to be straight up 
                anActor.recipe.lookAt.up = [0 0 1]; % set per recipe or per lookat
                egoVehicle = anActor;
            end

        end

        %% Mostly deprecated, as we are using the DSD/ML simulation engine
        function turn(obj, seconds)
            assetBranchName = [obj.assetType '_B'];

            if obj.braking % Assume braking is straight ahead for now
                obj.velocity(1) = max(0, obj.velocity(1) + (obj.brakePower(1) * seconds));
            end
            % x direction needs to be reversed
            actualV = obj.velocity .* [-1 1 1];

            piAssetTranslate(obj.recipe,assetBranchName,actualV .* seconds);
            if obj.hasCamera
                obj.recipe.lookAt.from = obj.recipe.lookAt.from + (actualV .* seconds);
            end
        end
    end
end

