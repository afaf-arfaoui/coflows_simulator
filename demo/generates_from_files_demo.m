% Generates a batch of coflows from a csv file that describes the instance

% Input file: a test CSV file describing a small batch of coflows within a
% fabric with 5 machines

% 2 different formalism are possible:
%  - Format _0 (example file test_coflows_f_0.csv): flowID field and
%  coflowID field both start from 1. dst field (id of destination port) is
%  the destination machine ID + total number of machines in the fabric
%  (expample: if the destination machine is 1 in a 4 machines fabric, then
%  the dst field value is 1+4 = 5).
%
% - Format _1 (esample file test_coflows_f_1.csv): flowID field and
% coflowID field both start from 0. dst field (id of destination port) is
% the destination machine ID.

%% Example 1: using formalism 0 from test file test_coflows_f_0.csv

fprintf('Generating mat files for example csv 1 (formalism 0)\n');
% build MAT files from the csv. Parameters are the path to csv file, the
% number of machines in the fabric, the format used, and the path to the Mat
% file to produce as output.
utils.fromCSVToCoflows('test_coflows_f_0.csv',3,0,'tmp_ex_f_0.mat');

fprintf('----------------- tmp_ex_f_0.mat file generated -----------------\n\n');

% The generated MAT file contains a Fabric object describing the fabric,
% and an array of Coflow objects that are in the batch
ex_1 = load('tmp_ex_f_0.mat');

%% Example 2: same batch as in example 1, but using formalism 1 from test file test_coflows_f_1.csv

fprintf('Generating mat files for example csv 2 (formalism 1)\n');
utils.fromCSVToCoflows('test_coflows_f_1.csv',3,1,'tmp_ex_f_1.mat');
fprintf('----------------- tmp_ex_f_1.mat file generated -----------------\n\n');

ex_2 = load('tmp_ex_f_1.mat','coflows');

%% Get the outputs, and apply some display. 
% NOTE: display does not depend on the formalism used to describe the batch

fabric = ex_1.fabric;
coflows_0 = ex_1.coflows;
coflows_1 = ex_2.coflows;

fprintf('Coflows from first file, using formalism 0:\n');
utils.displayCoflows(coflows_0);

fprintf('Coflows from second file, using formalism 1: \n');
utils.displayCoflows(coflows_1);

%% Delete temporary MAT files and variables
delete('tmp_ex_f_0.mat','tmp_ex_f_1.mat');
clear ex_1 ex_2;

fprintf(' ================ END ================ \n');
