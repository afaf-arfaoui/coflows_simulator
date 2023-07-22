classdef twoTypeCoflows_architecture < simulation_config.simulatorConfig
    
    % AUTHOR: Afaf
    % LAST MODIFIED: 14/12/2020
    % DEPRECATED : 26/01/2021
    
    methods (Static)
        function architercture_config = apply_parameters(architercture_config)
            
            prompt = {'min. # of machines', 'max. # of machines', 'min. # of coflows', 'max. # of coflows', 'probability of coflow type', 'Avg. flow volume in Mbp', 'std. flow volume', 'vector of 3 link capacities in Mbps'};
            dlgtitle = 'Architecture parameters';
            dims = [1 60];
            defaultinput = {'5','10', '5', '8', '[0.5 0.5]', '10', '2', '[1 1 1]'};
            answer = inputdlg(prompt,dlgtitle,dims,defaultinput);
            
            architercture_config.architecture_type = 'twoTypeCoflows_architecture';
            architercture_config.minNumMachines = str2double(answer{1}); % # minimum number of machines in the fabric (each machine will have 2 ports ingress/egress)
            architercture_config.maxNumMachines = str2double(answer{2}); % # maximum number of machines in the fabric (each machine will have 2 ports ingress/egress)
            
            architercture_config.minNumCoflows = str2double(answer{3}); % minimum number of coflows
            architercture_config.maxNumCoflows = str2double(answer{4}); % maximum number of coflows
            architercture_config.typeCoflowProba = utils.str2vec(answer{5}); % probability to decide of coflows type
            
            % type 1: coflows with one flow
            % type 2: coflows with multiple flows
            
            architercture_config.avgFlowVolume = str2double(answer{6}); % average size of flow*
            architercture_config.standardDivVolume = str2double(answer{7}); % standard deviation (since flows' volumes will be generated according to normal dist.
            architercture_config.linkCapacitiesAvailable = utils.str2vec(answer{8}); % possible link capacities (should not exceed 1x3 vector)
        end
    end
end

