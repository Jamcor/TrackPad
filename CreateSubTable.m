function tracks=CreateSubTable(tbl)
            [numb_tracks,~]=size(tbl);
            tracks=[];
            tracks.Track_ID=1:numb_tracks;
            tracks.Parent_ID=zeros(numb_tracks,1);
            tracks.Ancestor_ID=zeros(numb_tracks,1);
            tracks.Progeny_ID=zeros(numb_tracks,1);
            tracks.Generation_ID=zeros(numb_tracks,1);
            tracks.Daughter_IDs=cell(numb_tracks,1);
            tracks.Track_ID=(1:numb_tracks)';
            tracks.Fate=cell(numb_tracks,1);
            
            annotations=tbl.Annotation_Name{1}{2}; %same for all cells 
            
            for i=1:length(annotations)-1
            tracks=setfield(tracks,['Initial_' annotations{i}],cell(numb_tracks,1));
            tracks=setfield(tracks,['Final_' annotations{i}],cell(numb_tracks,1));
            end
            
            for i=1:numb_tracks
                if ~isempty(tbl.Parent_ID(i))
                    tracks.Parent_ID(i)=tbl.Parent_ID(i);
                else
                    tracks.Parent_ID(i)=NaN;
                end
                [~,lastframe]=size(tbl.time{i});
                tracks.Fate(i)=tbl.Annotation_Symbol{i}(1,lastframe);
                
                for j=1:length(annotations)-1
                    initial=getfield(tbl.Annotation_Symbol{i}{1,2},annotations{j});
                    final=getfield(tbl.Annotation_Symbol{i}{1,end-1},annotations{j});
                    tracks=setfield(tracks,['Initial_' annotations{j}],{i},{initial});
                    tracks=setfield(tracks,['Final_' annotations{j}],{i},{final});
                end
            end
            
            for i=1:length(tracks.Track_ID)
                k=i;
                while ~isnan(tracks.Parent_ID(k))
                    k=tracks.Parent_ID(k);
                end
                tracks.Ancestor_ID(i)=k;
            end
            
            ids=unique(tracks.Ancestor_ID);
            for i=1:length(ids)
                ndx=tracks.Ancestor_ID==ids(i);
                tracks.Ancestor_ID(ndx)=i;
            end
            %             tracks.Ancestor_ID=discretize(tracks.Ancestor_ID,...
            %                 length(unique(tracks.Ancestor_ID)));
            
            ndx=~isnan(tracks.Parent_ID);
            Parents=unique(tracks.Parent_ID(ndx));
            for i=1:length(Parents)
                Parent_ndx=tracks.Track_ID==Parents(i);
                Daughter_ndx=tracks.Parent_ID==Parents(i);
                tracks.Daughter_IDs{Parent_ndx}=(tracks.Track_ID(Daughter_ndx))';
            end
            
            for i=1:max(tracks(:).Ancestor_ID) %loop through ancestors
                ancestorndx=find(tracks(:).Ancestor_ID==i); % get ndx for all cells within pedigree
                %                 disp(['anc ' num2str(i)]);
                for j=1:length(ancestorndx) %Loop through all cells in pedigree
                    %                     disp(['cell ' num2str(j)]);               
                    parentid=tracks.Parent_ID(ancestorndx(j));
                    daughterid=tracks.Daughter_IDs{ancestorndx(j)}; %get parent and daughter ids
                    
                    if isnan(parentid) %parent cell
                        
                        tracks.Progeny_ID(ancestorndx(j))=1;
                        tracks.Generation_ID(ancestorndx(j))=0;
                        %if there are daughters
                        if ~isempty(daughterid)
                            if length(daughterid)==1
                                tracks.Progeny_ID(daughterid(1))=2;
                                tracks.Generation_ID(daughterid(1))=1;
                            else
                                tracks.Progeny_ID(daughterid(1))=2;
                                tracks.Progeny_ID(daughterid(2))=3;
                                tracks.Generation_ID(daughterid(1))=1;
                                tracks.Generation_ID(daughterid(2))=1;
                            end
                        end
                        
                    elseif ~isnan (parentid) && ~isempty(daughterid) %daughters
                        if length(daughterid)==1
                            progenyid=tracks.Progeny_ID(ancestorndx(j));
                            tracks.Progeny_ID(daughterid(1))=progenyid*2;
                            tracks.Generation_ID(daughterid(1))=tracks.Generation_ID(ancestorndx(j))+1;
                        else
                            progenyid=tracks.Progeny_ID(ancestorndx(j));
                            tracks.Progeny_ID(daughterid(1))=progenyid*2;
                            tracks.Progeny_ID(daughterid(2))=progenyid*2+1;
                            tracks.Generation_ID(daughterid(1))=tracks.Generation_ID(ancestorndx(j))+1;
                            tracks.Generation_ID(daughterid(2))=tracks.Generation_ID(ancestorndx(j))+1;
                        end
                    end
                    
                end
            end
            tracks.Parent_ID=arrayfun(@(x) {x},tracks.Parent_ID)';
            tracks.Track_ID=arrayfun(@(x) {x},tracks.Track_ID);
            tracks.Ancestor_ID=arrayfun(@(x) {x},tracks.Ancestor_ID);
            tracks.Progeny_ID=arrayfun(@(x) {x},tracks.Progeny_ID);
            tracks.Generation_ID=arrayfun(@(x) {x},tracks.Generation_ID);

            return
        end