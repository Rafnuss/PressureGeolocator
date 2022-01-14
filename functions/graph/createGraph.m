function [gr,nds] = createGraph(prob_map,lat,lon,calib,actEffort,thr_prob_percentile,thr_gs)
% Create the graph (vectors of sink and source index in the matrix) from a
% proabibilty map and a threashold of ground_speed


% Start with building up the standard gr structure 
gr.lat = lat;
gr.lon = lon;
gr.snds = [numel(gr.lat), numel(gr.lon), size(prob_map,3)];
gr.actEffort = hours(actEffort);%max(1,hours(actEffort));

% Create the index matrix of all coordinate (space-time) of the grid
% idx=reshape(1:numel(prob_map),size(prob_map));


% Normalize the probability map for each night
prob_map = prob_map ./ sum(prob_map,[1 2]);

% Set threashold corresponding to all nodes corresponding to
% thr_prob_percentile of the probability for each stationary period
tmp = sort(reshape(prob_map,[],gr.snds(3)));
thr_prob = tmp(sub2ind(size(tmp),sum(cumsum(tmp)<=(1-thr_prob_percentile)),1:gr.snds(3)));

% Set first and last one to true only at the known location.
[~, tmp1] = min(abs(gr.lat(:)-calib.lat));
[~, tmp2] = min(abs(gr.lon(:)-calib.lon));
prob_map(:,:,1)=0;
prob_map(tmp1,tmp2,1)=1;
if ~any(isnat(calib.second_period))
    prob_map(:,:,end)=0;
    prob_map(tmp1,tmp2,end)=1;
end

% find location above the prob threashold
nds = prob_map>=reshape(thr_prob,1,1,[]);
assert(all(sum(nds,[1 2])>0),['No possible location at stationary period: ' num2str(find(sum(nds,[1 2])==0)')])

% filter nds with distance 
resolution=0.25*111;
for i=1:3
    for i_s=1:size(nds,3)-1
        nds(:,:,i_s+1) = bwdist(nds(:,:,i_s)) < gr.actEffort(i_s)*thr_gs/resolution & nds(:,:,i_s+1);
        assert(sum(nds(:,:,i_s+1),'all')>0,'No more point avialable')
    end
    for i_s=size(nds,3):-1:2
        nds(:,:,i_s-1) = bwdist(nds(:,:,i_s)) < gr.actEffort(i_s-1)*thr_gs/resolution & nds(:,:,i_s-1);
        assert(sum(nds(:,:,i_s-1),'all')>0,'No more point avialable')
    end
end

% figure; tiledlayout('flow','TileSpacing','tight','Padding','tight');
% for i_s=1:size(nds,3)
%     nexttile; imagesc(nds(:,:,i_s))
% end

% Create the source S and target T
S=cell(gr.snds(3)-1,1);
T=cell(gr.snds(3)-1,1);
for i_s = 1:gr.snds(3)-1
    % Get index of the source and target according to the mask
    [S{i_s}, T{i_s}]= meshgrid(find(nds(:,:,i_s))+(i_s-1)*prod(gr.snds(1:2)), find(nds(:,:,i_s+1))+i_s*prod(gr.snds(1:2)));
end

gr.lastNodes=unique(T{end});

% Convert the cells to matrix
gr.s = cell2mat(cellfun(@(x) x(:),S,'UniformOutput',false));
gr.t = cell2mat(cellfun(@(x) x(:),T,'UniformOutput',false));


%% Compute GS
[Slat,Slon,St]=ind2sub(gr.snds,gr.s);
[Tlat,Tlon,~]=ind2sub(gr.snds,gr.t);

% tmp1 = lldistkm([lon(Slon) lat(Slat)], [lon(Tlon) lat(Slat)],'pythagoran');
% tmp2 = lldistkm([lon(Slon) lat(Slat)], [lon(Slon) lat(Tlat)],'pythagoran');
% tmp =[tmp1 tmp2]./actEffortHr(St);
% 
% % Add the sign
% gr.gs = sum([sign(lon(Tlon)-lon(Slon)) sign(lat(Tlat)-lat(Slat))].*tmp .* [1 1i],2);

gr.gs = resolution.*((Tlon-Slon).*cos(pi/180*lat(floor((Tlat+Slat)/2)))+1i.*(Tlat-Slat))./gr.actEffort(St);


%% Probability static 
gr.ps = prob_map(gr.t);

end