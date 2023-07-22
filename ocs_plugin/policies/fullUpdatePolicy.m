classdef fullUpdatePolicy < onlinePolicy
    %BASICSTRATEGY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = fullUpdatePolicy(ocs)
            %BASICSTRATEGY Construct an instance of this class
            %   Detailed explanation goes here
            obj = obj@onlinePolicy(ocs);
            obj.name = 'full_update';
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
            
            %% Non clairvoyant specific
            % Detect if there is some volume threshold reached in the
            % non-clairvoyant case
            is_vol_thresh_event = ismember("thresh",[events_to_manage.event_type]);
            % This must be manage only if the simulation is set to
            % non-clairvoyant:
            is_vol_thresh_event = is_vol_thresh_event && ~ocs.is_clrvnt;    
            
            %%
            % update system (apply last allocation)
            ocs.applyAllocation();
            
            % remove all departure events in events list
            events(departure_events_idx) = [];
            
            % remove thresh reached event
            if ~ocs.is_clrvnt
                % Flag is set, the event can be removed form events list
                events(strcmp([events.event_type],"thresh")) = [];
            end
            
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
            
            % Manage new arrivals in case of new arrivals           
            if is_arrival_event
                % update coflows in the system
                admission = ocs.addNewCoflows();
                
                % compute new order for all coflows (in case of some
                % coflows are admitted or if a volume thresh has been
                % reached in the non-clairvoyant case
                if admission || is_vol_thresh_event
                    if ocs.varys_dynamic_gammas
                        ocs.unfinished = ocs.computePriorities(ocs.fabric,ocs.coflows,false);
                    else
                        ocs.unfinished = ocs.computePriorities(ocs.fabric,ocs.coflows);
                    end
                    
                    % storing priorities for this round
                    ocs.prio_idx = ocs.prio_idx + 1;
                    ocs.prio_table{ocs.prio_idx} = ocs.unfinished;
                end
                ocs.active = ~isempty(ocs.unfinished);
                
                % remove current arrival event in events list
                events(strcmp([events.event_type],"arrival")) = [];
                
                % remove current thresh event in events list if necessary
%                 if ~ocs.is_clrvnt
%                     events(strcmp([events.event_type],"thresh")) = [];
%                 end
                
                % set next arrival event in events list
                if ~isempty(ocs.arrival_times)
                    events(end+1) = simEvent('arrival',ocs.arrival_times(1),sim_clock);
                end
            % No new arrival: management of volume threshold events
            % (non-clairvoyant scenario) or departure management when using
            % varys with dynamic gammas (compute new priorities of coflows
            % with updated values of isolation CCTs)
            elseif is_vol_thresh_event || (ocs.varys_departure && ocs.active)...
                    || (ocs.utopia_departure && ocs.active)
                if ocs.varys_dynamic_gammas && ocs.varys_departure
                    ocs.unfinished = ocs.computePriorities(ocs.fabric,ocs.coflows,false);
                else
                    ocs.unfinished = ocs.computePriorities(ocs.fabric,ocs.coflows);
                end
                
                % storing priorities for this round
                ocs.prio_idx = ocs.prio_idx + 1;
                ocs.prio_table{ocs.prio_idx} = ocs.unfinished;
                %ocs.active = ~isempty(ocs.unfinished);
                
                % departure has been managed. In varys case, send signal to
                % system
                if ocs.varys_departure
                    ocs.varys_departure = false;
                end
                if ocs.utopia_dynamic_order
                    ocs.utopia_departure = false;
                end
                
                % remove current thresh event in events list
                %events(strcmp([events.event_type],"thresh")) = [];
            end
            
            % Compute allocation if system is not empty
            if ocs.active
                % compute new allocation
                next_departure_time_interval = ocs.allocator.allocate();
                
                %% TEST
%               Here we should manage the setting of next threshold
%               reached event
                if ~ocs.is_clrvnt
                    next_thresh_time_interval = computeDurationTillThreshVol(ocs);
                    % add next threshold reached event in events list
                    if next_thresh_time_interval > 0
                        events(end+1) = simEvent('thresh',...
                            sim_clock.time + next_thresh_time_interval,...
                            sim_clock);
                    end
                end
                %% END TEST
                
                % add next departure event in events list
                events(end+1) = simEvent('departure',...
                    sim_clock.time + next_departure_time_interval,sim_clock);
            end
        end
        
    end
end

