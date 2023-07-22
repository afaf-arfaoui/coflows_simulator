% Parameters:
% - method: name of DCoflow variant: 'heu_v2_min_link', 
%   'heu_v2_min_sum_negative', 'heu_v2_min_sum_congested'
% - fabric: the Fabric ojbect representing the network
% - coflows: an array of Coflow objects within the fabric
% - ocs: an OCS object representing the Online Coflow Simulator

% Quang-Trung Luu, LIA & LAAS
% Modified by Cedric Richier on 2022.01.10, LIA
% (c) LIA-LAAS, 2022



function outputs = DCoflow_online(fabric, coflows, ocs)
% Implements the DCoflow algorithm in an online context

method = ocs.DCoflow_method;
outputs.method = method;
%time_unit = 1; % time unit expressed in number of seconds
time_unit = ocs.sim_clock.time_unit;


%% Initializations:
% Number of links
n_links = fabric.numFabricPorts;

% Capacity of each link expressed in number of volume units per second
portCapacity = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
portCapacity = [portCapacity.linkCapacity];

% Number of coflows
n_coflows = length(coflows);

% Deadline of coflows expressed in remaining number of seconds (can be
% negative in case of late deadline)
deadlines = round(([coflows.deadline]-ocs.sim_clock.time)*time_unit,5);

% Unscheduled coflows IDs:
ID_list = [coflows.id];
unsch_coflow_ids = ID_list; % S = [n]

% Demand of each coflow on each link:
D_ini = zeros(n_links, n_coflows);

% Scheduling order
order = zeros(1,n_coflows);

% Compute D: processing time matrix (processing time of each coflow per
% link)
for idx = 1:n_coflows
    c = coflows(idx);
    D_ini(:,idx) = (c.indicator*c.getFlowsVolume')./portCapacity';
end

D = D_ini; % keep track of D_ini

outputs.D_ini = D_ini;
outputs.bottleneck = zeros(1, n_coflows);

k = n_coflows;
%order_star = []; % keep track of rejected coflows
%last_ok = []; % coflows in the IF of the algorithm


%=================================================================================
% PART 1: COFLOW ORDERING 
%=================================================================================

while ~isempty(unsch_coflow_ids)
    
    % Find the most bottlenecked links:
    cumulD = sum(D,2);
    b_candidates = find(cumulD == max(cumulD));
    
    % Randomly pick one such link:
    r_ind = randi(length(b_candidates));
    b = b_candidates(r_ind);   
 
    
    %% TEST: to match implementation of example in sincronia paper:
    % b = max(b_canditates(b_canditates<=4));
    % end TEST
    %%
    
    % Coflows that use bottleneck
    Sb = D(b,:) > 0; % coflows using b (S_b)
    %Sb_id = S(Sb);
    
    % Coflows that have sum_{j in S_b} p_{jb} Vb/Bb <= DL_j
    % (any coflow j that can finish before deadline when scheduled last)
    dl_feasible = deadlines >= cumulD(b);
    set_idx     = Sb & dl_feasible;
    
    if sum(set_idx)
        
        % Take only the coflow with largest deadline in set_idx
        idx_candidates = find((deadlines == max(deadlines(set_idx))) & set_idx);
        
        % randomly pick one candidate
        r_ind = randi(length(idx_candidates));
        j_star_idx = idx_candidates(r_ind);
        
        % Schedule j_star last
        order(k) = coflows(j_star_idx).id; 

        % Remove j_star from set of unscheduled coflows
        unsch_coflow_ids = setdiff(unsch_coflow_ids, order(k)); 
        
        % Set demand of last scheduled coflow to zero
        D(:, j_star_idx) = 0;     
        k = k - 1; % update k
        
    else
        % x_star = argmin psi_{ell,x}
        psi = inf(1,n_coflows);
        
        % Loop over active coflows over link b
        for c_idx = 1:n_coflows
            if Sb(c_idx)
                c = coflows(c_idx);
                D_c = D(:, c_idx); % column of coflow c_idx in matrix D
                L_c = sum(c.indicator,2) > 0; % links used by coflow c
                psi_c_all = D_c(L_c).* ...
                    (deadlines(c_idx) - cumulD(L_c));
                
                if strcmp(method, 'heu_v2_min_link')
                    psi_c_row = min(psi_c_all);     % take directly the minimum element of each row
                    
                elseif strcmp(method, 'heu_v2_min_sum_negative')
                    psi_c_all(psi_c_all > 0) = 0;   % only summing negative elements
                    psi_c_row = sum(psi_c_all);
                    
                elseif strcmp(method, 'heu_v2_min_sum_congested')
                    % Check if links used by coflow c are congested ~bottleneck
                    is_congested = cumulD(L_c) >= 0.7*cumulD(b);
                    psi_c_row = psi_c_all(is_congested);
                    psi_c_row = sum(psi_c_row);
                end
                
                psi(c_idx) = psi_c_row;
                % TEST with weights (2022.27.01)
                %psi(c_idx) = c.weight * psi_c_row;
            end
        end
        
        % Select coflow x_star to reject
        x_candidates_idx = find((psi == min(psi)) & Sb);
        
        x_star_idx = x_candidates_idx(1); % take the first in x_star (update 07/10/2021)
        
        order(k) = coflows(x_star_idx).id;

        % Remove x_star from the set of unscheduled coflows
        unsch_coflow_ids = setdiff(unsch_coflow_ids, order(k));
        
        % Set demand of last scheduled (removed) coflow to zero
        D(:, x_star_idx) = 0; 
        k = k - 1; % update k   
    end
    
end % end while 

outputs.ini_order = order;
[~,ini_order_idx] = ismember(order,ID_list);
outputs.ini_deadlines = deadlines;

%=================================================================================
% PART 2: REMOVE LATE COFLOWS FROM THE ORDER 
%=================================================================================

% Initial guess, with only CCTs, without backtracking
ini_ccts = utils.evalCCTfromOrder(fabric, coflows, order);
ini_zn = (ini_ccts <= deadlines(ini_order_idx));
ini_nac = sum(ini_zn);           
ini_order_star = order(~ ini_zn); % sigma^star: coflows that do not meet their deadlines
%ini_order_star = intersect(order,ID_list(~ini_zn),'stable');
order_star = ini_order_star;
%pred_rejects = [];  % final sigma^star
pred_rejects = zeros(1,n_coflows); % final sigma^star
k_pred_rejects = 0;

% Backtrack to remove rejected coflows from the order
while ~isempty(order_star)
    kstar = order_star(1);              % first coflow in sigma^star
    kstar_pos = find(order == kstar);    % position of k^star in sigma

    % Calculate the CCT of sigma(k^star)
    temp = utils.evalCCTfromOrder(fabric, coflows, order(1:kstar_pos));
    kstar_idx = ID_list == kstar; % index of kstar in coflows array
    kstar_cct = temp(kstar_pos); % note: the indexes in temp are the same as in order
    %kstar_deadline = coflows(kstar_idx).deadline;
    kstar_deadline = deadlines(kstar_idx);

    %fprintf("c%d: cct = %.4f\n", kstar, kstar_cct);

    if kstar_cct > kstar_deadline
        % Remove k^star from sigma
        order(kstar_pos) = []; 
        %pred_rejects = [pred_rejects, kstar];
        k_pred_rejects = k_pred_rejects+1;
        pred_rejects(k_pred_rejects) = kstar;
    end
    % Remove k^star from sigma^star
    order_star(1) = []; 
end   


% Save
[~,order_idx] = ismember(order,ID_list);
%outputs.ini_ccts = ini_ccts(ini_order_idx);
outputs.ini_ccts = ini_ccts;
outputs.deadlines = deadlines(order_idx);
outputs.ini_zn = ini_zn;
outputs.ini_nac = ini_nac;           
outputs.ini_order_star = ini_order_star; % sigma^star: coflows that do not meet their deadlines
outputs.order_star = order_star;
outputs.pred_rejects = pred_rejects(pred_rejects>0);

% Final predicted results
outputs.pred_zn      = ~ismember(outputs.ini_order, outputs.pred_rejects);
outputs.pred_accepts = outputs.ini_order(outputs.pred_zn);
outputs.pred_ccts    = outputs.ini_ccts(outputs.pred_zn); % predicted ccts (of only accepted coflows)
outputs.pred_nac     = length(order);
outputs.order 		 = order; % final scheduling order




end