function sincronia_order = sincronia_BSSI(fabric,coflows)
%% Sincronia ordering: Bottleneck-Select-Scale-Iterate Algorithm

% Returns the coflow IDs sorted by descending priority given by the BSSI
% algorithm from sincronia paper

% Parameters:
% - fabric: the Fabric ojbect representing the network
% - coflows: an array of Coflow objects within the fabric

% Cedric Richier, LIA
% (c) LIA, 2020

% LAST MODIFIED 11/12/2020

%% Initializations:
% Number of links
n_links = fabric.numFabricPorts;

% Number of coflows
n_coflows = length(coflows);

% Link capacities (Bandwidth)
tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
B = [tmp.linkCapacity];

% Unscheduled coflows IDs:
unsch_coflow_ids = [coflows.id];

% Ignored (empty) coflows
empty_coflows = false(1,n_coflows);

% Demand of each coflow on each link:
D = zeros(n_links, n_coflows);

% Permutation
sincronia_order = zeros(1,n_coflows);

% Compute D (processing times of each coflow on each link):
for c = coflows
    %D(:,c.id) = c.indicator*[c.flows.volume]';
    c_idx     = find(unsch_coflow_ids == c.id);
    D(:,c_idx) = (c.indicator*c.getFlowsVolume')./B';
    empty_coflows(c_idx) = ~sum(D(:,c_idx));       
end

% Schedule empty coflows first
sincronia_order(1:sum(empty_coflows)) = unsch_coflow_ids(empty_coflows);

% update unscheduled coflows if there are some coflows to ignore
unsch_coflow_ids(empty_coflows) = [];


% weights (initialized to one)
%W = ones(1,n_coflows);
W = [coflows.weight];

% Last index in permutation
k = n_coflows;

%% Main loop: starting by finding the last coflow to schedule
while ~isempty(unsch_coflow_ids)
    
    % Find the most bottlenecked links:
    cumulD = sum(D,2);
    b_canditates = find(cumulD == max(cumulD));
    % Randomly pick one such link:
    r_ind = randi(length(b_canditates));
    b = b_canditates(r_ind);   
    %% TEST: to match implementation of example in sincronia paper:
%    b = max(b_canditates(b_canditates<=4));
    % end TEST
    %%
    
    % Select weighted largest coflow to schedule last
    % argmin w_c/D_c_b: the min is computed among coflows that use link b
    set_idx = find(D(b,:)>0);    
    c_candidates_idx = find( W./D(b,:) == min(W(set_idx)./D(b,set_idx)));
    % Randomly pick one such coflow:
    r_ind = randi(length(c_candidates_idx));
    c_bar_idx = c_candidates_idx(r_ind);
    sincronia_order(k) = coflows(c_bar_idx).id;
    %perm(k) = c_id;
    
    % Scale the weights:
    unsch_coflow_ids = setdiff(unsch_coflow_ids,sincronia_order(k));
    for c = coflows(ismember([coflows.id],unsch_coflow_ids))
        c_idx = find([coflows.id] == c.id);
        W(c_idx) = W(c_idx) - W(c_bar_idx)*D(b,c_idx)/D(b,c_bar_idx);
    end
    
    % Set demand of last scheduled coflow to zero:
    D(:,c_bar_idx) = 0;
    W(c_bar_idx) = 1;
    
    % Set k:
    k = k-1;
end

end




