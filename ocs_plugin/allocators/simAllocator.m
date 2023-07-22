classdef simAllocator < handle
    %SIMALLOCATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        name = 'Generic OCS allocator superclass';
        ocs
    end
    
    methods(Abstract)
        min_duration = allocate(obj)
    end
    
    methods
        function obj = simAllocator(ocs)
            %SIMALLOCATOR Construct an instance of this class
            %   Detailed explanation goes here            
            obj.ocs                  = ocs;
        end

    end
end

