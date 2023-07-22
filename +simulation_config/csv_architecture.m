classdef csv_architecture < simulation_config.simulatorConfig    
    methods (Static)
        function architecture_config = apply_parameters(architecture_config)
            
            prompt = {'# of machines', 'Path to file/filename:', 'Format type'};
            dlgtitle = 'Architecture parameters';
            dims = [1 60];
            defaultinput = {'3', '+generated_instances/csvFiles/test_coflows.csv', '0'};
            answer = inputdlg(prompt,dlgtitle,dims,defaultinput);
            
            architecture_config.architecture_type = 'csv_architecture';
            architecture_config.NumMachines = str2double(answer{1});
            architecture_config.filename = answer{2};
            architecture_config.format = str2double(answer{3});
            
        end
    end
end

