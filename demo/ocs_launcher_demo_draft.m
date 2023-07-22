
%% Load a test instance
load('ocs_test_coflows');

% Create simulation clock
delta_T = 1; % time slot duration (in number of time units)
sim_clock = simClock(delta_T);

%% Simulation settings
OCS_config = [];

%================== implemented ordering algos ============================
% 'one_paris' 'sincronia' 'max_slack_BSSI' 'E_constrained_BSSI' 'utopia'
% 'elite' 'varys' 'DCoflow' 'cs_mha' 'DC_MH_BR' 'dual_elite_deadline'
% 'elite_deadline' 'dual_elite' 'greedy_deadline' 'primal_sigma'
% 'bottleneck_lawler' 'dual_elite_lawler' 'dual_elite_lawler_gamma'
% 'elite_nnclrvnt' 'dual_bottleneck_deadline' 'dual_bottleneck_lawler'
% 'elite_deadline_draft' 'dual_elite_lawler_draft'
% 'dual_elite_lawler_gamma_draft' 'dual_elite_lawler_gamma_on_bot'
% 'elite_lawler' 'elite_lawler_draft' 'elite_lawler_gamma'
% 'elite_lawler_gamma_draft'
%==========================================================================
OCS_config.ordering_algorithm   = 'greedy_deadline';

%======================= TUNING PARAMETERS ================================
    
%============= Varys parameters ifdesired =================================
%OCS_config.varys_method = 'varys_dl'; % set varys to meet deadline
    
%OCS_config.varys_dynamic_gammas = true; % set dynamic gammas to compute
% SEBF order at each arrival and departure of coflows (i.e.: gammas are
% computed based on updated volumes of coflows)
% NOTE: only implemented when using full_update policy
%==========================================================================

%================== Utopia parameters if desired ==========================
%OCS_config.utopia_dynamic_order = true; % set dynamic computation of 
% the DRF order: the order is recomputed with updated volumes each time a
% coflow is finished
%
%OCS_config.fairness_input = true; % set the utopia scheduller to manual
%manual mode for the slowdown threshold. When set to true, the
%OCS_config.fairness_value property must be defined
%OCS_config.fairness_value = fairness_value; % manualy set the value of the
%slowdown threshold. To be effective, the OSC_config.fairness_input
%property must be set to true
%
% NOTE: (1) only implemented when using full_update policy
%       (2) Utopia handles the OFFLINE scenario only (2022.06.17)
%==========================================================================

%============= DCoflow parameters if desired ==============================
% OCS_config.DCoflow_method = 'heu_v2_min_sum_congested';
% implemented methods for DCoflow:
%  - 'heu_v2_min_link'
%  - 'heu_v2_min_sum_negative'
%  - 'heu_v2_min_sum_congested'
%==========================================================================
                                
%=============== Dual parameters if desired ===============================
% OCS_config.dual_params.alpha= 0.6; % default value is 0.7
% OCS_config.dual_params.beta= 0.3;  % default value is 0
%==========================================================================

%================ Elite parameter if desired ==============================
% OCS_config.elite_ppower = 4; % default value is 5
%==========================================================================

%=============== Lawler parameters if desired =============================
% OCS_config.lawler_params.gamma = 0.5; % default value is 0
% OCS_config.lawler_params.ppower  = 3; % default value is 1
%==========================================================================

%=================== NON CLAIRVOYANT (nnclrvnt) SPECIFIC ==================
% non clairvoyant method (elite_nnclrvnt) needs a threshold vector to work:
% generating thresholds:
% possible parameters are: 'test' 'linear' 'exp'
% t_vect = compute_T_vect(10,'exp');
% 
% % set the lvl vector of thresholds for each coflow to level one in each
% % link:
% lvl_t_vect = ones(fabric.numFabricPorts,1);
% for c=coflows
%     used_links_count = sum(c.indicator,2);
%     c_used_links = used_links_count>0;
%     c.addParam.thresh_lvl_vct = lvl_t_vect.*c_used_links;
%     c.addParam.used_links_count = used_links_count;
% end
% 
% % Set the threshold vector in the configuration variable
% %OCS_config.clrvnt_state = 1;
% OCS_config.t_vect = t_vect;
%==========================================================================

%==========================================================================


%=============== implemented allocation algorithms ========================
%  'greedy', 'varys' (varys is reserved for varys ordering algorithm)
% 'utopia' (utopia is reserved for utopia ordering algorithm
OCS_config.allocation_algorithm = 'greedy'; % 'greedy' 'varys' 'utopia'
%==========================================================================

%========================== set a policy ==================================
OCS_config.online_policy_name   = 'full_update';  % implemented policies:
                                                  %  - 'conservative'
                                                  %  - 'full_update'
                                                  %  - 'time_weighted'
%OCS_config.alpha_weight         = 1; % used for time_weighted policy
%==========================================================================

%% Initializations
OCS_config.clock                = sim_clock;
OCS_config.fabric               = fabric;
OCS_config.incoming_coflows     = coflows;

% Create system:
ocs = onlineCoflowSimulator();

% % Force to deadline aware simulation if desired:
% % when the ocs is deadline aware, it stops all the coflows that are not
% % finished when reaching their deadline. Such coflows are added to the
% % rejected coflows list in the ocs object
% if ~ ocs.is_dl_aware
%     ocs.is_dl_aware = true;
% end

% initialize system:
%ocs.initialize(OCS_config,true); % verbose version
ocs.initialize(OCS_config);

%% Create first event: arrivals at t = 0 or greater, depends on arrival times
events    = simEvent.empty(0,3);
events(1) = simEvent('arrival',ocs.arrival_times(1),sim_clock);

%% Create first late deadline event (in case of deadline aware simulation):
if ocs.is_dl_aware
    events(2) = simEvent('deadline',ocs.deadlines(1),sim_clock);
end

%% Time loop
count = 0;

while ~isempty(events)
    % Advance clock
    sim_clock.advance_1_delta_T();
    
    % Manage events
    if sim_clock.is_to_manage(events)
        count = count+1;        
        events = ocs.applyPolicy(events);
    end   
end

%% Collect results: TODO

%% Display some plots and results
if ocs.n_steps+1 < ocs.s_charge_len
    ocs.sys_charge(ocs.n_steps+2:end) = [];
end
% figure;
% plot(ocs.sys_charge);
% figure;
% plot(ocs.d_avg_ccts);
% figure;
% plot(ocs.E_star_list);
avg_cct = mean(ocs.final_ccts)
if ocs.is_dl_aware
    n_rejected = length(ocs.rejected)
    accept_rate = (1 - n_rejected/length(ocs.all_coflows))
end
%ocs.E_star_list

% Compute cct of accepted coflows:
temp = setdiff(ocs.ID_list,ocs.rejected);
avg_cct_accepted = mean(ocs.final_ccts(temp));

% Reset instance:
utils.resetCoflows(coflows);

