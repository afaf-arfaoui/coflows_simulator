% Generates a simple batch of coflows and performs some algorithms in order
% to compare resulting average Coflow Completion Times

%% Generating Coflow objects and Fabric object from a CSV file:
fprintf('Generating mat files for example csv file (formalism 0)\n');

% build MAT files from the csv. Parameters are the path to csv file, the
% number of machines in the fabric, the format used, and the path to the Mat
% file to produce as output.
utils.fromCSVToCoflows('test_coflows_f_0.csv',3,0,'tmp_ex_f_0.mat');

% load the generated mat files. It generates an array of Coflow objects
% named coflows, and a Fabric object named fabric in the Matlab workspace
load('tmp_ex_f_0.mat');

% Displaying the batch:
fprintf('Coflows in the batch:\n');
utils.displayCoflows(coflows);

%% Computing varys algorithm

% Varys implementation needs the the Fabric object, and the coflows array
% as inputs, and generates a structure as output:
varys_res = ResourceAllocationAlgos.varys.varys_offline(fabric,coflows);

%% Computing sincronia algorithm, using the greedy allocation:

% Sincronia algorithm takes the Fabric object and the array of Coflow
% objects as inputs, and generates the list of coflow IDs' sorted in
% descending order of their priorities:
sinc_prio = CoflowOrderAlgos.WeightBasedAlgos.sincronia_BSSI(fabric,coflows);

% Based on this sorted list, the greedy flow scheduling alogiritm generates
% a structure as output:
sinc_res = ResourceAllocationAlgos.greedyAllocation.greedyFlowScheduling(fabric,coflows,sinc_prio);

%% Computing ONEPARIS solution:

% ONEPARIS standalone sorting algorithm takes a Fabric object and an array
% of Coflow objects as inputs, and generates a list of coflow IDs' sorted
% in descending order of their priorities:
op_prio = CoflowOrderAlgos.OneParis.oneParis_sorting(fabric,coflows);

% Based on this sorted list, the ONEPARIS standalone resource allocation 
% alogiritm generates a structure as output:
op_res = ResourceAllocationAlgos.OnePARIS_Allocation.prioritized_coflows_processing(fabric,coflows,op_prio);

%% Comparing results

% Gathering the average CCT of each solution in a table and display the
% results:

ONEPARIS_avg = op_res.avg_cct;
Sincronia_avg = sinc_res.avg_cct;
Varys_avg = varys_res.avg_cct;

avg_ccts_results = table(ONEPARIS_avg,Sincronia_avg,Varys_avg);
display(avg_ccts_results);

delete('tmp_ex_f_0.mat');
