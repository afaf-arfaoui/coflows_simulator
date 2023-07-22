% Quang-Trung Luu & Cedric Richier, LIA
% (c) LIA, 2022.02.18

function OptimOut = cs_mha_online(fabric, coflows, ocs)

% rng(OptimIn.seed_id);  % fix randomness scheme
OptimOut = struct;  % output struct

% Time unit in number of seconds
time_unit = ocs.sim_clock.time_unit;


%============================================================================
% Reset the ids of coflows (for online simulation) => Reset again at the end
original_ids = [coflows.id];
for i = 1:length(coflows)
   coflows(i).id = i;
end
%============================================================================



%% Initializations:
% Number of links
n_links = fabric.numFabricPorts;

% Capacity of each link
portCapacity = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
portCapacity = [portCapacity.linkCapacity];

% Number of coflows
n_coflows = length(coflows);

% Unscheduled coflows IDs:
S = [coflows.id];

% Gathering deadlines of coflows
deadlines = round(([coflows.deadline] - ocs.sim_clock.time)*time_unit,5);

%-----------------------------------------------
% Relative deadline w.r.t. the current time slot
% deadlines = deadlines - current_slot(2);
%-----------------------------------------------

Tab.deadlines = deadlines';
Tab.id = S';

% Short Tab wrt deadlines
Tab = struct2table(Tab); % convert the struct array to a table
Tab = sortrows(Tab, 'deadlines'); % sort the table by 'deadlines'
Tab = table2struct(Tab);

% Demand of each coflow on each link:
D_ini = zeros(n_links, n_coflows);

% Scheduling order
%order = zeros(1,n_coflows);

% Compute D:
for c = coflows
    D_ini(:, c.id) = (c.indicator*c.getFlowsVolume')./portCapacity'; % original
	% D_ini(:, c.id) = c.indicator*[c.flows.remainingVolume]';
end
D = D_ini; % keep track of D_ini

OptimOut.D_ini = D_ini;
OptimOut.bottleneck = zeros(1, n_coflows);


%%

% Initialization
S_final = []; % set of admitted coflows
E_final = [];  % set of rejected coflows

for ell = 1:n_links
    
    % Processing time of sorted coflows on ell
    D_ell = D(ell, [Tab.id]); 

    % Keep only sorted coflows having positive load on link ell
    tmp = D_ell > 0;  % set of sorted coflows on ell

    D_ell = D_ell(tmp);            % processing times
    S_ell = [Tab(tmp).id];         % real id in coflows
    T_ell = [Tab(tmp).deadlines];  % deadlines
    S_ell_ini = S_ell;             % keep track of S_ell
        
    E_ell = [];
    flag = true;
    
    while true
         
        % Completion times (cumulative)
        D_ell_cum = cumsum(D_ell);  % completion times 
        dl_violation = D_ell_cum > T_ell;
        
        if sum(dl_violation) == 0
            break;
        end
        k = find(dl_violation == 1, 1); % first violated coflow

        % take the coflow having largest volume in 1:k
        % x* <- argmax(p_i, i <= k)
        S_until_k = S_ell(1:k);
        D_until_k = D_ell(1:k);
        x_star = S_until_k(D_until_k == max(D_until_k));
        x_star = x_star(1); % take the first in x_star (update 07/10/2021)

        % Remove xstar from S and D
        xstar_id = S_ell == x_star;
        S_ell(xstar_id) = [];
        D_ell(xstar_id) = [];
        T_ell(xstar_id) = [];
        
        E_ell(end+1) = x_star;
    end
    % E_ell = setdiff(S, S_ell); % modify E_ell
    S_ell_all{ell} = S_ell;
    E_ell_all{ell} = E_ell;
    
    % Final sets
    E_final = union(E_final, E_ell);
    S_final = setdiff(S, E_final);
    
end

% Sort S_final w.r.t deadlines
S_final = [Tab(ismember([Tab.id], S_final)).id];


% Sort E_final w.r.t max(all ell) p_{ell,i}/T_i
if ~isempty(E_final)
    Tab2 = struct;
    Tab2.id = [Tab.id]';
    tmp = max(D); % max volume of each coflow in all port 
    %Tab2.criteria = (max(D)./([Tab.deadlines]))';
    Tab2.criteria = ((tmp(Tab2.id))./([Tab.deadlines] + 0.001))';

    % Short tmp wrt criteria
    Tab2 = struct2table(Tab2); % convert the struct array to a table
    Tab2 = sortrows(Tab2, 'criteria'); % sort the table by 'deadlines'
    Tab2 = table2struct(Tab2);
    
    % Sort E_final w.r.t the order of Tab2.id
    E_final = [Tab2(ismember([Tab2.id], E_final)).id];
end

OptimOut.S_final = S_final;
OptimOut.E_final = E_final;
order = [S_final, E_final];


%============================================================================
% Return the real order and the real ids of coflows
order = original_ids(order);
for i = 1:length(coflows)
   coflows(i).id = original_ids(i);
end
%============================================================================


OptimOut.order = order;


end

