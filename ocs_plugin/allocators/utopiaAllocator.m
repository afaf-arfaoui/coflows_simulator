classdef utopiaAllocator < simAllocator
    %UTOPIAALLOCATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % See the simAllocator class for a list of inherited properties
    end
    
    methods
        function obj = utopiaAllocator(ocs)
            %UTOPIAALLOCATOR Construct an instance of this class
            %   Detailed explanation goes here
            obj = obj@simAllocator(ocs);
            obj.name = 'utopia';
        end
        
        function min_duration = allocate(obj)
            % Bandwidth allocation according to Utopia algorithm
            %   Detailed explanation goes here
            
            ocs = obj.ocs;
            n_links = ocs.fabric.numFabricPorts;
            n_coflows = length(ocs.coflows);
            n_machines = n_links/2;
            
            % Supercoflow demand:
            DS = zeros(n_links,1);
            
            % Demand matrix:
            D = zeros(n_links,n_coflows);
            
            % cumulative Rate = sum_(l<k)[r_l(i,j)]
            cumulRate = zeros(n_machines,n_machines);
            
            % Demand of super coflow on path i,j (i: ingress port, j: egress port)
            DS_path = zeros(n_machines,n_machines);
            
            for i = 1:length(ocs.coflows)
                %P(:,c.id) = (c.indicator*c.getFlowsVolume')./Bw'; % processing time
                %matrix, different from Demand matrix when fabric does not contain
                %one unit capacity links only
                c = ocs.coflows(i);
                D(:,i) = c.indicator*c.getFlowsVolume';
            end
            
            %% general step:
            for k = ocs.unfinished
                c_idx = find([ocs.coflows.id] == k);
                c = ocs.coflows(c_idx);
                % Update super coflow demand
                DS = DS+D(:,c_idx);
                % Get bottleneck demand of super coflow:
                DS_max = max(DS);
                % Update Demand of the super coflow on each path (ingress, egress):
                for f = c.flows
                    if f.volume > 0
                        links = f.links;
                        prev_demand = DS_path(links(1),links(2)-n_machines);
                        DS_path(links(1),links(2)-n_machines) = ...
                            prev_demand + f.volume;
                    end
                end
                % compute rate for each unfinished flow of c:
                j = ocs.index_bases(k);
                for f = c.flows
                    j = j+1;
                    if ocs.Flows(j).state
                        f_links = ocs.Flows(j).IO;
                        ingress = f_links(1);
                        egress  = f_links(2)-n_machines;
                        rate = min(max(round(DS_path(ingress,egress)/DS_max...
                            - cumulRate(ingress,egress),5),0)...
                            , min(ocs.B(f_links)));
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
                            % Update cumulRate on path
                            cumulRate(ingress,egress) = cumulRate(ingress,egress) ...
                                + rate;
                        end
                    end
                end
            end
            
            %% Work conservation
            
            % % count the number of unfinished flows per available links
            n_flows_per_link = zeros(1,length(ocs.B));
            for c = ocs.coflows
                j = ocs.index_bases(c.id);
                for f = c.flows
                    j = j+1;
                    if ocs.Flows(j).state
                        f_links = ocs.Flows(j).IO;
                        if prod(ocs.B(f_links))
                            n_flows_per_link(f_links) = ...
                                n_flows_per_link(f_links)+1;
                        end
                    end
                end
            end
            
            bw_used = zeros(1,length(ocs.B));
%             Rates_per_links = zeros(1,n_links);
%             Rates_per_links(1:n_machines) = sum(cumulRate,2);
%             Rates_per_links(n_machines+1:n_links) = sum(cumulRate);
            for k = ocs.unfinished
                c_idx = find([ocs.coflows.id] == k);
                c = ocs.coflows(c_idx);
                j = ocs.index_bases(k);
                for f = c.flows
                    j = j+1;
                    if ocs.Flows(j).state
                        f_links = ocs.Flows(j).IO;
                        if prod(ocs.B(f_links))&&prod(n_flows_per_link(f_links))
                            add_rate = min(ocs.B(f_links)...
                                ./n_flows_per_link(f_links));
                            %                         if prod(ocs.B(f_links))
                            %                             if ocs.Flows(j).rate > 0
                            %                                 add_rate = round(ocs.Flows(j).rate*...
                            %                                     min((ocs.B_origin(f_links)-ocs.B(f_links))...
                            %                                     ./ocs.B_origin(f_links)),5);
                            %                                 rate = ocs.Flows(j).rate + add_rate;
                            %                             end
                            % precision management
                            if add_rate < 1e-5
                                add_rate = 0;
                            end
                            if add_rate > 0
                                if ~ocs.Flows(j).active
                                    ocs.Flows(j).active = 1;
                                end
                                bw_used(f_links) = bw_used(f_links) ...
                                    + add_rate;
                                ocs.Flows(j).rate = ocs.Flows(j).rate ...
                                    + add_rate;
                            end
                        end
                    end
                end
            end
            
            % Update bandwidth accordingly
            ocs.B = ocs.B - bw_used;
            % precision management
            ocs.B(ocs.B<=1e-5) = 0;
            
            %% Heuristic: sort coflows by arrival times and then refill
            % in case of varys with deadlines: sort in EDF order:
            sorted_coflows = ocs.coflows;
            
%             if ocs.varys_dl
%                 % sort in EDF order
%                 dl = [ocs.coflows.deadline];
%                 [~,edf_order] = sort(dl);
%                 sorted_coflows = ocs.coflows(edf_order);
%             end
%             
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
            
%             if sum(is_skipped_coflow)
%                 % fair sharing among the skipped coflows:
%                 
%                 % % count the number of unfinished flows per available links
%                 n_flows_per_link = zeros(1,length(ocs.B));
%                 for c = ocs.coflows(is_skipped_coflow)
%                     j  = ocs.index_bases(c.id);
%                     for f = c.flows
%                         j = j+1;
%                         if ocs.Flows(j).state
%                             f_links = ocs.Flows(j).IO;
%                             if prod(ocs.B(f_links))
%                                 n_flows_per_link(f_links) = n_flows_per_link(f_links)+1;
%                             end
%                         end
%                     end
%                 end
%                 
%                 % % fair sharing among skipped coflows in ascending order
%                 % % of their i_CCT_initial
%                 skipped_coflow_idx(~skipped_coflow_idx) = [];
%                 bw_used = zeros(1,length(ocs.B));
%                 for c_idx = skipped_coflow_idx
%                     c = ocs.coflows(c_idx);
%                     j = ocs.index_bases(c.id);
%                     for f = c.flows
%                         j = j+1;
%                         if ocs.Flows(j).state
%                             f_links = ocs.Flows(j).IO;
%                             if prod(ocs.B(f_links))&&prod(n_flows_per_link(f_links))
%                                 rate = min(ocs.B(f_links)./n_flows_per_link(f_links));
%                                 % precision management
%                                 if rate <= 1e-5
%                                     rate = 0;
%                                 end
%                                 ocs.Flows(j).rate = rate;
%                                 if rate
%                                     % update active status of flow
%                                     if ~ocs.Flows(j).active
%                                         ocs.Flows(j).active = 1;
%                                     end
%                                     bw_used(f_links) = bw_used(f_links) + rate;
%                                 end
%                             end
%                         end
%                     end
%                 end
%                 
%                 % % Update bandwidth accordingly
%                 ocs.B = ocs.B - bw_used;
%                 % precision management
%                 ocs.B(ocs.B<=1e-5) = 0;
%                 
%             end
%             
%             %% Heuristic: sort coflows by arrival times and then refill
%             % in case of varys with deadlines: sort in EDF order:
%             sorted_coflows = ocs.coflows;
%             
%             if ocs.varys_dl
%                 % sort in EDF order
%                 dl = [ocs.coflows.deadline];
%                 [~,edf_order] = sort(dl);
%                 sorted_coflows = ocs.coflows(edf_order);
%             end
%             
%             for c = sorted_coflows
%                 j = ocs.index_bases(c.id);
%                 for f = c.flows
%                     j = j+1;
%                     if ocs.Flows(j).state
%                         f_links = ocs.Flows(j).IO;
%                         if prod(ocs.B(f_links))
%                             rate = min(ocs.B(f_links));
%                             if rate <= 1e-5
%                                 rate = 0;
%                             end
%                             ocs.Flows(j).rate = ocs.Flows(j).rate + rate;
%                             if rate
%                                 if ~ocs.Flows(j).active
%                                     ocs.Flows(j).active = 1;
%                                 end
%                                 for l = f_links
%                                     ocs.B(l) = ocs.B(l)-rate;
%                                     if ocs.B(l) <= 1e-5
%                                         ocs.B(l) = 0;
%                                     end
%                                 end
%                             end
%                         end
%                     end
%                 end
%             end
            
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

