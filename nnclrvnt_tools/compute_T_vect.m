function t_vect = compute_T_vect(n_T, varargin)
%COMPUTET_VECT Generates a vector of thresholds representing expected
% volume of coflows in each link of the fabric
% Parameters:
%   - n_T: number of thresholds
% Returns the n_T size threshold vector t_vect


method = 'linear';
if nargin > 1
    method = varargin{1};
end

% NOTE
% min and Max values for the thresholds - it's instance dependant for now !
% Need to think of an automatic method to evaluate these values !
m = 1;
M = 3;

switch method
    case 'test'
        t_vect = [1 2 4 8 12 16 20 30 40 60]';
    case 'linear'
        t_vect = m + (M-m)/(n_T-1)*(0:n_T-1)';
    case 'exp'
        A = (M-m)/(exp(n_T)-exp(1));
        B = M-exp(n_T)*A;
        t_vect = (A*exp(1:n_T) + B)';
    otherwise
        t_vect = sort(rand(n_T,1));
end

end