classdef CoflowSkeleton < network_elements.Coflow

    % LAST MODIFIED: 26/01/2021
    
    
    methods
        function obj = CoflowSkeleton(coflowID, architecture_config)
            
            obj = obj@network_elements.Coflow(coflowID);
            %obj.fabric = architecture_config.fabric;
            
            obj.numFlows = 0;
            obj.prices = zeros(1,2*architecture_config.NumMachines);
            
        end
        
        function addFlow(obj,flowID,volume,src,dst)
            % id,flowVolume,source,destination,coflowID,varargin
            obj.flows = [obj.flows network_elements.FlowSkeleton(flowID,volume,src,dst,obj.id)];
            obj.numFlows = obj.numFlows +1;
            %obj.updateIndicator(n_Machines);
            %obj.updatePrices(n_Machines);
        end
        
%         function update(obj,fabric)
%             n_Machines = fabric.numFabricPorts/2;
%             obj.updateIndicator(n_Machines);
%             obj.updatePrices(n_Machines);
%             obj.setVolume();
%             obj.setICCT(fabric);
%         end
%         
%         function updateIndicator(obj,n_Machines)
%             n_links = 2*n_Machines;            
%             obj.indicator = zeros(n_links,obj.numFlows);            
%             for flow = obj.flows
%                 obj.indicator(flow.source.id,flow.id) = 1;
%                 obj.indicator(flow.destination.id,flow.id) = 1;
%             end
%         end
%         
%         function updatePrices(obj,n_Machines)
%             obj.prices = zeros(1,2*n_Machines);
%         end
        
%         function flowsVolume = getFlowsVolume(obj)
%             tmp = [obj.flows];
%             flowsVolume = [tmp.volume];
%         end
        
    end
end

