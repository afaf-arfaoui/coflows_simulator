function ocs = sim_params_checking(sim_config,ocs)
%SIM_PARAMS_CHECKING check listing of all configuration parameters
%   Detailed explanation goes here

if strcmp(sim_config.ordering_algorithm,'E_constrained_BSSI')
    if isfield(sim_config,'fairness_input')
        ocs.fairness_input = sim_config.fairness_input;
        ocs.fairness_value = sim_config.fairness_value;
    end    
end

if strcmp(sim_config.allocation_algorithm,'varys') && ...
        ~strcmp(sim_config.ordering_algorithm,'varys')
    warning('Varys allocation can only be done with Varys ordering algorithm. Thus, allocation_algorithm is set to greedy instead ... \n');
    ocs.allocation_algorithm = 'greedy';
else
    ocs.allocation_algorithm = sim_config.allocation_algorithm;
end

if strcmp(sim_config.allocation_algorithm,'utopia') && ...
        ~strcmp(sim_config.ordering_algorithm,'utopia')
    warning('Utopia allocation can only be done with Utopia ordering algorithm. Thus, allocation_algorithm is set to greedy instead ... \n');
    ocs.allocation_algorithm = 'greedy';
else
    ocs.allocation_algorithm = sim_config.allocation_algorithm;
end


ocs = sim_params_dependent('dcoflow',sim_config,ocs);

if strcmp(sim_config.ordering_algorithm,'DC_MH_BR') && ~ocs.is_dl_aware
    ocs.is_dl_aware = true;
end

if strcmp(sim_config.ordering_algorithm,'cs_mha') && ~ocs.is_dl_aware
    ocs.is_dl_aware = true;
end

if strcmp(sim_config.ordering_algorithm,'varys')
    if isfield(sim_config,'varys_dynamic_gammas')
        ocs.varys_dynamic_gammas = sim_config.varys_dynamic_gammas;
    end
    if isfield(sim_config,'varys_method')
        if strcmp(sim_config.varys_method,'varys_dl')
            ocs.varys_dl = true;
            ocs.is_dl_aware = true;
        end
    end
end

if strcmp(sim_config.ordering_algorithm,'utopia')
    ocs = sim_params_dependent('utopia',sim_config,ocs);
    if isfield(sim_config,'utopia_dynamic_order')
        ocs.utopia_dynamic_order = sim_config.utopia_dynamic_order;
    end
end

if strcmp(sim_config.ordering_algorithm,'dual_elite_deadline') ...
        || strcmp(sim_config.ordering_algorithm,'dual_bottleneck_deadline') ...
        || strcmp(sim_config.ordering_algorithm,'dual_elite_lawler') ...
        || strcmp(sim_config.ordering_algorithm,'dual_bottleneck_lawler') ...
        || strcmp(sim_config.ordering_algorithm,'dual_elite_lawler_gamma') ...
        || strcmp(sim_config.ordering_algorithm,'dual_elite_lawler_gamma_on_bot') ...
        || strcmp(sim_config.ordering_algorithm,'dual_elite_lawler_draft') ...
        || strcmp(sim_config.ordering_algorithm,'dual_elite_lawler_gamma_draft')
            
    ocs = sim_params_dependent('elite',sim_config,ocs);
    ocs = sim_params_dependent('dual',sim_config,ocs);
    ocs = sim_params_dependent('lawler',sim_config,ocs);
    
    % Force dual alpha parameter to 1 for dual_bottleneck_deadline, and for
    % dual_bottleneck_lawler
    if strcmp(sim_config.ordering_algorithm,'dual_bottleneck_deadline') ...
            || strcmp(sim_config.ordering_algorithm,'dual_bottleneck_lawler')
        ocs.dual_params.alpha = 1;
    end
end

if strcmp(ocs.ordering_algorithm,'dual_elite')
    ocs = sim_params_dependent('elite',sim_config,ocs);
    ocs = sim_params_dependent('dual',sim_config,ocs);
end

if strcmp(ocs.ordering_algorithm,'elite_lawler')...
        || strcmp(ocs.ordering_algorithm,'elite_lawler_draft')...
        || strcmp(ocs.ordering_algorithm,'elite_lawler_gamma')...
        || strcmp(ocs.ordering_algorithm,'elite_lawler_gamma_draft')
    ocs = sim_params_dependent('elite',sim_config,ocs);
    ocs = sim_params_dependent('lawler',sim_config,ocs);
end

if strcmp(ocs.ordering_algorithm,'elite') ...
        || strcmp(ocs.ordering_algorithm,'elite_nnclrvnt') ...
        || strcmp(ocs.ordering_algorithm,'elite_deadline') ...
        || strcmp(ocs.ordering_algorithm,'elite_deadline_draft')
    ocs = sim_params_dependent('elite',sim_config,ocs);
end

if strcmp(ocs.ordering_algorithm,'elite_nnclrvnt')
    ocs.is_clrvnt = 0;
    if ~isfield(sim_config,'t_vect')
        warning('Threshold vector not specified. Default vector used instead.');
        ocs.t_vect = compute_T_vect(10);
    else
        ocs.t_vect = sim_config.t_vect;
    end
end

end

