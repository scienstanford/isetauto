classdef scenario < handle
    %SCENARIO Pre-defined scenario with which we conduct tests/experiments
    
    properties
        Property1
    end
    
    methods
        function obj = scenario(inputArg1,inputArg2)
            %SCENARIO Construct an instance of this class
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

