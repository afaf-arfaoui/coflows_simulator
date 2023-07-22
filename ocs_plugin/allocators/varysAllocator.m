classdef varysAllocator < simAllocator
    %VARYSALLOCATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
         % See the simAllocator class for a list of inherited properties
    end
    
    methods
        function obj = varysAllocator(ocs)
            %VARYSALLOCATOR Construct an instance of this class
            %   Detailed explanation goes here
            obj = obj@simAllocator(ocs);
            obj.name = 'varys';
        end
        
        function min_duration = allocate(obj)
            % Bandwidth allocation according to MADD algorithm
            %   Detailed explanation goes here
            ocs = obj.ocs;
            
            is_skipped_coflow = false(1,length(ocs.coflows));
            skipped_coflow_idx = zeros(1,length(ocs.unfinished));
            skip_index = 0;
            
            % First loop over sorted coflows: MADD allocation
            % unfinished needs to be ordered in ascending gamma values
            %  (or in ascending arrival order in case of meet deadline
            %  objective)
            for k = ocs.unfinished
                c_idx = find([ocs.coflows.id] == k);
                c = ocs.coflows(c_idx);
                current_gamma = utils.computeGamma(c,c.getFlowsVolume,ocs.B);
                % case of coflow blocked by a higher priority coflow
                if current_gamma == inf
                    skip_index = skip_index +1;
                    skipped_coflow_idx(skip_index) = c_idx;
                    is_skipped_coflow(c_idx) = true;
                    continue;
                end
                % coflow has some resource available: allocate bandwidth to
                % its flows according to MADD
                if ocs.varys_dl % management when varys is in deadline mode
                    current_gamma = (c.deadline-ocs.sim_clock.time)...
                        *ocs.sim_clock.time_unit;
                end
                j = ocs.index_bases(k);
                for f = c.flows
                    j = j+1;
                    if ocs.Flows(j).state
                        f_links = ocs.Flows(j).IO;
                        rate = f.volume / current_gamma;
                        if sum(ocs.B(f_links)<rate)
                            rate = min(ocs.B(f_links));
                        end
                        % precision management
                        if rate < 1e-5
                            rate = 0;
                        end
                        ocs.Flows(j).rate = rate;
                        if rate
                            % Update active status for flow:
                            ocs.Flows(j).active = 1;
                            % Update bandwidth on path
                            ocs.B(f_links) = max(ocs.B(f_links)-rate,0);
                            % precision management
                            for l = f_links
                                if ocs.B(l) <= 1e-5
                                    ocs.B(l) = 0;
                                end
                            end
                        end
                    end
                end
            end
            
            %% Work conservation           
            if sum(is_skipped_coflow)
                % fair sharing among the skipped coflows:
                
                % % count the number of unfinished flows per available links
                n_flows_per_link = zeros(1,length(ocs.B));
                for c = ocs.coflows(is_skipped_coflow)
                    j  = ocs.index_bases(c.id);
                    for f = c.flows
                        j = j+1;
                        if ocs.Flows(j).state
                            f_links = ocs.Flows(j).IO;
                            if prod(ocs.B(f_links))
                                n_flows_per_link(f_links) = n_flows_per_link(f_links)+1;
                            end
                        end
                    end
                end
                
                % % fair sharing among skipped coflows in ascending order
                % % of their i_CCT_initial
                skipped_coflow_idx(~skipped_coflow_idx) = [];
                bw_used = zeros(1,length(ocs.B));
                for c_idx = skipped_coflow_idx
                    c = ocs.coflows(c_idx);
                    j = ocs.index_bases(c.id);
                    for f = c.flows
                        j = j+1;
                        if ocs.Flows(j).state
                            f_links = ocs.Flows(j).IO;
                            if prod(ocs.B(f_links))&&prod(n_flows_per_link(f_links))
                                rate = min(ocs.B(f_links)./n_flows_per_link(f_links));
                                % precision management
                                if rate <= 1e-5
                                    rate = 0;
                                end
                                ocs.Flows(j).rate = rate;
                                if rate
                                    % update active status of flow
                                    if ~ocs.Flows(j).active
                                        ocs.Flows(j).active = 1;
                                    end
                                    bw_used(f_links) = bw_used(f_links) + rate;
                                end
                            end
                        end
                    end
                end
                
                % % Update bandwidth accordingly
                ocs.B = ocs.B - bw_used;
                % precision management
                ocs.B(ocs.B<=1e-5) = 0;
                
            end
            
            %% Heuristic: sort coflows by arrival times and then refill
            % in case of varys with deadlines: sort in EDF order:
            sorted_coflows = ocs.coflows;
            
            if ocs.varys_dl
                % sort in EDF order
                dl = [ocs.coflows.deadline];
                [~,edf_order] = sort(dl);
                sorted_coflows = ocs.coflows(edf_order);
            end
            
            for c = sorted_coflows
                j = ocs.index_bases(c.id);
                for f = c.flows
                    j = j+1;
                    if ocs.Flows(j).state
                        f_links = ocs.Flows(j).IO;
                        if prod(ocs.B(f_links))
                            rate = min(ocs.B(f_links));
                            if rate <= 1e-5
                                rate = 0;
                            end
                            ocs.Flows(j).rate = ocs.Flows(j).rate + rate;
                            if rate
                                if ~ocs.Flows(j).active
                                    ocs.Flows(j).active = 1;
                                end
                                for l = f_links
                                    ocs.B(l) = ocs.B(l)-rate;
                                    if ocs.B(l) <= 1e-5
                                        ocs.B(l) = 0;
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            %% Compute duration until next departure
            
            % Consider only active flows (with rate > 0):
            ocs.f_active = [ocs.Flows.active]==1;
            
            % Compute the minimum duration to end at least one of all active flows:
            min_duration = min([ocs.Flows(ocs.f_active).volume]...
                ./[ocs.Flows(ocs.f_active).rate])/ocs.sim_clock.time_unit;
            %min_duration = min_duration/ocs.sim_clock.time_unit; 
            
        end
    end
end

