% Supercoflow demand:
n_links = ocs.fabric.numFabricPorts;
n_coflows = length(ocs.coflows);
n_machines = n_links/2;
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
    C = coflows(i);
    D(:,i) = C.indicator*C.getFlowsVolume';
end

%% general step:
for k = ocs.unfinished
    % Update super coflow demand
    DS = DS+D(:,c_idx);
    % Get bottleneck demand of super coflow:
    DS_max = max(DS);
    % Update Demand of the super coflow on each path (ingress, egress):
    for f = c.flows
        if f.volume > 0
            links = f.links;
            prev_demand = DS_path(links(1),links(2)-n_machines);
            DS_path(links(1),links(2)-n_machines) = prev_demand + f.volume;
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
                cumulRate(ingress,egress) = cumulRate(ingress,egress) + rate;
            end
        end
    end
end

%% Work conservation
bw_used = zeros(1,length(ocs.B));
Rates_per_links = zeros(n_links,1);
Rates_per_links(1:n_machines,1) = sum(cumulRate,2);
Rates_per_links(n_machines+1:n_links) = sum(cumulRate);
for k = ocs.unfinished
    j = ocs.index_bases(k);
    for f = c.flows
        j = j+1;
        if ocs.Flows(j).state
            f_links = ocs.Flows(j).IO;
            if prod(ocs.B(f_links))
                rate = ocs.Flows(j).rate*(1 + ...
                    min(ocs.B(f_links)./Rates_per_links(f_links,1)));
                if rate
                    if ~ocs.Flows(j).active
                        ocs.Flows(j).active = 1;
                    end
                    bw_used(f_links) = bw_used(f_links) + rate;
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
%%
