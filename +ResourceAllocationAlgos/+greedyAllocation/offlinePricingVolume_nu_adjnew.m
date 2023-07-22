function outputs = offlinePricingVolume_nu_adjnew(fabric,coflows,updateVolStep,maxPrice,beta,div,w_size,epsi,linksCap,Order,delta,epsilon,pp)

% LAST MODIFIED: 28/12/2020
maxrate=2;
% clear;
% clc;
% close all;

%% General settings

% Time interval delta (unit = second)
%delta = 1e-1; % 1 ms

% Epsilon value to avoid division by zero
%epsilon = 1e-5;

%% Ordering the coflows

n_coflows = length(coflows);
% # of coflows

coflows = utils.orderingCoflows(coflows, n_coflows,Order);
% assigning priority to coflows and ordering them (according to their priority)

%% Preparing outputs

% Initializing number of iterations to zero
t = 0;

plotStruct = struct('slot',{}, 'c_id',{}, 'f_id',{}, 'f_price', {}, 'f_drate',{},'f_adrate',{}, 'f_rvol',{});

for ii = 1:n_coflows
    coflows(ii).prices_prev = coflows(ii).prices;
end

%% Main loop

while (sum([coflows.state_c]) > 0)
% while there is still some flows active in the network
    
    t = t+1;
    % Updating step number
  %  fprintf('\n Number of iterations: %d\n', t)
    
%     if ~mod(t,1000)
%         t
%     end   
    
    fabric.sumRatesOnLink(:) = 0;
    fabric.sumAdjustedRatesOnLink = fabric.sumRatesOnLink(:);
    
    %% Cedric Last update: 2021/01/05
    Brem = linksCap;
    % End Cedric
    %%
%     if t> 990
%         aaa=2
%     end
    for c = coflows([coflows.state_c] == 1)
       if (c.priority == min([coflows([coflows.state_c] == 1).priority]))
           
           sharedLinks = find(sum(c.indicator,2) ~=0);
           % links used by the coflow prioritized coflow
           
           for l = 1:length(sharedLinks) % update the coflow prices on each link
               f_sharingLink = find(c.indicator(sharedLinks(l),:)); % find flows of coflow "c" sharing link "l"
               c.prices(sharedLinks(l)) = min(maxPrice, max(c.prices(sharedLinks(l)) + ...
                   beta * (sum([c.flows(f_sharingLink).d_rate]) -linksCap(l)),0));
           end
           
           
           
%% Start prices convergence (prioritized coflow)
           
           c.max_diff_prices = max(abs(c.prices - c.prices_prev));
      %     fprintf('\n prioritized: %d\n', c.max_diff_prices)
           
           if (c.max_diff_prices <= epsi)
               c.current_w = c.current_w + 1;
           else
               c.current_w = 0;
           end
           
           if (c.current_w >= w_size)
               c.stability = 1;
           else
               c.stability = 0;
           end
           
           if (c.stability == 1 && c.current_w == 10)
               c.ts_counter = c.ts_counter + 10;
           elseif (c.stability == 1 && c.current_w > 10)
               c.ts_counter = c.ts_counter + 1;
           end
           
           c.prices_prev = c.prices;
%% END prices convergence (prioritized coflow)
           
%   if (mod(t,updateVolStep) == 0 )
%               sum_f_v=0;
%               for f = c.flows
%                sum_f_v=sum_f_v+ f.remainingVolume;
%               end
%              end
           for f = c.flows
               if (f.state_f == 1)
                   f.price = c.prices * c.indicator(:,f.id); % computes the price of flow f belonging to coflow c
                   
                   % test
                   if (f.price == 0)
                       f.d_rate = min(linksCap(f.links));
                   else
                       f.d_rate = min(maxrate,(f.volume/div) / f.price); % computes the rate of flow f
                   end
%                    if (f.d_rate <= minRate)
%                        f.d_rate = 0;
%                    end
                   % end test 
                   
                   
                 %  if (mod(t,updateVolStep) == 0)
%                  a=rand(1)
%                  if a<pp
                if (mod(t,updateVolStep) == 0 && t==1 )
                       f.volume = f.remainingVolume;
                   end
                   fabric.sumRatesOnLink(f.links) = fabric.sumRatesOnLink(f.links) + f.d_rate;
                   plotStruct(end+1) = struct('slot',{t}, 'c_id',{c.id}, 'f_id',{f.id}, 'f_price', {f.price}, 'f_drate',{f.d_rate},'f_adrate',{f.ad_rate}, 'f_rvol',{f.remainingVolume});
               end
           end
           
       else
           
           sharedLinks = find(sum(c.indicator,2) ~=0);
           % links used by the coflow prioritized coflow
           
           c_prioritised = coflows([coflows.priority]<= c.priority & [coflows.state_c] == 1); 
           % coflows that are prioritizedc = coflows([coflows.state_c] == 1) over coflow c
           
           for l = 1:length(sharedLinks) % update the coflow prices on each link
               
               s = 0;
            
               for cp = c_prioritised
                   f_sharingLink = find(cp.indicator(sharedLinks(l),:)); % find flows sharing link l
                   if (cp.id ~= c.id)
                       s = s + sum([cp.flows(f_sharingLink).d_rate_old]);
                   else
                       s = s + sum([cp.flows(f_sharingLink).d_rate]);
                   end
                   
               end
               
               c.prices(sharedLinks(l)) = min(maxPrice, max(c.prices(sharedLinks(l)) + beta * (s -linksCap(l)),0));

           end
           
           
%% Start prices convergence

           c.max_diff_prices = max(abs(c.prices - c.prices_prev));
           %fprintf('id: %d - non-prioritized: %d\n',c.id, c.max_diff_prices)
           
           if (c.max_diff_prices <= epsi)
               c.current_w = c.current_w + 1;
           else
               c.current_w = 0;
           end
           
           if (c.current_w >= w_size)
               c.stability = 1;
           else
               c.stability = 0;
           end
           
           if (c.stability == 1 && c.current_w == 10)
               c.ts_counter = c.ts_counter + 10;
           elseif (c.stability == 1 && c.current_w > 10)
               c.ts_counter = c.ts_counter + 1;
           end
           
           c.prices_prev = c.prices;
%% END prices convergence 
%              if (mod(t,updateVolStep) == 0 )
%               sum_f_v=0;
%               for f = c.flows
%                sum_f_v=sum_f_v+ f.remainingVolume;
%               end
%              end
           for f = c.flows
               if (f.state_f == 1)
                   f.price = c.prices * c.indicator(:,f.id); % computes the price of flow f belonging to coflow c
%                    f.d_rate = (f.volume/div) / f.price; % computes the rate of flow f
% %                    if (f.d_rate <= minRate)
% %                        f.d_rate = 0;
% %                    end

                   % test
                   if (f.price == 0)
                       f.d_rate = min(linksCap(f.links));
                   elseif (f.volume/div) / f.price > epsilon
                       f.d_rate = min(maxrate,(f.volume/div) / f.price); % computes the rate of flow f
                   else f.d_rate =0;
                   end
                   % end test
                   
%                     a=rand(1)
%                  if a<pp
                   if (mod(t,updateVolStep) == 0 && t==1 )
                       f.volume = f.remainingVolume;
                   end
                   fabric.sumRatesOnLink(f.links) = fabric.sumRatesOnLink(f.links) + f.d_rate;
                   plotStruct(end+1) = struct('slot',{t}, 'c_id',{c.id}, 'f_id',{f.id}, 'f_price', {f.price}, 'f_drate',{f.d_rate}, 'f_adrate',{f.ad_rate}, 'f_rvol',{f.remainingVolume});
               end
           end
           
       end
       
    end
    
    %% Old adjusted rates computation
%     for c = coflows([coflows.state_c] == 1)
%         flows = [c.flows];
%         flows = flows([flows.state_f] == 1);
%         for f = flows
%             f.ad_rate = round(min(linksCap(f.links)*f.d_rate ./ max(fabric.sumRatesOnLink(f.links), linksCap(f.links))),6);
%             fabric.sumAdjustedRatesOnLink(f.links) = fabric.sumAdjustedRatesOnLink(f.links) + f.ad_rate;
%         end
%         
%     end


    %% New computation of adjusted rates Cedric (last update: 2021/01/05)
    for c  = coflows([coflows.state_c] == 1)
        flows = [c.flows];
        rates = [flows.d_rate];
        sumRatesLinks = c.indicator*rates';
        next_Brem = Brem;
        for f = flows
            p_ad_rates = round(Brem(f.links)*f.d_rate ./ max(sumRatesLinks(f.links),Brem(f.links)),6);
            p_ad_rates(isnan(p_ad_rates)) = 0;            
            next_Brem(f.links) = max(next_Brem(f.links) - round(p_ad_rates,5),0);            
            f.ad_rate = min(round(p_ad_rates,5));
            fabric.sumAdjustedRatesOnLink(f.links) = fabric.sumAdjustedRatesOnLink(f.links) + f.ad_rate;
        end
        Brem = next_Brem;
    end
    %End Cedric
    %%
    
    flows = [coflows([coflows.state_c] == 1).flows];
    flows = flows([flows.state_f] == 1);
    flows = utils.updateParamsFlows(flows, delta,t);
    
%     if ~mod(t,1000)
%         fprintf('\n Remaining volume: \n');
%         [flows.remainingVolume]
%         fprintf('\n Rates: \n');
%         [flows.d_rate]
%         fprintf('\n Prices: \n');
%         [flows.price]
%     end
    
%     fprintf('\n sum d_rates on links: \n')
%     fabric.sumRatesOnLink'
%     fprintf('\n sum ad_rates on links: \n')
%     fabric.sumAdjustedRatesOnLink'
%     fprintf('\n d_rates: \n')
%     [flows.d_rate]
%     fprintf('\n ad_rates: \n')
%     [flows.ad_rate]
    
    for c = coflows
        c.state_c = sum([flows([flows.idCoflow] == c.id).state_f] == 1) >= 1;
        if (c.state_c == 0 && c.departure == -1)
            c.departure = t;
        end
    end
end
%fprintf('\n Number of iterations: %d\n', t);


%% Computing CCTs metrics

outputs.coflows = utils.sortCoflowsByID(coflows);

outputs.CCTs = utils.computeCCTs(coflows);

outputs.av_CCT = mean(outputs.CCTs);

outputs.plotStruct = plotStruct;


outputs.nb_iter = t;


end

