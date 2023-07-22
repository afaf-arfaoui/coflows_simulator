classdef simEvent < handle
    %SIMEVENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        event_type;
        event_delta_T;
        event_time;      
    end
    
    methods
        function obj = simEvent(event_type,event_time,clock)
            %SIMEVENT Construct an instance of this class
            %   Detailed explanation goes here
            if nargin > 0
                obj.event_type = convertCharsToStrings(event_type);
                delta_T_time = clock.delta_T_time;
                obj.event_delta_T = ceil(event_time/delta_T_time);
                obj.event_time = obj.event_delta_T*delta_T_time;               
            end
        end
        
    end
end

