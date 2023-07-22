<<<<<<< HEAD
# coflows_simulator
Coflow_simulator contains some well-known SOTA algorithms that deal with scheduling and resource allocation for coflows' traffic. 
It generates traffic that mimics real one based on real datasets. 
It allows the assessment of the developed algorithms and their benchmark with SOTA ones.
=======
# Coflow Material - LIA, 2021

## What is it
This matlab project provides various tools to create, manipulate, and manage coflows.

## Getting started

### Prerequisite
All the material inside this project is expected to work on matlab version r2014a and newer.

### Installation
 - Unzip the project archive in a matlab working directory of your choice.
 - Add the coflow_material folder and its subfolders to the matlab path.

### Launching example files
Check the demo folder for a list of basic examples that focus on how to use the main usefull functionalities

## Packages and functionalities

**Note:** 
 - All the functions implemented in the project can be called in a matlab script using the following generic command:\
*output = package_name.subpackage_name.function_name(arguments)*
 - All coflow sorting algorithms, as well as the all-in-one solutions (such as Varys, and OneParis_AllInONe) takes a Fabric object (network), and an aray of Coflows objects as arguments. All the resource allocation algorithms needs a Fabric object, an array of coflows, and the ids of coflows sorted in ascending priorities order as arguments.

### Coflow implementation
In this project, we represent a coflow throw the use of a main class named Coflow that implements a bunch of properties and methods.
All the related material is located in the +networkElements package, which contains Fabric (network), and Flow implementations as well.
The main usefull objects in any script should be a Fabric object representing the network, and an array of Coflow objects that store a set of coflows

### Generating coflows
All the coflows are represented based on the Big Switch model. We provide a bunch of solutions in order to generate batches of coflows:
 - Using a generator: please refer to the demo folder for examples showing how to generate batches of coflows with the main_generator function
 - Describing a batch using a CSV file. Each line in the CSV file describes a flow. The file must have the folowing fields: flowID, coflowID, src, dst, bandwidth (volume of a flow), weight. A CSV file can be provided in one of the two folowing format:
    - Format 0: the flowID field and the coflowID field start from 1. The src field is the ID of the source machine of the flow. The dst field is the ID of the destination machine of the flow + the total number of machines in the fabric
    - Format 1: the flowID field and the coflowID field start from 0. The src field is the ID of the source machine of the flow. The dst field is the ID of the destination machine of the flow

### Baseline algorithms
The baseline algorithms implemented in this project can be found in specific packages, and gather the following solutions:
 - Varys
 - Sincronia
 - Greedy Flow Schedulling, a preemptive, sigma-order, and work conserving resource allocation algorithm

### Implemented solutions
We provide the following solutions of coflow management in this project:
 - OneParis All in one, thatimplements an ordering of coflows in terms of priority levels, and a ressource allocation in an all-in-one solution
 - OneParis ordering which is the stand-alone solution of OneParis that is doing the ordering of coflows only
 - OneParis allocation which is our stand-alone resource allocation implementation that is based on a given order of priorities of coflows

### Coflow Ordering Algorithms
The +CoflowOrderAlgos package contains algorithms that sort coflows in a descending order of priority:
 - The WeightBasedAlgos subpackage contains a bunch of functions that implements Primal Dual based algorithms
 - In particular, CoflowOrderAlgos.WeightBasedAlgos.sincroniaBSSI function implements the sincronia (Bottleneck Select Scale Iterate) algorithm
 - CoflowOrderAlgos.OneParis.oneParis_sorting function implements the OneParis Algorithm that focus only on sorting coflows in descending priorities order (once paper published ONE-PARIS will be made available)

### Resource Allocation Algorithms
The +ResourceAllocationAlgos package contains material related to several bandwidth allocation policies:
 - +OnePARIS_Allocation subpackage is dedicated to the oneParis All-in-One solution. The main functions in this subpackage are: 
    - ResourceAllocationAlgos.OnePARIS_Allocations.oneParis_allInOne. That is the implementation of OneParis where sorting coflows and resource allocation are performed at the same time
    - ResourceAllocationAlgos.OnePARIS_Allocations.prioritized_coflows_processing is the stand-alone resource allocation algorithm used in the all-in-one solution
 - +greedyAllocation subpackage is dedicated to the Greedy Flow Scheduling implementation. The main function is ResourceAllocationAlgos.greedyAllocation.greedyFlowScheduling
 - +varys subpackage is dedicated to varys implementation. Main function is ResourceAllocationAlgos.varys.varys_offline
 - +pricing subpackage is dedicated to the resource allocation based on pricing scheme. The main function is ResourceAllocationAlgos.pricing.offlinePricing. The main inputs are: a Fabric object, an array of Coflow object, and a list of coflow IDs sorted in descending order of their priorities. There are other input parameters for which we provide some default values in the demo file (demo/xxxx). For further details about input parameters, please refer to the commentaries in the code itself. The offlinePricing function run the pricing scheme and outputs a set of computed metrics such as the Coflow Completion Times of each coflow, the average Coflow Completion Time, and the number of iterartions
   (once paper about the pricing mechanism is accepted, pricing subpackage will be made available)
### The +utils package
The +utils package contains tools such as displaying objects, transforming objects from / to files, and generating coflows. Here is a list of the main functions we provide in this package
 - displayCoflows: displays a batch of coflows in an easy to read manner
 - fromCSVToCoflows: generates an array of Coflow objects from a CSV file. Please refer to the code for a further description of this function
 - coflowsToCSV: generate a CSV file describing a batch of coflows from an array of Coflow objects
 - fabricToCSV: generates a CSV file describing a fabric from a Fabric object
 - main_generator: generates a batch of coflows. Please refer to the demo folder for examples showing how to use


>>>>>>> 51eecbc (first_commit)
