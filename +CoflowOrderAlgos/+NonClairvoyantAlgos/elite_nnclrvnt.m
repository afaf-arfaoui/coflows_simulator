function order = elite_nnclrvnt(fabric,coflows,ocs)

% LAST MODIFIED 2022/06/01

% Returns the coflow IDs sorted by descending priority in a non clairvoyant
% scenario

% Parameters:
% - fabric: the Fabric ojbect representing the network
% - coflows: an array of Coflow objects within the fabric
% - ocs: an online coflow simulator object

% Cedric Richier, LIA
% (c) LIA, 2022

% tuning parameter
ppower=ocs.elite_ppower; % power assigned to the aggregated volume on links 
                         % that are used by more than one colfow

%% Initializations:
% Number of links
n_links = fabric.numFabricPorts;

% Number of coflows
n_coflows = length(coflows);

% Unscheduled coflows IDs:
unsch_coflow_ids = [coflows.id];

% Demand of each coflow on each link:
D = zeros(n_links, n_coflows);

% Permutation
order = zeros(1,n_coflows);

% Compute D:
t_vect = ocs.t_vect;

c_idx = 0;
for c = coflows
    c_t_lvls = c.addParam.thresh_lvl_vct;
    c_idx = c_idx+1;
    D(c_t_lvls>0,c_idx) = t_vect(c_t_lvls(c_t_lvls>0));
end

% Weights of coflows
%W = ones(1,n_coflows);
W = [coflows.weight];

% Metric used to compute a score for each unscheduled coflow
Z = zeros(1,n_coflows);

% index in permutation:
k = n_coflows;

%% Main loop: select the coflow to schedule last
while k > 0
    total_vol = sum(sum(D(1:size(D,1)/2,:))); % total volume in the network
    total_vol_links = sum(D,2); % total volume on each link
    
    
    % Update the metric Z for remaining coflows during the current iteration:
    unsch_coflow_ids = setdiff(unsch_coflow_ids,order);
    
    for c = coflows(ismember([coflows.id],unsch_coflow_ids))
        c_idx = find([coflows.id] == c.id);
        num_coflows_on_link = sum(D ~= 0, 2); 
        % number of coflows sharing each link
        % counting only links that coflow c shares with other
        % coflows, links used by coflow c alone should not be counted since
        % it is not in conflict with any other coflow on these links
        
      % W(c.id) = 1 - 0.5 / (L * total_vol^2) * sum(total_vol_links(num_coflows_on_link > 1).^2.* ...
         %   D(num_coflows_on_link > 1,c.id) ./ max(D(num_coflows_on_link > 1,:)')');
         
         Z(c_idx) =  1./W(c_idx).*sum(total_vol_links(num_coflows_on_link > 1).^ppower.* ...
           D(num_coflows_on_link > 1,c_idx) ./ max(D(num_coflows_on_link > 1,:)')');
    end
    
    % Find the most bottlenecked links:
    cumulD = sum(D,2);
    b_links = find(cumulD == max(cumulD)); 
    
    c_candidates = [];
    % finding coflows using bottlenecks links
    for c = coflows(ismember([coflows.id],unsch_coflow_ids))
        linkUsedBy_c = unique([c.flows.links]);
        if sum(ismember(b_links,linkUsedBy_c)) > 0
            c_idx = find([coflows.id] == c.id);
            %c_candidates = [c_candidates c];
            c_candidates = [c_candidates c_idx];
        end
    end
   
    % finding among c_candidates those with smallest weights
    candidates_ind = find(Z == max(Z(c_candidates)));
    
    % if more than 1 choose randomly
    r_ind = randi(length(candidates_ind));
    c_star_idx = candidates_ind(r_ind);
    order(k) = coflows(c_star_idx).id;

    
    % Set demand of last scheduled coflow to zero:
    D(:,c_star_idx) = 0;
    Z(c_star_idx) = -1;
    
    % Set k:
    k = k-1;
end

end