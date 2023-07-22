classdef Flow < handle
    
    % AUTHOR: Afaf
    % LAST MODIFIED: 18/11/2020
    
    properties
        id;                      % id of flow
        idCoflow;                % the id of the coflow to which the flow belongs
        volume;                  % flow size in Mbit
        volume_initial;          % saving initial volume value
        remainingVolume;         % remaining size in Mbit
        transmitted_vol = 0;     % transmitted volume of flow
        estimated_vol;           % estimated volume of flow
        source;                  % the source of the flow (one of the ingress ports of the fabric)
        destination;             % the destination of the flow (one of the egress ports of the fabric)
        d_rate = 1;              % dynamic rate
        d_rate_old = 1,          % for updating prices !!!
        ad_rate = 1;             % adjusted rate
        fct = 0;                 % flow completion time (initializing to zero (unit = second)) --> 1Paris FCTs
        state_f = 1;             % 1 if remainingVolume>0 0 if remainingVolume = 0
        price;                   % overall price on the path used by the flow
        arrival = 0;             % slot of arrival of COFLOW (dynamic case) (offline case arrival = 0)
        departure = -1;          % slot of departure of the FLOW
        links;                   % links used by the flow
        fct_pricing = 0;         % flow completion time (initializing to zero (unit = second)) --> pricing FCTs (with volume update)
        fct_pricing_2 = 0;       % flow completion time (initializing to zero (unit = second)) --> pricing FCTs (without volume update)
        
        % source and destination are chosen such that they do not correspond to the same machine
    end
    
    methods
        function obj = Flow(id, coflowID)
            % FLOW Construct an instance of this class
            obj.id = id;
            obj.idCoflow = coflowID;
        end
        
        function obj = setSource(obj,fabric,src_id)
            obj.source = fabric.machinesPorts(src_id).ingress;
            obj.links  = [obj.source.id obj.destination.id];
        end
        
        function obj = setDestination(obj,fabric,dst_id)
            n_machines = fabric.numFabricPorts/2;
            if dst_id > n_machines
                dst_id = dst_id - n_machines;
            end
            obj.destination = fabric.machinesPorts(dst_id).egress;
            obj.links = [obj.source.id obj.destination.id];
        end
        
        function obj = setVolume(obj,volume)
            obj.volume = volume;
            obj.remainingVolume = obj.volume;
            obj.volume_initial = obj.volume;
        end
        
        function obj = reset(obj)
            f_vol               = obj.volume_initial;
            obj.volume          = f_vol;
            obj.remainingVolume = f_vol;
            obj.transmitted_vol = 0;
            obj.d_rate          = 1;
            obj.d_rate_old      = 1;
            obj.ad_rate         = 1;
            obj.departure       = -1;
            obj.fct             = 0;
            obj.fct_pricing     = 0;
            obj.fct_pricing_2   = 0;
            obj.state_f         = 1;
        end
    end
end

