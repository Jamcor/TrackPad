function complete_clone=CreateCloneFiles(tracks,tbl,TimeStamps,varargin)

numb_tracks=length(tracks.Track_ID);
ancestor_IDs=unique([tracks.Ancestor_ID{:}]);
complete_clone={};

for i=1:length(ancestor_IDs)
   disp(['Ancestor is ' num2str(ancestor_IDs(i))]);
   complete_clone{i}.TimeStamps=TimeStamps;
   familyndx=([tracks.Ancestor_ID{:}]==ancestor_IDs(i)); 
   trackids=tracks.Track_ID{familyndx};
   
   for j=1:length(trackids)
   disp(['Progeny is ' num2str(trackids(j))]);
   complete_clone{i}.track{j}.TrackNum=tracks.Progeny_ID{trackids(j)};    
   complete_clone{i}.track{j}.T=tbl.time{trackids(j)};
   complete_clone{i}.track{j}.X=tbl.Position{trackids(j)}(:,1);
   complete_clone{i}.track{j}.Y=tbl.Position{trackids(j)}(:,2);
   complete_clone{i}.track{j}.Width=tbl.Position{trackids(j)}(:,3);
   complete_clone{i}.track{j}.Height=tbl.Position{trackids(j)}(:,4);
   
%      complete_clone{i}.track{j}.BirthTime=complete_clone{i}.track{j}.T(1)-TimeStamps(1);
%    complete_clone{i}.track{j}.DeathTime=complete_clone{i}.track{j}.T(end)-TimeStamps(1);
     complete_clone{i}.track{j}.BirthTime=complete_clone{i}.track{j}.T(1);
   complete_clone{i}.track{j}.DeathTime=complete_clone{i}.track{j}.T(end);
%    complete_clone{i}.track{j}.CellImages=tbl.Cell_Image{trackids(j)}
%    complete_clone{i}.track{j}.CellMask=tbl.Position{trackids(j)}

if isfield(tbl,'CellMask')
    
    complete_clone{i}.track{j}.Mask=squeeze(tbl.CellMask{trackids(j)});
end


stopreason=[tracks.Fate{trackids(j)}];
                    switch stopreason
                        case 'DI'
                            complete_clone{i}.track{j}.StopReason=1;
                        case 'NC'
                            complete_clone{i}.track{j}.StopReason=0;
                        case 'DE'
                            complete_clone{i}.track{j}.StopReason=2;
                        case 'LO'
                           complete_clone{i}.track{j}.StopReason=3;
                        case 'L'
                           complete_clone{i}.track{j}.StopReason=3;
                    end

   end
   
end

if length(varargin)==2
    condition=varargin{1};
    savepath=varargin{2};
if ~isdir([savepath condition])
   mkdir([savepath condition]);
end
save([savepath condition '\' condition ' clonefile.mat'],'complete_clone');
% else   
%     save([condition ' clonefile.mat'],'complete_clone');
end
return
end