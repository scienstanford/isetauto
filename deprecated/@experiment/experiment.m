classdef experiment < handle
    %EXPERIMENT Specific test parameters run against a scenario
    %   These include lens, sensor, headlights, vehicle, flare, and
    %   camera position among others
    
    properties
        Property1
    end
    
    methods
        function obj = experiment(inputArg1,inputArg2)
            %EXPERIMENT Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1 + inputArg2;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

