% Generates a simple batch of coflows, then computes a coflow priority order
% using ONEPARIS, and finally schedules coflows according to the pricing
% scheme

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

%% Computing ONEPARIS order:

% ONEPARIS standalone sorting algorithm takes a Fabric object and an array
% of Coflow objects as inputs, and generates a list of coflow IDs' sorted
% in descending order of their priorities:
op_prio = CoflowOrderAlgos.OneParis.oneParis_sorting(fabric,coflows);

%% stability parameters (testing the convergence of the pricing mechanism)

w_size = 10; % window that allows to say that price is stable or not
epsi = 1e-4; % max price on links (for a given coflow) should not exceed epsi

%% other parameters, with default values

maxPrice = 100;  % price limit (prices of coflows on each link should not exceed maxPrice)
beta = 1;      % parameter for price update
updateVolStep = 1500; % update the volume each 1500 slots
epsilon = 1e-5; % Epsilon value to avoid division by zero
tmp = [[fabric.machinesPorts.ingress] [fabric.machinesPorts.egress]];
linksCap = [tmp.linkCapacity]'; % vector of link capacities
delta = 1e-3; % Time interval delta (unit = second)

%% Scheduling coflows using the pricing mechanism
fprintf('========================================\n');
fprintf('Scheduling coflows .... Please wait ...\n');
fprintf('========================================\n\n');
outputs = ResourceAllocationAlgos.pricing.offlinePricing(fabric,coflows,updateVolStep,...
    maxPrice,beta,w_size,epsi,linksCap,op_prio,delta,epsilon);

%% Printings
fprintf('CCTs: [ ');
fprintf('%g ', round(outputs.CCTs,3));
fprintf(']\n');

fprintf('Average CCT: %d\n', round(outputs.av_CCT,3));
fprintf('Number of iterations: %d\n',outputs.nb_iter);

% Uncomment the following line to save outputs:
%save('test_pricing', 'outputs');

delete('tmp_ex_f_0.mat');