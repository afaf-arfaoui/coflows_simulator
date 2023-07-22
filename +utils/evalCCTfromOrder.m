function cct = evalCCTfromOrder(fabric,coflows,order)

% Number of colfows
n_coflows = length(coflows);

% Number of links
n_links = fabric.numFabricPorts;

% Link capacities
tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
B = [tmp.linkCapacity];

cct = zeros(1,n_coflows);
ID_list = [coflows.id];
[~,order_idx] = ismember(order,ID_list);

D = zeros(n_links, n_coflows);

for c_idx= order_idx
    cc = coflows(c_idx);
    D(:,c_idx) = (cc.indicator*[cc.getFlowsVolume]')./B';
end

for c_idx = flip(order_idx)
    c = coflows(c_idx);
    L_c = sum(c.indicator,2) > 0;
    cct(c_idx) = max(sum(D,2).*L_c); 
    D(:,c_idx) = 0;
end

% reorder vector cct w.r.t the order (19/11/2021)
cct = cct(order_idx);

end