% -------------------------------------------------------------------------
function live_paths = incremental_linking(frames,iouth,costtype,jumpgap,threhgap)
% -------------------------------------------------------------------------

num_frames = length(frames);

%% online path building

live_paths = struct(); %% Stores live paths
dead_paths = struct(); %% Store the paths that has been terminated
dp_count = 0;
for  t = 1:num_frames
    num_box = size(frames(t).boxes,1);
    if t==1
        for b = 1 : num_box
            live_paths(b).boxes = frames(t).boxes(b,:);
            live_paths(b).scores = frames(t).scores(b);
            live_paths(b).allScores(t,:) = frames(t).allScores(b,:);
            live_paths(b).pathScore = frames(t).scores(b);
            live_paths(b).foundAT(t) = 1;
            live_paths(b).count = 1;
            live_paths(b).lastfound = 0; %less than 5 mean yes
        end
    else
        lp_count = getPathCount(live_paths);
        
        %         fprintf(' %d ', t);
        edge_scores = zeros(lp_count,num_box);
        
        for lp = 1 : lp_count
            edge_scores(lp,:) = score_of_edge(live_paths(lp),frames(t),iouth,costtype);
        end
        
        
        dead_count = 0 ;
        coverd_boxes = zeros(1,num_box);
        path_order_score = zeros(1,lp_count);
        for lp = 1 : lp_count
            if live_paths(lp).lastfound < jumpgap %less than 5 mean yes
                box_to_lp_score = edge_scores(lp,:);
                if sum(box_to_lp_score)>0 %%checking if atleast there is one match
                    [m_score,maxInd] = max(box_to_lp_score);
                    live_paths(lp).count = live_paths(lp).count + 1;
                    lpc = live_paths(lp).count;
                    live_paths(lp).boxes(lpc,:) = frames(t).boxes(maxInd,:);
                    live_paths(lp).scores(lpc) = frames(t).scores(maxInd);
                    live_paths(lp).allScores(lpc,:) = frames(t).allScores(maxInd,:);
                    live_paths(lp).pathScore = live_paths(lp).pathScore + m_score;
                    live_paths(lp).foundAT(lpc) = t;
                    live_paths(lp).lastfound = 0;
                    edge_scores(:,maxInd) = 0;
                    coverd_boxes(maxInd) = 1;
                else
                    live_paths(lp).lastfound = live_paths(lp_count).lastfound +1;
                end
                
                scores = sort(live_paths(lp).scores,'ascend');
                num_sc = length(scores);
                path_order_score(lp) = mean(scores(max(1,num_sc-jumpgap):num_sc));
                
            else
                dead_count = dead_count + 1;
            end
        end
        
        % Sort the path based on scoe of the boxes and terminate dead path
        
        [live_paths,dead_paths,dp_count] = sort_live_paths(live_paths,....
            path_order_score,dead_paths,dp_count,jumpgap);
        lp_count = getPathCount(live_paths);
        % start new paths using boxes that are not assigned
        if sum(coverd_boxes)<num_box
            for b = 1 : num_box
                if ~coverd_boxes(b)
                    lp_count = lp_count + 1;
                    live_paths(lp_count).boxes = frames(t).boxes(b,:);
                    live_paths(lp_count).scores = frames(t).scores(b);
                    live_paths(lp_count).allScores = frames(t).allScores(b,:);
                    live_paths(lp_count).pathScore = frames(t).scores(b);
                    live_paths(lp_count).foundAT = t;
                    live_paths(lp_count).count = 1;
                    live_paths(lp_count).lastfound = 0;
                end
            end
        end
    end
end

live_paths = fill_gaps(live_paths,threhgap);
dead_paths = fill_gaps(dead_paths,threhgap);
lp_count = getPathCount(live_paths);
lp = lp_count+1;
if isfield(dead_paths,'boxes')
    for dp = 1 : length(dead_paths)
        live_paths(lp).start = dead_paths(dp).start;
        live_paths(lp).end = dead_paths(dp).end;
        live_paths(lp).boxes = dead_paths(dp).boxes;
        live_paths(lp).scores = dead_paths(dp).scores;
        live_paths(lp).allScores = dead_paths(dp).allScores;
        live_paths(lp).pathScore = dead_paths(dp).pathScore;
        live_paths(lp).foundAT = dead_paths(dp).foundAT;
        live_paths(lp).count = dead_paths(dp).count;
        live_paths(lp).lastfound = dead_paths(dp).lastfound;
        lp = lp + 1;
    end
end

live_paths = sort_paths(live_paths);


% -------------------------------------------------------------------------
function sorted_live_paths = sort_paths(live_paths)
% -------------------------------------------------------------------------
sorted_live_paths = struct();

lp_count = getPathCount(live_paths);
if lp_count>0
    path_order_score = zeros(1,lp_count);
    
    for lp = 1 : length(live_paths)
        scores = sort(live_paths(lp).scores,'descend');
        num_sc = length(scores);
        path_order_score(lp) = mean(scores(1:min(20,num_sc)));
    end
    
    [~,ind] = sort(path_order_score,'descend');
    for lpc = 1 : length(live_paths)
        olp = ind(lpc);
        sorted_live_paths(lpc).start = live_paths(olp).start;
        sorted_live_paths(lpc).end = live_paths(olp).end;
        sorted_live_paths(lpc).boxes = live_paths(olp).boxes;
        sorted_live_paths(lpc).scores = live_paths(olp).scores;
        sorted_live_paths(lpc).allScores = live_paths(olp).allScores;
        sorted_live_paths(lpc).pathScore = live_paths(olp).pathScore;
        sorted_live_paths(lpc).foundAT = live_paths(olp).foundAT;
        sorted_live_paths(lpc).count = live_paths(olp).count;
        sorted_live_paths(lpc).lastfound = live_paths(olp).lastfound;
    end
end

% -------------------------------------------------------------------------
function gap_filled_paths = fill_gaps(paths,gap)
% -------------------------------------------------------------------------
gap_filled_paths = struct();
if isfield(paths,'boxes')
    g_count = 1;
    
    for lp = 1 : getPathCount(paths)
        if length(paths(lp).foundAT)>gap
            gap_filled_paths(g_count).start = paths(lp).foundAT(1);
            gap_filled_paths(g_count).end = paths(lp).foundAT(end);
            gap_filled_paths(g_count).pathScore = paths(lp).pathScore;
            gap_filled_paths(g_count).foundAT = paths(lp).foundAT;
            gap_filled_paths(g_count).count = paths(lp).count;
            gap_filled_paths(g_count).lastfound = paths(lp).lastfound;
            count = 1;
            i = 1;
            while i <= length(paths(lp).scores)
                diff_found = paths(lp).foundAT(i)-paths(lp).foundAT(max(i-1,1));
                if count == 1 || diff_found == 1
                    gap_filled_paths(g_count).boxes(count,:) = paths(lp).boxes(i,:);
                    gap_filled_paths(g_count).scores(count) = paths(lp).scores(i);
                    gap_filled_paths(g_count).allScores(count,:) = paths(lp).allScores(i,:);
                    i = i + 1;
                    count = count + 1;
                else
                    for d = 1 : diff_found
                        gap_filled_paths(g_count).boxes(count,:) = paths(lp).boxes(i,:);
                        gap_filled_paths(g_count).scores(count) = paths(lp).scores(i);
                        gap_filled_paths(g_count).allScores(count,:) = paths(lp).allScores(i,:);
                        count = count + 1;
                    end
                    i = i + 1;
                end
            end
            g_count = g_count + 1;
        end
    end
end


% -------------------------------------------------------------------------
function [sorted_live_paths,dead_paths,dp_count] = sort_live_paths(live_paths,...
    path_order_score,dead_paths,dp_count,gap)
% -------------------------------------------------------------------------

sorted_live_paths = struct();
[~,ind] = sort(path_order_score,'descend');
lpc = 0;
for lp = 1 : getPathCount(live_paths)
    olp = ind(lp);
    if live_paths(ind(lp)).lastfound < gap
        lpc = lpc + 1;
        sorted_live_paths(lpc).boxes = live_paths(olp).boxes;
        sorted_live_paths(lpc).scores = live_paths(olp).scores;
        sorted_live_paths(lpc).allScores = live_paths(olp).allScores;
        sorted_live_paths(lpc).pathScore = live_paths(olp).pathScore;
        sorted_live_paths(lpc).foundAT = live_paths(olp).foundAT;
        sorted_live_paths(lpc).count = live_paths(olp).count;
        sorted_live_paths(lpc).lastfound = live_paths(olp).lastfound;
    else
        dp_count = dp_count + 1;
        dead_paths(dp_count).boxes = live_paths(olp).boxes;
        dead_paths(dp_count).scores = live_paths(olp).scores;
        dead_paths(dp_count).allScores = live_paths(olp).allScores;
        dead_paths(dp_count).pathScore = live_paths(olp).pathScore;
        dead_paths(dp_count).foundAT = live_paths(olp).foundAT;
        dead_paths(dp_count).count = live_paths(olp).count;
        dead_paths(dp_count).lastfound = live_paths(olp).lastfound;
        
    end
end




% -------------------------------------------------------------------------
function score = score_of_edge(v1,v2,iouth,costtype)
% -------------------------------------------------------------------------

N2 = size(v2.boxes,1);
score = zeros(1,N2);

% try
bounds1 = [v1.boxes(end,1:2) v1.boxes(end,3:4)-v1.boxes(end,1:2)+1];
% catch
%     fprintf('catch here')
% end
bounds2 = [v2.boxes(:,1:2) v2.boxes(:,3:4)-v2.boxes(:,1:2)+1];
iou = inters_union(bounds1,bounds2);

for i = 1 : N2
    
    if iou(i)>=iouth
        
        scores2 = v2.scores(i);
        scores1 = v1.scores(end);
        score_similarity = sqrt(sum((v1.allScores(end,:) - v2.allScores(i,:)).^2));
        if strcmp(costtype, 'score')
            score(i) =  scores2;
        elseif strcmp(costtype, 'scrSim')
            score(i) = 1-score_similarity;
        elseif strcmp(costtype, 'scrMinusSim')
            score(i) = scores2 + (1 - score_similarity);
        end
        
    end
    
end

% -------------------------------------------------------------------------
function lp_count = getPathCount(live_paths)
% -------------------------------------------------------------------------

if isfield(live_paths,'boxes')
    lp_count = length(live_paths);
else
    lp_count = 0;
end

% -------------------------------------------------------------------------
function iou = inters_union(bounds1,bounds2)
% -------------------------------------------------------------------------

inters = rectint(bounds1,bounds2);
ar1 = bounds1(:,3).*bounds1(:,4);
ar2 = bounds2(:,3).*bounds2(:,4);
union = bsxfun(@plus,ar1,ar2')-inters;

iou = inters./(union+eps);
