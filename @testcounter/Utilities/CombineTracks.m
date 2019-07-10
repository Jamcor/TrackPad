function [tbl,CellProperties]=CombineTracks
% Combines track tables and alters Track_ID, Parent_ID and Daughter_ID (if
% exists
[FileName,PathName,FilterIndex]=uigetfile('*.mat','Select Track Files','MultiSelect','on');
S(1)=load([PathName FileName{1}]);
TrackerStateLength=size(S(1).tbl.Tracker_State,2);
Width=width(S(1).tbl);
for i=2:length(FileName)
    S(i)=load([PathName FileName{i}]);    
    if size(S(i).tbl.Tracker_State,2)>TrackerStateLength
        TrackerStateLength=size(S(i).tbl.Tracker_State,2);
    end; % need to make Track_State length uniform across tables so that they can be concatentated
end

for i=1:length(S)
    [h,w]=size(S(i).tbl.Tracker_State);
    if w<TrackerStateLength
        S(i).tbl.Tracker_State=cat(2,S(i).tbl.Tracker_State, cell(h,TrackerStateLength-w));
    end    
    if i>1
       
        if Width==size(S(i).tbl,2)
            S(i).tbl.Track_ID=S(i).tbl.Track_ID+height(tbl);
            S(i).tbl.Parent_ID=S(i).tbl.Parent_ID+height(tbl);
            tbl=cat(1,tbl,S(i).tbl);
        else
            disp([FileName{i} ' does not have the same number of fields as ' FileName{1}]);
        end
    else
        tbl=S(i).tbl;            
    end    
end
CellProperties=S(1).CellProperties;
TimeStamps=S(1).TimeStamps;
[SaveFileName,SavePathName]=uiputfile('*.mat');
save([SavePathName SaveFileName],'tbl','CellProperties','TimeStamps');