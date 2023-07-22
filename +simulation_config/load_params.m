function architecture_config = load_params(varargin)

% AUTHOR: Afaf
% LAST MODIFIED: 26/01/2021


%% Default simulation option
default_architecture = 'twoTypeCoflows_architectureVol';

%% If no simulation option is defined, use the default one
if ~isempty(varargin)
    architecture_type = varargin{1};
else
    architecture_type = default_architecture; %  Default value
end

fprintf('Using "%s" configuration\n.',architecture_type)

%% Load the corresponding simulation parameters
switch architecture_type
%     case 'twoTypeCoflows_architecture' % DEPRECATED
%         architecture_config = simulation_config.twoTypeCoflows_architecture.apply_parameters;
    case 'twoTypeCoflows_architectureVol'
        architecture_config = simulation_config.twoTypeCoflows_architectureVol.apply_parameters;
    case 'mapRed_architecture'
        architecture_config = simulation_config.mapRed_architecture.apply_parameters;
    case 'csv_architecture'
        architecture_config = simulation_config.csv_architecture.apply_parameters;
    otherwise
        warning('Simulation type not defined: using default one instead');
        architecture_config = simulation_config.twoTypeCoflows_architectureVol.apply_parameters;
end

end

