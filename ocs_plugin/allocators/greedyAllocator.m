classdef greedyAllocator < simAllocator
    %GREEDYALLOCATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % See the simAllocator class for a list of inherited properties
    end
    
    methods
        
        function obj = greedyAllocator(ocs)
            %GREEDYALLOCATOR Construct an instance of this class
            %   Detailed explanation goes here
            obj = obj@simAllocator(ocs);
            obj.name = 'greedy';
        end
        
        function min_duration = allocate(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            ocs = obj.ocs;
            
            % Greedy flow allocation
            for k = ocs.unfinished
                for j = ocs.index_bases(k)+1:ocs.index_bases(k)+ocs.n_flows_by_coflows(k)
                    % Allocation to flows that are not finished
                    if ocs.Flows(j).state
                        % Check bandwidth avalability on flow's path
                        f_links = ocs.Flows(j).IO;
                        if prod(ocs.B(f_links)) > 0
                            % Allocate all bandwidth to flow
                            ocs.Flows(j).rate = min(ocs.B(f_links));
                            % Update active status for flow:
                            ocs.Flows(j).active = 1;
                            % Update bandwidth on path
                            ocs.B(f_links) = ocs.B(f_links)-min(ocs.B(f_links));
                        end
                    end
                end
            end
            
            % Consider only active flows (with rate > 0):
            ocs.f_active = [ocs.Flows.active]==1;
            
            % Compute the minimum duration to end at least one of all active flows:
            min_duration = min([ocs.Flows(ocs.f_active).volume]./[ocs.Flows(ocs.f_active).rate]);
            min_duration = min_duration/ocs.sim_clock.time_unit;                       
        end
        
    end
end

