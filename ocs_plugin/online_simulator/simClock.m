classdef simClock < handle
    %SIMCLOCK This object represents a clock available in the simulation.
    % Cedric Richier, LIA
    % (c) LIA, 2021
    
    properties
        time_unit              = 1e-3; % time unit in seconds
        delta_T_time    % How long does a time slot last (in time units)
        current_delta_T % current number of time slots since the beginning (an integer)        
        time            % Actual time (in time units)
        time_since_last_action % Actual time since last decision (in time units)
    end
    
    methods
        function obj = simClock(delta_T_time, varargin)
            %SIMCLOCK Construct an instance of this class
            %   Detailed explanation goes here
            if nargin > 1
                obj.time_unit = varargin{1};
            end
            obj.delta_T_time           = delta_T_time;
            obj.current_delta_T        = -1;
            obj.time                   = -delta_T_time;
            obj.time_since_last_action = obj.time;            
        end
        
        % Advances clock by one time slot
        function obj = advance_1_delta_T(obj)
            obj.current_delta_T = obj.current_delta_T + 1;
            obj.time            = obj.time + obj.delta_T_time;
            obj.time_since_last_action = obj.time_since_last_action + obj.delta_T_time;
        end
        
        function management = is_to_manage(obj,events)
            management = false;
            if ~isempty(events)
                management = sum([events.event_delta_T] == obj.current_delta_T);
            end          
        end
        
        function obj = reset(obj)
            obj.current_delta_T        = -1;
            obj.time                   = -obj.delta_T_time;
            obj.time_since_last_action = obj.time;
        end
        
    end
end

