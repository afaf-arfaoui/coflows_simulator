function displayCoflows(coflows)
% Displays information about coflows structure
% Parameters:
% - coflows: an array of coflow objets
% Cedric Richier, LIA
% (c) LIA, 2020

for c = coflows
    fprintf('Coflow %d:\n', c.id);
    for f = c.flows
        fprintf('\t flow %d: vol = %d, IN=%d , OUT = %d\n\n',...
            f.id,f.volume,f.source.id,f.destination.id);
    end
end

end