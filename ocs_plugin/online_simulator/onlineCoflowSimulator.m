classdef onlineCoflowSimulator < handle
    %SIMSYSTEM Summary of this class goes here
    %   Detailed explanation goes here
        
    properties
        ordering_algorithm
        DCoflow_method
        elite_ppower          = 5;
        dual_params           = struct('alpha',0.7,'beta',0);
        lawler_params         = struct('gamma',0,'ppower',1);
        allocation_algorithm
        online_policy_name
        policy
        allocator
        is_dl_aware           = false;
        varys_dynamic_gammas  = false;
        varys_departure       = false;
        varys_dl              = false;
        prev_arrival_time     = 0;
        prev_virtual_time     = 0;
        prev_P_star           = 1;
        utopia_dynamic_order  = false;
        utopia_departure      = false;
        fairness_input        = false;
        fairness_value        = 0;
        active
        fabric
        coflows
        incoming_coflows
        all_coflows
        new_coflows
        ID_list
        arrival_times
        deadlines
        delta_T_arrivals
        k_last
        n_coflows
        sim_clock
        finished
        unfinished
        rejected
        B_origin
        B
        final_ccts
        prio_table
        prio_idx
        dl_coflows_outputs
        dl_coflows_outputs_idx
        n_flows_by_coflows
        n_flows
        tot_n_coflows
        tot_n_flows        
        index_bases
        Flows
        tot_f_ended
        n_steps
        verbose
        f_active
        E_star_list = [];
        d_avg_max_length
        d_avg_last_idx
        d_avg_ccts
        s_charge_len
        sys_charge
        is_clrvnt = true;
        per_link_agr_vols = [];
        t_vect = [];
    end
    
    methods
        
        function obj = onlineCoflowSimulator()
            %SIMSYSTEM Construct an instance of this class
            %   Detailed explanation goes here
            obj.ordering_algorithm    = 'one_paris';
            obj.DCoflow_method        = [];
            obj.allocation_algorithm  = 'greedy';
            obj.online_policy_name    = 'full_update';
            obj.allocator             = [];
            obj.policy                = [];
            obj.fabric                = [];
            obj.coflows               = [];
            obj.n_coflows             = 0;
            obj.n_flows               = 0;
            obj.incoming_coflows      = [];
            obj.all_coflows           = [];
            obj.new_coflows           = [];
            obj.k_last                = 0;
            obj.d_avg_max_length      = 0;
            obj.d_avg_last_idx        = 0;
            obj.d_avg_ccts            = [];
            obj.s_charge_len          = 0;
            obj.sys_charge            = [];
        end
        
        function new_allocator = createAllocator(obj,sim_config)
            name = sim_config.allocation_algorithm;
            switch name
                case 'greedy'
                    new_allocator = greedyAllocator(obj);
                case 'varys'
                    new_allocator = varysAllocator(obj);
                case 'utopia'
                    new_allocator = utopiaAllocator(obj);
                otherwise
                    error('%s allocator not defined\n',name);
            end
        end
        
        function new_policy = createPolicy(obj,sim_config)
            name = sim_config.online_policy_name;
            switch name
                case 'full_update'
                    new_policy = fullUpdatePolicy(obj);
                case 'conservative'
                    new_policy = conservativePolicy(obj);
                case 'time_weighted'
                    if isfield(sim_config,'alpha_weight')
                        new_policy = timeWeightedPolicy(obj,sim_config.alpha_weight);
                    else
                        new_policy = timeWeightedPolicy(obj);
                    end
                otherwise
                        error('%s policy not defined\n',name);
            end
        end
        
        % Apply policy to current events
        function events = applyPolicy(obj,events)
            % test sys_charge
            obj.n_steps = obj.n_steps+1;
            
            % test for plot
            if obj.n_steps +1 > obj.s_charge_len
                add_length = ceil(obj.s_charge_len/2);
                obj.s_charge_len = obj.s_charge_len + add_length;
                new_chunk = zeros(1,add_length);
                old_chunk = obj.sys_charge;
                obj.sys_charge = [old_chunk new_chunk];
            end            
            
            events = obj.policy.applyPolicy(events);
            
            obj.sys_charge(obj.n_steps+1) = obj.n_coflows;
        end
        
        % Admission control if deadline awareness is active
        function is_admitted = admitThisCoflow(obj,c)
            is_admitted = true;
            if obj.varys_dl
                B_shadow = obj.shadowVarysDLAllocation();
                current_gamma = utils.computeGamma(c,c.getFlowsVolume,B_shadow);
                deadline_duration = (c.deadline - obj.sim_clock.time)...
                    *obj.sim_clock.time_unit;
                if round(current_gamma - deadline_duration,5) > 0
                    is_admitted = false;
                end
            end
        end
        
        % Varys specific shadow allocation for the deadline objective
        function B_shadow = shadowVarysDLAllocation(obj)
            B_shadow = obj.B;
            for c = obj.coflows
                current_gamma = utils.computeGamma(c,c.getFlowsVolume,B_shadow);
                % case of coflow blocked by a higher priority coflow
                if current_gamma == inf
                    % No allocation for this coflow
                    continue;
                end
                % coflow has some resource available: allocate bandwidth to
                % its flows according to MADD with deadline
                current_gamma = (c.deadline - obj.sim_clock.time)...
                    *obj.sim_clock.time_unit;
                j = obj.index_bases(c.id);
                for f = c.flows
                    j = j+1;
                    if obj.Flows(j).state
                        f_links = obj.Flows(j).IO;
                        rate = f.volume / current_gamma;
                        if sum(B_shadow(f_links)<rate)
                            rate = min(B_shadow(f_links));
                        end
                        % precision management
                        if rate < 1e-5
                            rate = 0;
                        end
                        if rate                            
                            % Update bandwidth on path
                            B_shadow(f_links) = max(B_shadow(f_links)-rate,0);
                            % precision management
                            for l = f_links
                                if B_shadow(l) <= 1e-5
                                    B_shadow(l) = 0;
                                end
                            end
                        end
                    end
                end
            end
        end
        
        % Manage new arrivals
        function new_admission = addNewCoflows(obj)
            current_delta_T = obj.sim_clock.current_delta_T;
            current_coflows_idx = obj.delta_T_arrivals == current_delta_T;
            obj.new_coflows = obj.incoming_coflows(current_coflows_idx);
            is_rejected = false(length(obj.new_coflows),1);
            
            for k = 1:length(obj.new_coflows)
                c = obj.new_coflows(k);
                if ~obj.admitThisCoflow(c)
                    c_id = c.id;
                    % - store rejected state
                    is_rejected(k) = true;
                    % - add to rejected coflows
                    obj.rejected = union(obj.rejected,c_id);
                    % - manage in Flows structure
                    c_base = obj.index_bases(c_id);
                    c_f_range = c_base+1:c_base+obj.n_flows_by_coflows(c_id);
                    for j = c_f_range
                        obj.Flows(j).state = 0;
                    end
                    % Store the final CCT of coflow
                    obj.final_ccts(c_id) = 0;
                    % Update the set of indexes for finished coflows
                    obj.finished = union(obj.finished,c_id);
                    % Update the departure date of c
                    c.departure = obj.sim_clock.time;
                    if obj.verbose
                        fprintf('Coflow # %d rejected \n',c_id);
                    end 
                    % manage still active deadlines if simulator is deadline aware
                    if obj.is_dl_aware
                        % set of indexes that match the rejected coflow's
                        % deadline
                        is_dl_idx = [obj.all_coflows.deadline] == c.deadline;
                        % set of corresponding coflows IDs
                        is_dl_ids = obj.ID_list(is_dl_idx);
                        if prod(ismember(is_dl_ids,obj.finished))
                            % If all coflows with this deadline are
                            % finished, remove the deadline from deadlines
                            % list
                            obj.deadlines(obj.deadlines == c.deadline) = [];
                        end
                    end
                    % Update total number of finished flows
                    obj.tot_f_ended = obj.tot_f_ended+c.numFlows;
                    continue;
                end
                obj.k_last=obj.k_last+1;
                obj.coflows(obj.k_last) = c;
            end
            % Remove rejected coflows from new coflows list
            obj.new_coflows(is_rejected) = [];
            
            obj.n_coflows = length(obj.coflows);
            obj.n_flows = sum([obj.coflows.numFlows]);            
            obj.incoming_coflows(current_coflows_idx) = [];
            obj.arrival_times(current_coflows_idx)    = [];
            obj.delta_T_arrivals(current_coflows_idx) = [];
            new_admission = ~isempty(obj.new_coflows);
        end
        
        % Compute new priorities for awaiting coflows
        function new_order = computePriorities(obj,fabric,coflows,varargin)
            fixed_gammas = true;
            switch nargin
                case 4
                    fixed_gammas = varargin{1};
            end
            
            default_algorithm = 'one_paris';            
            switch obj.ordering_algorithm
                case 'one_paris'
                    new_order = CoflowOrderAlgos...
                        .OneParis.oneParis_sorting(fabric,coflows);
                case 'sincronia'
                    new_order = CoflowOrderAlgos...
                        .WeightBasedAlgos.sincronia_BSSI(fabric,coflows);
                case 'elite'
                    new_order = CoflowOrderAlgos...
                        .WeightBasedAlgos.elite(fabric,coflows,obj.elite_ppower);
                case 'varys'
                    if obj.varys_dl
                        new_order = [obj.coflows.id];
                    else
                        if fixed_gammas
                            new_order = CoflowOrderAlgos...
                                .Varys.varys_SEBF_online(obj);
                        else
                            new_order = CoflowOrderAlgos...
                                .Varys.varys_SEBF_online(obj,false);
                        end
                    end
                case 'E_constrained_BSSI'
                    new_order = E_constrained_BSSI_online(fabric,coflows,obj);
                case 'E_constrained_noVolume_BSSI'
                    new_order = E_constrained_BSSI_noVolume_online(fabric,coflows,obj);
                case 'max_slack_BSSI'
                    new_order = max_slack_BSSI_online(fabric,coflows,obj);
                case 'primal_sigma'
                    new_order = CoflowOrderAlgos.Other.primal_sigma_order(fabric,coflows);
                case 'DCoflow'
                    obj.dl_coflows_outputs_idx = obj.dl_coflows_outputs_idx+1;
                    outputs = CoflowOrderAlgos.DeadlineAwareAlgos.DCoflow_online(...
                        fabric,coflows,obj);
                    obj.dl_coflows_outputs{obj.dl_coflows_outputs_idx} = outputs;
                    new_order = [outputs.order outputs.pred_rejects];
                case 'DC_MH_BR'
                    obj.dl_coflows_outputs_idx = obj.dl_coflows_outputs_idx+1;
                    outputs = CoflowOrderAlgos.DeadlineAwareAlgos.D_coflow_MH_balaRachid_v1(...
                        fabric,coflows,obj);
                    obj.dl_coflows_outputs{obj.dl_coflows_outputs_idx} = outputs;
                    new_order = [outputs.order outputs.pred_rejects];
                case 'cs_mha'
                    obj.dl_coflows_outputs_idx = obj.dl_coflows_outputs_idx+1;
                    outputs = CoflowOrderAlgos.DeadlineAwareAlgos.cs_mha_online(...
                        fabric,coflows,obj);
                    obj.dl_coflows_outputs{obj.dl_coflows_outputs_idx} = outputs;
                    new_order = outputs.order;
                case {'dual_elite_deadline','dual_bottleneck_deadline'}
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.dual_elite_deadline(...
                        fabric,coflows, obj);
                case 'elite_deadline'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.elite_deadline(...
                        fabric,coflows, obj);
                
                %====================== WORK IN PROGRESS =====================================
                case 'elite_deadline_draft'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.elite_deadline_draft(...
                        fabric,coflows, obj);
                %=============================================================================    
                    
                case 'greedy_deadline'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.greedy_deadline(...,
                        coflows);
                case 'dual_elite'
                    new_order = CoflowOrderAlgos.WeightBasedAlgos.dual_elite(fabric,coflows,...
                        obj.dual_params.alpha,obj.dual_params.beta,obj.elite_ppower);
                case 'dual_elite_lawler_gamma'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.dual_elite_lawler_gamma(...
                        fabric,coflows,obj);
                    
                %====================== WORK IN PROGRESS ===================================== 
                case 'dual_elite_lawler_gamma_draft'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.dual_elite_lawler_gamma_draft(...
                        fabric,coflows,obj);
                %=============================================================================
                    
                %====================== WORK IN PROGRESS =====================================   
                case 'dual_elite_lawler_gamma_on_bot' 
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.dual_elite_lawler_gamma_on_bot(...
                        fabric,coflows, obj);
                %=============================================================================

                case 'bottleneck_lawler'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.bottleneck_lawler(...
                        fabric,coflows,obj);
                    
                %====================== WORK IN PROGRESS ===================================== 
                case 'dual_elite_lawler_draft'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.dual_elite_lawler_draft(...
                        fabric,coflows,obj);
                %=============================================================================
                
                case {'dual_elite_lawler', 'dual_bottleneck_lawler'}
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.dual_elite_lawler(...
                        fabric,coflows,obj);
                
                %====================== WORK IN PROGRESS =====================================
                case 'elite_lawler'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.elite_lawler(...
                        fabric,coflows,obj);
                    
                case 'elite_lawler_draft'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.elite_lawler_draft(...
                        fabric,coflows,obj);
                    
                case 'elite_lawler_gamma'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.elite_lawler_gamma(...
                        fabric,coflows,obj);
                    
                case 'elite_lawler_gamma_draft'
                    new_order = CoflowOrderAlgos.DeadlineAwareAlgos.elite_lawler_gamma_draft(...
                        fabric,coflows,obj);
                %=============================================================================
                    
                case 'elite_nnclrvnt'
                    new_order = CoflowOrderAlgos.NonClairvoyantAlgos.elite_nnclrvnt(...
                        fabric,coflows,obj);
                
                %====================== WORK IN PROGRESS ==================
                case 'utopia'
                    new_order = CoflowOrderAlgos.Utopia...
                        .Utopia_DRF(fabric,coflows,obj);
                %==========================================================
                
                otherwise
                    warning('Ordering algorithm %s not defined: using %s instead\n',...
                        obj.ordering_algorithm,default_algorithm)
                    new_order = CoflowOrderAlgos.OneParis.oneParis_sorting(...
                        fabric,coflows);
            end
        end
        
        % Initialization of the simulator according to the configuration
        % settings
        function obj = initialize(obj,sim_config,varargin)
            % Verbose
            obj.verbose = false;
            switch nargin
                case 3
                    obj.verbose = varargin{1};
            end
            
            % Set ordering algorithm
            obj.ordering_algorithm = sim_config.ordering_algorithm;
            
            % fabric and coflows
            obj.fabric = sim_config.fabric;
            obj.incoming_coflows = sim_config.incoming_coflows;
            obj.all_coflows      = obj.incoming_coflows;
            obj.ID_list          = [obj.all_coflows.id];
            
            % Configuration checking according to the defined ordering
            % algoritm
            obj = sim_params_checking(sim_config,obj);

            % policy setting
            obj.online_policy_name = sim_config.online_policy_name;
            obj.policy = obj.createPolicy(sim_config);
            % allocator setting
            obj.allocator = obj.createAllocator(sim_config);
            % simulation clock
            obj.sim_clock = sim_config.clock;
            
            % Total number of coflows during the simulation
            obj.tot_n_coflows = length(obj.incoming_coflows);
            % coflows' arrival times
            obj.arrival_times = [obj.incoming_coflows.arrival];
            obj.delta_T_arrivals = ceil(obj.arrival_times/obj.sim_clock.delta_T_time);
            
            % non clairvoyant case
            if ~obj.is_clrvnt
                obj.per_link_agr_vols = zeros(obj.fabric.numFabricPorts,...
                    obj.tot_n_coflows);
            end
            
            % Deadline awareness
            if obj.is_dl_aware
                obj.deadlines = unique([obj.incoming_coflows.deadline]);
            end
            
            % Coflows awaiting
            obj.coflows = network_elements.Coflow.empty(obj.tot_n_coflows,0);
            
            % Keep track of all prioritie during the simulation
            obj.prio_table = cell(length(unique([obj.arrival_times])),1);
            obj.prio_idx   = 0;
            
            % Specific properties related to the outputs
            obj.dl_coflows_outputs = cell(length(unique([obj.arrival_times])),1);
            obj.dl_coflows_outputs_idx = 0;
            obj.d_avg_max_length = obj.tot_n_coflows;
            obj.d_avg_ccts = zeros(1,obj.d_avg_max_length);
            obj.d_avg_last_idx = 0;
            obj.s_charge_len = 500;
            obj.sys_charge = zeros(1,obj.s_charge_len);
            
            % Link capacities
            tmp = [[obj.fabric.machinesPorts.ingress] [obj.fabric.machinesPorts.egress]];
            obj.B_origin = [tmp.linkCapacity];
            obj.B = obj.B_origin;
            
            % Initializing the final cct of each coflow to zero
            obj.final_ccts = zeros(1,obj.tot_n_coflows);
            
            % Store the number of flows by coflows
            obj.n_flows_by_coflows = [obj.incoming_coflows.numFlows];
            
            % number of flows
            obj.tot_n_flows = sum(obj.n_flows_by_coflows);
            
            % Array that stores the offset of flows according to their coflows
            obj.index_bases = [0 cumsum(obj.n_flows_by_coflows(1:obj.tot_n_coflows-1))];
            
            % Set of indexes of finished coflows
            obj.finished=[];
            
            % Set of indexes of unfinished coflows sorted by priorities
            obj.unfinished = [];
            
            % active state of the system
            obj.active = ~isempty(obj.unfinished);
            
            % Set of active flows
            obj.f_active = [];
            
            % Set of rejected coflows (in the deadline aware scenario)
            obj.rejected = [];
            
            % Flows structure for dynamic management of flows:
            if obj.verbose
                fprintf('Instanciating Flows structure ... ');
            end           
            obj.Flows = struct('id',num2cell(1:obj.tot_n_flows),...
                'c_id',num2cell(zeros(1,obj.tot_n_flows)),'IO',zeros(1,2),...
                'volume',num2cell(zeros(1,obj.tot_n_flows)),...
                'fct',num2cell(zeros(1,obj.tot_n_flows)),...
                'state', num2cell(ones(1,obj.tot_n_flows)),...
                'c_state',num2cell(ones(1,obj.tot_n_flows)),...
                'active',num2cell(zeros(1,obj.tot_n_flows)),...
                'rate',num2cell(zeros(1,obj.tot_n_flows)));            
            if obj.verbose
                fprintf('Flows struct created ... \n');
            end
            
            % Fill the flows' structure
            if obj.verbose
                fprintf('Filling the structure ....');
            end
            
            j = 0;
            for c = obj.incoming_coflows
                for f = c.flows
                    j = j+1;
                    obj.Flows(j).c_id = c.id;
                    obj.Flows(j).IO = f.links;
                    obj.Flows(j).volume = f.volume_initial;
                end
            end
            
            if obj.verbose
                fprintf('Flows struct filled ...\n');
            end
            
            % Counter for number of ended flows:
            obj.tot_f_ended = 0;
            
            % Counter for number of steps:
            obj.n_steps = 0;
        end
        
        % Update the volume thresholds of a coflow c in the non-clairvoyant
        % scenario
        function c = updateThreshLvls(obj,c)
            epsilon = 1e-5;
            max_lvl = length(obj.t_vect);
            for l = 1:obj.fabric.numFabricPorts
                c_l_vol = obj.per_link_agr_vols(l,c.id);
                if c_l_vol > 0
                    t_lvl = 1;
                    while c_l_vol >= obj.t_vect(t_lvl) - epsilon && t_lvl < max_lvl
                        t_lvl = t_lvl + 1;
                    end
                    c.addParam.thresh_lvl_vct(l) = t_lvl;
                end
            end
        end
        
        % Simutate the current allocation since last action
        function obj = applyAllocation(obj)           
            % Number of finished flows during the update
            n_f_ended = 0;
            
            % Store the number of finished coflows:
            len_finished = length(obj.finished);
            
            % Update fcts, remaining volume, rate and state of all flows that are
            % not finished
            time_unit = obj.sim_clock.time_unit;
            time_interval  = time_unit*obj.sim_clock.time_since_last_action;
            for k = obj.unfinished
                c_late = false;
                c_is_deadline = false;
                c_idx = [obj.coflows.id] == k;
                c = obj.coflows(c_idx);
                c_state = 0;
                if obj.is_dl_aware
                    c_is_deadline = c.deadline >= 0 && ...
                        c.deadline <= obj.sim_clock.time;
                end
                k_base = obj.index_bases(k);
                k_f_range = k_base+1:k_base+obj.n_flows_by_coflows(k);
                rem_f = [obj.Flows(k_f_range).state]==1;
                rem_f_range = k_f_range(rem_f);
                for j = rem_f_range
                    if obj.Flows(j).state
                        f = c.flows(j-k_base);
                        f_time_interval = time_interval;
                        if obj.f_active(j)
                            % Update volume of active flows during this step
                            volume         = obj.Flows(j).volume;
                            rate           = obj.Flows(j).rate;
                            f_remaining_time = volume/rate;
                            
                            if f_remaining_time < time_interval
                                f_time_interval = f_remaining_time;
                            end
                            
                            f_vol_transmitted_this_round = f_time_interval...
                                    *rate;
                            current_f_volume = max(0,round(volume-...
                                f_vol_transmitted_this_round,5));
                            if current_f_volume <= 1e-5
                                current_f_volume = 0;
                            end
                            c.remaining_vol = max(0,...
                                round(c.remaining_vol - (volume - ...
                                current_f_volume),5));
                            obj.Flows(j).volume = current_f_volume;
                            f.volume = current_f_volume;
                            f.remainingVolume = current_f_volume;
                            f.transmitted_vol = max(0,...
                                round(f.volume_initial - f.remainingVolume,5));
                            
                            % non-clairvoyant case management
                            if ~obj.is_clrvnt
                                % if f is still active after this round,
                                % the current transmitted volume is added
                                % to the aggregated vol of coflow c in
                                % links used by f
                                if current_f_volume > 0
                                    for l = f.links
                                        obj.per_link_agr_vols(l,c.id) = ...
                                            round(obj.per_link_agr_vols(l,c.id) + ...
                                            f_vol_transmitted_this_round,5);
                                    end
                                % otherwise, the total volume of f is
                                % removed from the aggregated volume of c
                                % in the links used by f
                                else
                                    for l = f.links
                                        updated_c_l_vol = max(0,...
                                            round(obj.per_link_agr_vols(l,c.id) - ...
                                            f.volume_initial,5));
                                        c.addParam.used_links_count(l) = ...
                                            c.addParam.used_links_count(l)-1;
                                        if updated_c_l_vol < 1e-5
                                            updated_c_l_vol  = 0;
                                            % c has no more detected vol in
                                            % l. Set the threshold level to
                                            % 0 if there is no other flow
                                            % alive of c in l, set it to 1
                                            % otherwise
                                            if ~c.addParam.used_links_count(l)
                                                c.addParam.thresh_lvl_vct(l) = 0;
                                            else
                                                c.addParam.thresh_lvl_vct(l) = 1;
                                            end
                                        end
                                        obj.per_link_agr_vols(l,c.id) = ...
                                            updated_c_l_vol;
                                    end
                                end
                            end
                            
                        end
                        % Reset rate of flow to zero for next step
                        obj.Flows(j).rate = 0;
                        % Reset active state to zero for next step
                        obj.Flows(j).active = 0;
                        % Update flow completion time
                        obj.Flows(j).fct = obj.Flows(j).fct + f_time_interval;
                        f.fct = obj.Flows(j).fct;
                        
                        if ~obj.Flows(j).volume % flow ends now
                            % Update the unfinished flow status
                            obj.Flows(j).state = 0;
                            n_f_ended = n_f_ended+1;
                            obj.n_flows = obj.n_flows-1;
                            obj.f_active(j) = false;
                        elseif ~c_state
                            % There is at least one unfinished flow for this
                            % coflow, thus the coflow is still active for next step
                            % if its deadline is still feasible
                            if ~ c_is_deadline
                                c_state = 1;
                            else
                                if ~c_late
                                    c_late = true;
                                end
                                % Update the unfinished flow status
                                obj.Flows(j).state = 0;
                                n_f_ended = n_f_ended+1;
                                obj.n_flows = obj.n_flows-1;
                                obj.f_active(j) = false;
                            end
                        end
                    end
                end
                % Update starvation state for coflow
                if c.is_starving
                    c.is_starving = c.remaining_vol == c.volume_initial;
                end
                % Update the current isolation CCT for coflow c
                c.computeCurrentICCT(obj.fabric);
                % Update transmitted volume of coflow c
                c.transmitted_vol = max(0,...
                                round(c.volume_initial - c.remaining_vol,5)); 
                % Check if coflow is finished
                if ~c_state % all flows of coflow are done
                    % Store the final CCT of coflow
                    obj.final_ccts(k) = max([obj.Flows(k_f_range).fct]);
                    % Update the set of indexes for finished coflows
                    obj.finished = union(obj.finished,k);
                    % Remove coflows k from the list of current coflows
                    obj.coflows(c_idx) = [];
                    obj.k_last = obj.k_last - 1;
                    obj.n_coflows = obj.n_coflows-1;
                    c.departure = obj.sim_clock.time;
                    
                    % If dynamic gammas in varys, and c is the first coflow
                    % to leave the system at current time, then send 
                    % signal to the simulator
                    if obj.varys_dynamic_gammas
                        if ~obj.varys_departure
                            obj.varys_departure = true;
                        end
                    end
                    
                    % If dynamic utopia, and c is the first coflow
                    % to leave the system at current time, then send 
                    % signal to the simulator
                    if obj.utopia_dynamic_order
                        if ~obj.utopia_departure
                            obj.utopia_departure = true;
                        end
                    end
                    
                    if ~c_late
                        c.remaining_vol = 0;
                    else
                        obj.rejected = union(obj.rejected,k);
                        if obj.verbose
                            fprintf('Coflow # %d rejected \n',k);
                        end
                    end
                    
                    % manage still active deadlines if simulator is deadline aware
                    if obj.is_dl_aware
                        % set of indexes that match the finishing coflow's
                        % deadline
                        is_dl_idx = [obj.all_coflows.deadline] == c.deadline;
                        % set of corresponding coflows IDs
                        is_dl_ids = obj.ID_list(is_dl_idx);
                        if prod(ismember(is_dl_ids,obj.finished))
                            % If all coflows with this deadline are
                            % finished, remove the deadline from deadlines
                            % list
                            obj.deadlines(obj.deadlines == c.deadline) = [];
                        end
                    end
                    
                    if ~obj.is_clrvnt
                        % if the simulation uses a non-clairvoyant
                        % scenario the aggregated vol of colfow c is
                        % removed from all links:
                        obj.per_link_agr_vols(:,c.id) = 0;
                    end
                    
                    % dynamically keep track of avg cct during the
                    % simulation
                    obj.d_avg_last_idx = obj.d_avg_last_idx + 1;
                    if obj.d_avg_last_idx > obj.d_avg_max_length
                        add_length = ceil(obj.d_avg_max_length/2);
                        obj.d_avg_max_length = obj.d_avg_max_length + add_length;
                        new_chunk = zeros(1,add_length);
                        old_chunk = obj.d_avg_ccts;
                        obj.d_avg_ccts = [old_chunk new_chunk];
                    end
                    obj.d_avg_ccts(obj.d_avg_last_idx) = sum(obj.final_ccts)/...
                        length(obj.finished);

                elseif ~obj.is_clrvnt
                    % coflow c is still active, the threshold's level need
                    % to be updated
                    obj.updateThreshLvls(c);
                end
                
            end
            
            % Update the set of unfinished coflows if necessary
            if len_finished < length(obj.finished)
                obj.unfinished = setdiff(obj.unfinished,obj.finished,'stable');
                obj.active = ~isempty(obj.unfinished);
            end
            
            % Reset available bandwidth on all links for next step
            obj.B = obj.B_origin;
            
            % Update total number of finished flows
            obj.tot_f_ended = obj.tot_f_ended+n_f_ended;
            
            if obj.verbose
                
                fprintf('Number of coflows in the system: %d\n',obj.n_coflows);                
                fprintf('Number of finished flows this step: %d\n', n_f_ended);
                fprintf('Total number of finished flows: %d\n', obj.tot_f_ended);
                fprintf('---------------------------------------------------------\n');
            end
            
            % Reset the time since last update to zero
            obj.sim_clock.time_since_last_action = 0;
            
        end
        
        % Compute duration till next volume threshold in the
        % non-clairvoyant case
        function min_duration_till_thresh = computeDurationTillThreshVol(obj)
            min_duration_till_thresh = 0;
            
            if ~obj.is_clrvnt
                active_flows = obj.Flows(obj.f_active);
                total_rate_per_links = zeros(obj.fabric.numFabricPorts,obj.tot_n_coflows);
                for f = active_flows
                    total_rate_per_links(f.IO,f.c_id) = ...
                        total_rate_per_links(f.IO,f.c_id)+f.rate;
                end
                
                active_coflows = unique([active_flows.c_id]);
                active_links = unique([active_flows.IO]);
                c_min_duration_thresh = zeros(1,length(active_coflows));
                
                % c_rem_vol_until_thresh for each active coflow c:
                idx = 0;
                for c_id = active_coflows
                    idx = idx+1;
                    c = obj.all_coflows(c_id);
                    c_t_values = zeros(obj.fabric.numFabricPorts,1);
                    c_t_lvl = c.addParam.thresh_lvl_vct;
                    c_t_values(c_t_lvl>0) = obj.t_vect(c_t_lvl(c_t_lvl>0));
                    c_rem_vol_until_thresh = c_t_values-obj.per_link_agr_vols(:,c_id);
                    
                    % After that: for each active coflow c:
                    c_min_duration_thresh(idx) = min(...
                        c_rem_vol_until_thresh(active_links)...
                        ./total_rate_per_links(active_links,c_id));
                end
                
                % at the end: min_duration_until_thresh = min(c_min_duration_thresh) over
                % all c's
                min_duration_till_thresh = min(c_min_duration_thresh)...
                    /obj.sim_clock.time_unit;
                
            end
        end
        
    end
end

