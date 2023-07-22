function [architecture_config] = fabric_generation(architecture_config)

    % AUTHOR: Afaf + Cedric
    % LAST MODIFIED: 10/03/2021
    
    switch architecture_config.architecture_type
        
%        case {'twoTypeCoflows_architecture', 'twoTypeCoflows_architectureVol'}
        case 'twoTypeCoflows_architectureVol'
            
        architecture_config.NumMachines = randi([architecture_config.minNumMachines architecture_config.maxNumMachines]); % Random # of machines
        architecture_config.fabric = network_elements.Fabric2Classes(architecture_config.NumMachines, architecture_config.linkCapacitiesAvailable); % generating the fabric
        
        case {'csv_architecture', 'skeleton_architecture'}
            
        architecture_config.fabric = network_elements.FabricSkeleton(architecture_config.NumMachines);
        
        case {'mapRed_architecture', 'mapRed_fullFlows_architecture'}
            
            % Generating the fabric given the input parameters.
            % For mapRed architectures, the fabric object is not
            % diferent from the towTypeCoflows_architecture
            architecture_config.fabric = network_elements.Fabric2Classes(architecture_config.NumMachines, architecture_config.linkCapacitiesAvailable);
    end

end

