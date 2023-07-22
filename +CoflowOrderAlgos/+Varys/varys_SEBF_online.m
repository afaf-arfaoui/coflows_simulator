function new_order = varys_SEBF_online(ocs,varargin)
%VARYS_SEBF Summary of this function goes here
%   Detailed explanation goes here
    fixed_gammas = true;
    switch nargin
        case 2
            fixed_gammas = varargin{1};
    end
    
    coflows = ocs.coflows;
    ID_list = [coflows.id];
    if fixed_gammas
        gammas = [coflows.i_CCT_initial];
    else
        gammas = [coflows.i_CCT_current];
    end
    [~,SEBF_order] = sort(gammas);
    new_order = ID_list(SEBF_order);

%     new_order = ocs.unfinished;
%     if new_arrivals
%         for c = ocs.new_coflows
%             index = 1;
%             for k = new_order
%                 c_k = ocs.coflows([ocs.coflows.id] == k);
%                 if c.i_CCT_initial < c_k.i_CCT_initial
%                     break;
%                 end
%                 index = index+1;
%             end
%             pre_chunk=[];
%             post_chunk = [];
%             if index > 1
%                 pre_chunk = new_order(1:index-1);
%             end
%             if index <= length(new_order)
%                 post_chunk = new_order(index:end);
%             end
%             new_order = [pre_chunk c.id post_chunk];
%         end
%     end
    
end
