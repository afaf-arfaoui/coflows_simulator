classdef onlinePolicy < handle
    %ONLINESTRATEGY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        name = 'generic online policy';
        ocs        
    end
    
    methods(Abstract)
        sim_events = applyPolicy(obj,sim_events);
    end
    
    methods
        function obj = onlinePolicy(ocs)
            %ONLINESTRATEGY Construct an instance of this class
            %   Detailed explanation goes here
            obj.ocs = ocs;
        end
    end
end

