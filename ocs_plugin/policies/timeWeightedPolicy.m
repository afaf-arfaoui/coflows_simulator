classdef timeWeightedPolicy < onlinePolicy
    %TIMEWEIGHTEDPOLICY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        alpha_w
    end
    
    methods
        function obj = timeWeightedPolicy(ocs,varargin)
            %TIMEWEIGHTEDPOLICY Construct an instance of this class
            %   Detailed explanation goes here
            obj = obj@onlinePolicy(ocs);
            obj.name = 'time_weighted';
            obj.alpha_w = 0;
            switch nargin
                case 2
                    obj.alpha_w = varargin{1};
            end
        end
        
        function events = applyPolicy(obj,events)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            ocs = obj.ocs;
            sim_clock = ocs.sim_clock;
            
            % Get departure event indexes in events list
            departure_events_idx = strcmp([events.event_type],"departure");
            % Get events to manage in this round
            events_to_manage = events([events.event_delta_T] == sim_clock.current_delta_T);
            % Detect if there is an arrival event in this round
            is_arrival_event = ismember("arrival",[events_to_manage.event_type]);
            % Number of deadlines in the deadlines list:
            n_deadlines = length(ocs.deadlines);
            
            % update system (apply last allocation)
            ocs.applyAllocation();
            
            % remove all departure events in events list
            events(departure_events_idx) = [];
            
            % manage deadline event if necessary
            if ocs.is_dl_aware && n_deadlines > length(ocs.deadlines)
                deadline_events_idx = strcmp([events.event_type],"deadline");
                dl_to_check = events(deadline_events_idx).event_time;
                if ~ismember(dl_to_check,ocs.deadlines)
                    events(deadline_events_idx) = [];
                    if ~isempty(ocs.deadlines)
                        events(end+1) = simEvent('deadline',ocs.deadlines(1),sim_clock);
                    end
                end
            end
            
            % Manage new arrivals            
            if is_arrival_event                
                % update weights of coflows
                if ~isempty(ocs.coflows)
                    for c = ocs.coflows
                        c.weight = c.weight_origin*(1 + obj.alpha_w*...
                            (sim_clock.current_delta_T -...
                            ceil(c.arrival/sim_clock.delta_T_time)));
                    end
                end
                
                % update coflows in the system
                admission = ocs.addNewCoflows();
                
                % compute new order for all coflows
                if admission
                    ocs.unfinished = ocs.computePriorities(ocs.fabric,ocs.coflows);
                    
                    % storing priorities at this round
                    ocs.prio_idx = ocs.prio_idx + 1;
                    ocs.prio_table{ocs.prio_idx} = ocs.unfinished;
                end
                ocs.active = ~isempty(ocs.unfinished);
                
                % remove current arrival event in events list
                events(strcmp([events.event_type],"arrival")) = [];
                
                % set next arrival event in events list
                if ~isempty(ocs.arrival_times)
                    events(end+1) = simEvent('arrival',ocs.arrival_times(1),sim_clock);
                end
            end
            
            % Compute allocation if system is not empty
            if ocs.active
                % compute new allocation
                next_departure_time_interval = ocs.allocator.allocate();
                
                % add next departure event in events list
                events(end+1) = simEvent('departure',...
                    sim_clock.time + next_departure_time_interval,sim_clock);                
            end
        end
    end
end

