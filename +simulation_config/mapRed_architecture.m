classdef mapRed_architecture < simulation_config.simulatorConfig
    % Map Reduce architecture configuration
    
    % Cedric Richier, LIA
    % (c) LIA, 2021
    
    methods (Static)
        function architecture_config = apply_parameters(architecture_config)
            
            prompt = {'# of machines', 'min. # of coflows', 'max. # of coflows',...
                'min. max. # of mappers', 'min. max. # of reducers',...
                'Avg. flow size in Mb', 'vector of link capacities in Mbps'};
            dlgtitle = 'Architecture parameters';
            dims = [1 60];
            defaultinput = {'5', '2', '5', '[1 3]', '[1 2]', '1', '[1 1 1]'};
            answer = inputdlg(prompt,dlgtitle,dims,defaultinput);
            
            architecture_config.architecture_type = 'mapRed_architecture';
            
            % # of machines in the fabric (each machine will have 2 ports ingress/egress)
            architecture_config.NumMachines = str2double(answer{1});
            
            % minimum number of coflows
            architecture_config.minNumCoflows = str2double(answer{2});
            
            % maximum number of coflows
            architecture_config.maxNumCoflows = str2double(answer{3});
            
            % vec of min max # of Mappers
            architecture_config.minMaxMap = utils.str2vec(answer{4});
            
            % vec of min max # of Reducers
            architecture_config.minMaxRed = utils.str2vec(answer{5});
            
            % average size of flow
            architecture_config.avgFlowVolume = str2double(answer{6});
            
            % possible link capacities (should not exceed 1x3 vector)
            architecture_config.linkCapacitiesAvailable = utils.str2vec(answer{7}); 
        end
    end
end