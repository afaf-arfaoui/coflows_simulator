function outputs = greedyFlowScheduling(fabric,coflows,prio_order,varargin)
% Process the Greedy Rate Allocation Algorithm presented in sincronia paper
% This implementation builds a structure from input objects in order
% to manage large instances
% The function returns a structure gathering CCTs of coflows, average CCT
% and the number of steps from the greedy allocation algorithm
% Parameters:
% - fabric: the Fabric object representig the network. 
% - coflows: an array of Coflow objects
% - prio_order: the array of coflows' ID in ascending priorities order
% - verbose (optional): displays some feedbacks if true, does nothing
%   otherwise
%
% Cedric Richier, LIA
% (c) LIA, 2021

verbose = false;
switch nargin
    case 4
        verbose = varargin{1};
end
if verbose
    tic
end

%% Initializations:

% Store indexes of unfinished coflows sorted by ascendant priority
unfinished = prio_order;

% Number of coflows
n_coflows = length(coflows);

% Set of indexes of finished coflows
finished=[];

% Link capacities
tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
B_origin = [tmp.linkCapacity];
B = B_origin;

% Initializing the final cct of each coflow to zero
final_ccts = zeros(1,n_coflows);

% Store the number of flows by coflows:
n_flows_by_coflows = [coflows.numFlows];

% total number of flows
tot_n_flows = sum(n_flows_by_coflows);

% Array that stores the offset of flows according to their coflows
index_bases = [0 cumsum(n_flows_by_coflows(1:n_coflows-1))];

% Flows structure to manipulate:
if verbose
    fprintf('Instanciating Flows structure ... ');
end

Flows = struct('id',num2cell(1:tot_n_flows),...
    'c_id',num2cell(zeros(1,tot_n_flows)),'IO',zeros(1,2),...
    'volume',num2cell(zeros(1,tot_n_flows)),...
    'fct',num2cell(zeros(1,tot_n_flows)),'state',num2cell(ones(1,tot_n_flows)),...
    'c_state',num2cell(ones(1,tot_n_flows)),'active',num2cell(zeros(1,tot_n_flows)),...
    'rate',num2cell(zeros(1,tot_n_flows)));

if verbose
    fprintf('Flows struct created ... \n');
end

% Fill the structure
if verbose
    fprintf('Filling the structure ....');
end

j = 0;
for c = coflows
    for f = c.flows
        j = j+1;
        Flows(j).c_id = c.id;
        Flows(j).IO = f.links;
        Flows(j).volume = f.volume;        
    end
end

if verbose
    fprintf('Flows struct filled ...\n');
end

% Counter for number of ended flows:
tot_f_ended = 0;

% Counter for number of steps:
n_steps = 0;

%% Main loop:
while ~isempty(unfinished)
    
    % Incrementing number of steps:
    n_steps = n_steps+1;
    
    if verbose
        fprintf('----------------------- STEP %d -------------------------\n',n_steps);
    end
    
    % Number of finished flows in a step (verbose)
    n_f_ended = 0;
    
    % Greedy flow allocation
    for k = unfinished
        %c = coflows(k);
        for j = index_bases(k)+1:index_bases(k)+n_flows_by_coflows(k)
        %for f = c.flows
            % Allocation to flows that are not finished
            if Flows(j).state
                % Check bandwidth avalability on flow's path
                f_links = Flows(j).IO;
                %if sum(B(f_links)) == 2 % NOTE: capacity of ALL links is 1
                if prod(B(f_links)) > 0
                    % Allocate all bandwidth to flow
                    %Flows(j).rate = 1;
                    Flows(j).rate = min(B(f_links));
                    % Update active status for flow:
                    Flows(j).active = 1;
                    % Update bandwidth on path
                    B(f_links) = B(f_links)-min(B(f_links));
                end
            end
        end
        
    end     
    
    % Consider only active flows (with rate > 0):
    f_active = [Flows.active]==1;
    
    % Compute the minimum duration to end at least one of all active flows:
    min_duration = min([Flows(f_active).volume]./[Flows(f_active).rate]);
    
    % Store the number of finished coflows:
    len_finished = length(finished);
    
    % Update fcts, remaining volume, rate and state of all flows that are 
    % not finished
    for k = unfinished
        c_state = 0;
        k_f_range = index_bases(k)+1:index_bases(k)+n_flows_by_coflows(k);
        rem_f = [Flows(k_f_range).state]==1;
        rem_f_range = k_f_range(rem_f); 
        for j = rem_f_range
            if Flows(j).state
                if f_active(j)
                    % Update volume of active flows during this step
                    Flows(j).volume = Flows(j).volume-min_duration*Flows(j).rate;
                end
                % Reset rate of flow to zero for next step
                Flows(j).rate = 0;
                % Reset active state to zero for next step
                Flows(j).active = 0;
                % Update flow completion time
                Flows(j).fct = Flows(j).fct + min_duration;
                if ~Flows(j).volume % flow ends now
                    % Update the unfinished flow status
                    Flows(j).state = 0;
                    n_f_ended = n_f_ended+1;
                else
                    % There is at least one unfinished flow for this
                    % coflow, thus the coflow is still active for next step
                    c_state = 1;
                end
            end
        end
        % Check if coflow is finished
        if ~c_state % all flows of coflow are done
            % Store the final CCT of coflow
            final_ccts(k) = max([Flows(k_f_range).fct]);
            % Update the set of indexes for finished coflows
            finished = union(finished,k);
        end
    end
    
    % Update the set of unfinished coflows if necessary
    if len_finished < length(finished)
        unfinished = setdiff(unfinished,finished,'stable');
    end
    
    % Reset available bandwidth on all links for next step
    %B(:) = 1; % NOTE: capacity of ALL links is 1
    B = B_origin;
    
    % Update total number of finished flows
    tot_f_ended = tot_f_ended+n_f_ended;
    
    if verbose
        fprintf('Number of finished flows this step: %d\n', n_f_ended);
        fprintf('Total number of finished flows: %d\n', tot_f_ended);
        fprintf('---------------------------------------------------------\n');
    end
    
end

%% Formating outputs:
outputs.avg_cct = mean(final_ccts);
outputs.ccts = final_ccts;
%outputs.fcts_all = all_fcts;
%outputs.rates = All_rates_by_step;
outputs.total_steps = n_steps;
%For Jakub:
outputs.Flows = Flows;

if verbose
    toc
end

end