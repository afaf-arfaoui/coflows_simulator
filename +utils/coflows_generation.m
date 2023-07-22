function architecture_config = coflows_generation(architecture_config)

    % AUTHOR: Afaf
    % LAST MODIFIED: 10/03/2021
    
    
    architecture_config.coflows = [];
    
    switch architecture_config.architecture_type
        
%         case 'twoTypeCoflows_architecture' % DEPRECATED
%             
%             architecture_config.NumCoflows = randi([architecture_config.minNumCoflows architecture_config.maxNumCoflows]); % random number of coflows
%             fprintf('* Number of coflows %d \n', architecture_config.NumCoflows)
%             % generating coflows
%             for ii = 1:architecture_config.NumCoflows
%                 fprintf('  + Generating coflow %d :', ii)
%                 architecture_config.coflows = [architecture_config.coflows network_elements.Coflow2classes(ii, architecture_config)];
%             end
            
        case 'twoTypeCoflows_architectureVol'
            
            architecture_config.NumCoflows = randi([architecture_config.minNumCoflows architecture_config.maxNumCoflows]); % random number of coflows
            fprintf('* Number of coflows %d \n', architecture_config.NumCoflows)
            % generating coflows
            for ii = 1:architecture_config.NumCoflows
                fprintf('  + Generating coflow %d\n', ii)
                
                if (ii == 1) % insure that there is at least 1 coflow of class 1
                    flag_type = 0;
                    architecture_config.coflows = [architecture_config.coflows network_elements.Coflow2classesVol(ii, architecture_config,flag_type)];
                elseif (ii == 2) % insure that there is at least 1 coflow of class 2
                    flag_type = 1;
                    architecture_config.coflows = [architecture_config.coflows network_elements.Coflow2classesVol(ii, architecture_config,flag_type)];
                else % decide of the coflow class randomly
                    flag_type = 2;
                    architecture_config.coflows = [architecture_config.coflows network_elements.Coflow2classesVol(ii, architecture_config,flag_type)];
                end
            end
            
        case 'csv_architecture'
            filename = architecture_config.filename;
            if (architecture_config.format == 0)
                architecture_config = utils.csvToCoflows(filename,architecture_config);
            else
                architecture_config = utils.H_csvToCoflows(filename,architecture_config);
            end
            
        case 'mapRed_architecture'
            
            architecture_config.NumCoflows = randi([architecture_config.minNumCoflows architecture_config.maxNumCoflows]); % random number of coflows
            fprintf('* Number of coflows %d \n', architecture_config.NumCoflows)
            % generating coflows
            for ii = 1:architecture_config.NumCoflows
                fprintf('  + Generating coflow %d \n', ii)
                architecture_config.coflows = [architecture_config.coflows network_elements.CoflowMapRed(ii, architecture_config)];
            end
            
        case 'mapRed_fullFlows_architecture'
            architecture_config.NumCoflows = randi([architecture_config.minNumCoflows architecture_config.maxNumCoflows]); % random number of coflows
            fprintf('* Number of coflows %d \n', architecture_config.NumCoflows)
            % generating coflows
            for ii = 1:architecture_config.NumCoflows
                fprintf('  + Generating coflow %d \n', ii)
                architecture_config.coflows = [architecture_config.coflows network_elements.CoflowMapRedFF(ii, architecture_config)];
            end
    end

end


