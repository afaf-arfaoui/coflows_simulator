function ocs = sim_params_dependent(keyword,sim_config,ocs)
%SIM_PARAMS_DEPENDENT Check parameters dependencies
%   Detailed explanation goes here

switch keyword
    case 'dcoflow'
        if strcmp(sim_config.ordering_algorithm,'DCoflow')
            default_DCoflow_method = 'heu_v2_min_link';
            if ~ocs.is_dl_aware
                ocs.is_dl_aware = true;
            end
            if ~isfield(sim_config,'DCoflow_method')
                warning('DCoflow method not specified. Default method set to %s ...\n'...
                    , default_DCoflow_method);
                ocs.DCoflow_method = default_DCoflow_method;
            else
                implemented_methods = {'heu_v2_min_link',...
                    'heu_v2_min_sum_negative',...
                    'heu_v2_min_sum_congested'};
                if ~sum(strcmp(sim_config.DCoflow_method,implemented_methods))
                    warning('%s is an unknown DCoflow method. Default method set to %s ...\n'...
                        , sim_config.DCoflow_method, default_DCoflow_method);
                    ocs.DCoflow_method = default_DCoflow_method;
                else
                    ocs.DCoflow_method = sim_config.DCoflow_method;
                end
            end
        end
    case 'elite'
        if isfield(sim_config,'elite_ppower')
            ocs.elite_ppower = sim_config.elite_ppower;
        end
    case 'dual'
        if isfield(sim_config,'dual_params')
            if isfield(sim_config.dual_params,'alpha')
                ocs.dual_params.alpha = sim_config.dual_params.alpha;
            end
            if isfield(sim_config.dual_params,'beta')
                ocs.dual_params.beta = sim_config.dual_params.beta;
            end
        end
    case 'lawler'
        if isfield(sim_config,'lawler_params')
            if isfield(sim_config.lawler_params,'gamma')
                ocs.lawler_params.gamma = sim_config.lawler_params.gamma;
            end
            if isfield(sim_config.lawler_params,'ppower')
                ocs.lawler_params.ppower = sim_config.lawler_params.ppower;
            end
        end
    case 'utopia'
        for c = ocs.incoming_coflows
            c.addParam.virtual_finish_time = -1;
        end
end

end

