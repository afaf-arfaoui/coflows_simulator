function sigma_order = Utopia_DRF(fabric,coflows,varargin)
%Sort coflows in in ascending order of their completion under DRF
%allocation

%% Optional args
ocs = [];
if nargin == 3
    ocs = varargin{1};
end

%% Initializations:
% Number of coflows
n_coflows = length(coflows);

% Weights of coflows
%weights = [coflows.weight];

% Number of links
n_links = fabric.numFabricPorts;

% Link capacities
%tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
%B = [tmp.linkCapacity];

% re-indexing coflows from one to the number of coflows in the system:
original_ids = [coflows.id];
for i = 1:length(coflows)
    coflows(i).id = i;
end

% Permutation
%sigma_order = zeros(1,n_coflows);

% Demand of each coflow on each link:
D = zeros(n_links, n_coflows);

% Max demand of each coflow
max_D = zeros(n_coflows,1);

% Correlation of coflow k on link i is c_i_k = d_i_k/max_d_k:
C = zeros(n_links,n_coflows);

% Full rate processing time of each coflow on each link:
%P = zeros(n_links, n_coflows);

% Compute Demand matrix D
for c = coflows
    %P(:,c.id) = (c.indicator*c.getFlowsVolume')./Bw'; % processing time
    %matrix, different from Demand matrix when fabric not contains one unit 
    %capacity links only
    k = c.id;
    D(:,k) = c.indicator*c.getFlowsVolume';
    max_D(k) = max(D(:,k));
    C(:,k)   = D(:,k)./max_D(k);
end

% Virtual Finish Times of new coflows
vft = zeros(n_coflows,1);
if ~isempty(ocs)
    P_star = ocs.prev_P_star;
    for c = coflows
        k = c.id;
        if c.addParam.virtual_finish_time == -1
            prev_vt = ocs.prev_virtual_time;
            arrival_time = c.arrival;
            virtual_time = prev_vt + P_star*(arrival_time...
                - ocs.prev_arrival_time)*ocs.sim_clock.time_unit;
            c.addParam.virtual_finish_time = virtual_time + max_D(k);
            ocs.prev_virtual_time = virtual_time;
            ocs.prev_arrival_time = arrival_time; 
        end
        vft(k) = c.addParam.virtual_finish_time;
    end
end

%% Compute DRF order (in offline, it follows the ascending order of D_max):
if ~isempty(ocs)
    [~,sigma_order]   = sort(vft);
    % Compute P* for next arrival: progress under DRF
    ocs.prev_P_star = 1/max(sum(C,2));
else
    [~,sigma_order] = sort(max_D);
end

%% re-indexing coflows as original:
sigma_order = original_ids(sigma_order);
for i = 1:length(coflows)
    coflows(i).id = original_ids(i);
end

end

