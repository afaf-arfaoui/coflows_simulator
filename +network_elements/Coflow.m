classdef Coflow < handle & matlab.mixin.Heterogeneous
    
    % AUTHOR: Afaf & Cedric
    % LAST MODIFIED: 18/05/2021 by Trung: added 'addParam' parameter
    
    properties
        id;                  % ID of the coflow
        numFlows;            % total # of flows forming the coflow
        flows;               % the flows forming the coflow (array of objects)
        indicator;           % indicates whether flow j of coflow k uses link i
        weight_origin = 1;   % initial value of weight. Default is one
        weight               % weight of the coflow
        priority = 0;        % will change according to the order that maybe given to coflows
        state_c = 1;         % (initially all flows are active) if there is at least one flow active state_c = 1 if no flow is active state_c = 0
        is_starving = true;  % in the online scenario, when entering the system the coflow is starving. This state change when one of his flows is served
        prices;              % vector of prices on each link
        maxPrices;           % maximal value reached
        arrival = 0;         % slot of arrival of coflow (dynamic case) (offline case arrival = 0)
        departure = -1;      % slot of departure of the LAST FLOW
        i_CCT_initial = 0;   % CCT in isolation
        i_CCT_current;       % Current CCT in isolation in the online scenario
        %fabric;
        %% price convergence
        stability = 0;       % vector of prices converges stability = 1 otherwise stability = 0
        current_w = 0;       % counter of the number of slots where the vector of prices converges (set to 0 whenever the change is bigger than epsi)
        prices_prev;         % vector of prices of the previous slot
        max_diff_prices = 0; % Max_diff_prices = max(|prices - prices_prev|)
        ts_counter = 0;      % total number of slots (during all simulation) where the vector of prices is stable
        volume_initial = 0;  % initial volume of coflow (sum of volumes of its flows)    
        remaining_vol;       % remaining volume of coflow (sum of remaining volumes of its flows)
        transmitted_vol = 0; % transmitted volume of coflow (sum of transmitted volumes of its flows)
        estimated_vol   = 0; % estimated volume of coflow
        deadline = -1;       % deadline for the coflow
        
        %% additional parameters, gathered into the struct addParam
        % Examples:
        % c.addParam.CCT0: isolated CCT of coflow c
        % c.addParam.t_arrival: arrival time
        % c.addParam.t_deadline: deadline
        % c.addParam.k_arrival: arrival time slot
        % c.addParam.k_deadline: deadline time slot
        % c.addParam.slot_id: array of time slots between [k_arrival, k_deadline]
        addParam = {};

    end
    
    methods
        function obj = Coflow(coflowID) % Coflow Constructs an instance of this class
            obj.id = coflowID;
            obj.remaining_vol = obj.volume_initial;
            obj.weight = obj.weight_origin;
            obj.i_CCT_initial = 0;
            obj.i_CCT_current = obj.i_CCT_initial;
            %obj.fabric = [];
        end
        
        function obj = setInitialWeight(obj,w)
            obj.weight_origin = w;
            obj.weight        = obj.weight_origin;
        end
        
        function updateIndicator(obj,n_Machines)
            n_links = 2*n_Machines;            
            obj.indicator = zeros(n_links,obj.numFlows);            
            for flow = obj.flows
                obj.indicator(flow.source.id,flow.id) = 1;
                obj.indicator(flow.destination.id,flow.id) = 1;
            end
        end
        
        function updatePrices(obj,n_Machines)
            obj.prices = zeros(1,2*n_Machines);
        end
        
        function obj = setVolume(obj)
            obj.volume_initial = sum(obj.getFlowsVolume);
            obj.remaining_vol   = obj.volume_initial;
        end
        
        function obj = setICCT(obj,fabric)
            tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
            Bw = [tmp.linkCapacity];

            obj.i_CCT_initial = max((obj.indicator*[obj.getFlowsVolume]')./Bw');
            obj.i_CCT_current = obj.i_CCT_initial;
        end
        
        function update(obj,fabric)
            n_Machines = fabric.numFabricPorts/2;
            obj.updateIndicator(n_Machines);
            obj.updatePrices(n_Machines);
            obj.setVolume();
            obj.setICCT(fabric);
        end
        
        function flowsVolume = getFlowsVolume(obj)
            tmp = [obj.flows];
            flowsVolume = [tmp.volume];
        end
        
        function obj = computeCurrentICCT(obj,fabric)            
            % Link capacities (Bandwidth)            
            tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
            Bw = [tmp.linkCapacity];

            obj.i_CCT_current = max((obj.indicator*[obj.flows.remainingVolume]')./Bw');
        end
             
        function obj = reset(obj)
            obj.weight          = obj.weight_origin;
            obj.state_c         = 1;
            obj.priority        = 0;
            obj.prices          = zeros(1,length(obj.prices));
            obj.maxPrices       = obj.prices;
            obj.prices_prev     = obj.prices;
            obj.stability       = 0;
            obj.current_w       = 0;
            obj.max_diff_prices = 0;
            obj.ts_counter      = 0;
            obj.remaining_vol   = obj.volume_initial;
            obj.transmitted_vol = 0;
            obj.departure       = -1;
            obj.i_CCT_current = obj.i_CCT_initial;
            for f = obj.flows
                f.reset();
            end
        end
    end
end

