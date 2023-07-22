function sigma_order = dual_elite(fabric,coflows, varargin)
% AUTHOR : Afaf & Cedric
% LAST MODIFIED 2022/06/02

% ordering algorithm: Longest Weighted Processing Time on Bottleneck Last

% Returns the coflow IDs sorted by descending priority given by the LWPTBL
% algorithm

% Parameters:
% - fabric: the Fabric ojbect representing the network
% - coflows: an array of Coflow objects within the fabric
% - alpha (optional): value of parameter alpha that sets links to consider
%   during a given step of the algorithm. If the charge of the bottleneck
%   in a given step is P_mu, then the links l to consider must verify P_l
%   >= alpha*P_mu
% - beta (optional): value of parameter beta that sets links to consider
%   during a given step of the algorithm. If the charge of the heaviest
%   flow on a link l is P_l* in a given step, then l is in L_k for a coflow
%   k if P_l_k >= beta x P_l*

% Cedric Richier, Afaf Arfaoui
% (c) LIA, 2021


%% Manage inputs
% Parameter alpha for alpha-charged links, i.e: l | P_l > alpha*P_mu
alpha = 0.7;
beta = 0;
ppower = 5;
switch nargin
    case 3
        alpha = varargin{1};
    case 4
        alpha = varargin{1};
        beta = varargin{2};
    case 5
        alpha = varargin{1};
        beta = varargin{2};
        ppower = varargin{3};
end

%% Initializations:
% Number of links
n_links = fabric.numFabricPorts;

% Link capacities (Bandwidth)
tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
Bw = [tmp.linkCapacity];

% Number of coflows
n_coflows = length(coflows);

% re-indexing coflows from one to the number of coflows in the system:
original_ids = [coflows.id];
for i = 1:length(coflows)
    coflows(i).id = i;
end

% Unscheduled coflows IDs:
unsch_coflow_ids = [coflows.id];

% Full rate processing time of each coflow on each link:
P = zeros(n_links, n_coflows);

% Links used by each coflow:
L_K_origin = zeros(n_links,n_coflows);

% Compute P and L_ks:
for c = coflows
    P(:,c.id) = (c.indicator*c.getFlowsVolume')./Bw';
    L_K_origin(:,c.id) = P(:,c.id)>0;
end

% Update L_K for links used by a single coflow:
L_K = L_K_origin;
L_K((repmat(sum(L_K,2),1,n_coflows) == 1)&L_K) = 0;

% Permutation
sigma_order = zeros(1,n_coflows);

% Coflows' weights (initialized to one)
W = ones(1,n_coflows);

% Links' weights per coflow (initialized to one)
%Alpha_L_K = ones(n_links,n_coflows);
Alpha_L_K = P.^ppower;
% Alpha_L_K = P.*P; % alpha_l_k = (P_l_k)^2

% index in permutation = current number of coflows to schedule
n = n_coflows;

%% Main loop: starting by finding the last coflow to schedule
while n
    
    % Schedule isolated coflows if necessary:
    isolated_ids = unsch_coflow_ids(~sum(L_K(:,unsch_coflow_ids)));
    if ~isempty(isolated_ids)
        for k = isolated_ids
            
            % Set sigma_order
            sigma_order(n) = k;
            
            % Update the set of unsceduled coflows
            unsch_coflow_ids = setdiff(unsch_coflow_ids,sigma_order(n));
            
            % Set demand of last scheduled coflow to zero:
            P(:,sigma_order(n)) = 0;
            
            % Update L_K_origin
            L_K_origin(:,sigma_order(n)) = 0;
            
            % Decrementing n:
            n = n-1;
        end
        continue;
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
    % Set of links to consider: L_n = all links by default
    L_n = ones(n_links,1);
    
    % Find bottlenecks:
    cumulP = sum(P,2);
    P_mu = max(cumulP);
    links_B  = cumulP == P_mu;
    
    % Define alpha-charged links for current step:
    L_alpha = cumulP >= alpha*P_mu;
    
    % Initializing L_beta
    L_beta_K = L_K_origin;
    
    % Find heaviest charge for each link:
    P_star = max(P,[],2);
    
    % Set beta-charged 
    for l = 1:n_links
        L_beta_K(l,:) = L_K_origin(l,:)&(P(l,:) >= beta * P_star(l));
    end

    % Initialize values of the metric for each coflow:
    metric = nan(1,n_coflows);

    %% Find a coflow k* that minimizes the metric:
    
    % Compute values of the metric for each unscheduled coflow:
    uses_bot = zeros(1,n_coflows); % says if a given coflow uses a bottleneck
    for k = unsch_coflow_ids % Choose k* among unscheduled coflows
        uses_bot(k) = sum(L_K_origin(:,k)&links_B); % k* should use one bottleneck
        if uses_bot(k)
            % Update set of links L_k for each unscheduled coflow (related to
            % constraints of alpha-charge and beta-charge:
            tmp_metric = nan(1,n_coflows);
            L_k_n = L_K(:,k)&L_alpha&L_beta_K(:,k)&L_n; % Set of links in L_n that are valuable to consider for coflow k
            for kk = unsch_coflow_ids
                if kk ~= k
                    tmp_metric(kk) = W(kk)- sum(W(k)*(P(L_k_n,kk)./P(L_k_n,k)).*...
                        (Alpha_L_K(L_k_n,k)/sum(Alpha_L_K(L_k_n,k))));
                end
            end            
            metric(k) = min(tmp_metric);
        end
    end
    
    max_metric_value = max(metric);
    
    %% Ensure non negativity for the max value of the metric
    while max_metric_value < 0
        
         % Find the least utilized links over L_n:
        least_utilized_links = find(cumulP == min(cumulP(cumulP>0&L_n)));
        
        % Choose one of them at random:
        rand_idx = randi(length(least_utilized_links));
        l_tilda = least_utilized_links(rand_idx);
        
        % Update L_n:
        L_n(l_tilda) = 0;
        
        % Update values of the metric for each unscheduled coflow:
        for k = unsch_coflow_ids % Choose k* among unscheduled coflows
            if uses_bot(k) && L_K(l_tilda,k) % Update metric's value only if k uses the removed link                
                tmp_metric = nan(1,n_coflows);
                L_k_n = L_K(:,k)&L_alpha&L_beta_K(:,k)&L_n; % Set of links in L_n that are valuable to consider for coflow k
                for kk = unsch_coflow_ids
                    if kk ~= k
                        tmp_metric(kk) = W(kk)- sum(W(k)*(P(L_k_n,kk)./P(L_k_n,k)).*...
                            (Alpha_L_K(L_k_n,k)/sum(Alpha_L_K(L_k_n,k))));
                    end
                end
                metric(k) = min(tmp_metric);
            end
        end
        
        max_metric_value = max(metric);
        
    end
    
    % Find all candidates for k*:
    k_star_candidates = find(metric == max_metric_value);
    
    % Randomly select a coflow among the candidates to schedule at position n:
    rand_idx = randi(length(k_star_candidates));
    sigma_order(n) = k_star_candidates(rand_idx);
    
    %% Scale the weights:
    
    % Update the weights of unscheduled coflows
    L_kstar_n = L_K(:,sigma_order(n))&L_alpha&L_beta_K(:,sigma_order(n))&L_n;
    k_star_factor = (W(sigma_order(n))/sum(Alpha_L_K(L_kstar_n,sigma_order(n))))*...
        (Alpha_L_K(L_kstar_n,sigma_order(n))./P(L_kstar_n,sigma_order(n)));
    for k = unsch_coflow_ids        
        W(k) = W(k) - sum(P(L_kstar_n,k).*k_star_factor);
    end
    
    % Update the set of unsceduled coflows
    unsch_coflow_ids = setdiff(unsch_coflow_ids,sigma_order(n));
    
    %% Setting the next iteration:
    
    % Set demand of last scheduled coflow to zero:
    P(:,sigma_order(n)) = 0;
    
    % Set the weight of links per coflow to zero for the last scheduled
    % coflow:
    Alpha_L_K(:,sigma_order(n)) = 0;
    
    % The last scheduled coflow does not use links anymore:
    L_K(:,sigma_order(n)) = 0;
    L_K_origin(:,sigma_order(n)) = 0;
    
    % Update L_K for links used by a single coflow:
    L_K((repmat(sum(L_K,2),1,n_coflows) == 1)&L_K) = 0;
    
    % Decrementing n:
    n = n-1;
end

% re-order coflows as original:
sigma_order = original_ids(sigma_order);
for i = 1:length(coflows)
    coflows(i).id = original_ids(i);
end

end




