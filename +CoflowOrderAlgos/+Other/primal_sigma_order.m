function primal_order = primal_sigma_order(fabric,coflows)

% LAST MODIFIED 2021/05/10

% Computes w_star, the minimum value of w for which the optimisation problem of
% minimizing the average CCTs of coflows is feasible

% Retruns w_star

% Parameters:
% - fabric: the Fabric ojbect representing the network
% - coflows: an array of Coflow objects within the fabric

% Vaibhav Gupta, Cedric Richier, LIA
% (c) LIA, 2021


% number of links
n_links = fabric.numFabricPorts;

% Link capacities (Bandwidth)
tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
Bw = [tmp.linkCapacity];

% Number of coflows
n_coflows = length(coflows);

% get initial ids
initial_IDs = [coflows.id];
% re_indexing
for k = 1:length(coflows)
    coflows(k).id = k;
end
    

% Demand of each coflow on each link:
D = zeros(n_links, n_coflows);

% Links used by each coflows:
L_K = zeros(n_links,n_coflows);

% Compute D
for c = coflows
    D(:,c.id) = (c.indicator*[c.flows.volume]')./Bw';
    L_K(:,c.id) = D(:,c.id)>0;
end

% Find bottlenecks candidates
isolations = max(D);
volumes = sum(D)./2;


isolation_rates = volumes./isolations;
[~,primal_order] = sort(isolation_rates,'descend');

primal_order = initial_IDs(primal_order);

% re indexing coflows as initial
for k = 1:length(coflows)
    coflows(k).id = initial_IDs(k);
end

end

