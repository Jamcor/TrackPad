classdef TrackCollection < handle
    % TrackCollection is a container for all track objects
    
    
    properties
        CurrentTrack % always has a reference to the current track even if its not complete
        Tracks
        Editing=false;
        %listens to the following objects
        CntrlObj
        CurrentTrackID=0;
        TableData
        tbl
    end
    
    events
        AppendedTrackEvent
    end
    
    methods
        function obj=TrackCollection(Track)
            if nargin==1
                %initialise with reference to first track.
                obj.CurrentTrack=Track;
            end
        end
        
        function Append(obj,hObject,EventData)
            % appends track to trackcollection
            hTrackPad=obj.CntrlObj;
            axes(hTrackPad.ImageHandle.Parent); % make sure text is written in trackpad.
            CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
            if isempty(obj.Tracks)
                obj.Tracks(1).Track=obj.CurrentTrack;
                delete(obj.Tracks(1).Track.StopListenerHandle);
                delete(obj.Tracks(1).Track.PauseListenerHandle);
                %default annotation
                n=find(cellfun(@(x) ~isempty(x),obj.Tracks(1).Track.Track),1,'first'); %find first and last frame
                m=find(cellfun(@(x) ~isempty(x),obj.Tracks(1).Track.Track),1,'last');
                % Annotate origin and Ancestor
                obj.Tracks(1).Track.Track{n}.Annotation.Name=hTrackPad.CellProperties(1).Name;
                obj.Tracks(1).Track.Track{n}.Annotation.Type=hTrackPad.CellProperties(1).Type{1};
                obj.Tracks(1).Track.Track{n}.Annotation.Symbol=hTrackPad.CellProperties(1).Symbol{1};
                Position=obj.Tracks(1).Track.Track{n}.Position;
                x=Position(1)+Position(3)/2;
                y=Position(2)+Position(4)/2;
                obj.Tracks(1).Track.Track{n}.AnnotationHandle=text(x,y,... %first frame
                    hTrackPad.CellProperties(1).Symbol{1},...
                    'Color','g','HorizontalAlignment','center','Visible','off','PickableParts','none');
                % Annotated fate as Not complete
                obj.Tracks(1).Track.Track{m}.Annotation.Name=hTrackPad.CellProperties(2).Name;
                obj.Tracks(1).Track.Track{m}.Annotation.Type=hTrackPad.CellProperties(2).Type{1};
                obj.Tracks(1).Track.Track{m}.Annotation.Symbol=hTrackPad.CellProperties(2).Symbol{1};
                Position=obj.Tracks(1).Track.Track{m}.Position;
                x=Position(1)+Position(3)/2;
                y=Position(2)+Position(4)/2;
                obj.Tracks(1).Track.Track{m}.AnnotationHandle=text(x,y,... %last frame
                    hTrackPad.CellProperties(2).Symbol{1},...
                    'Color','g','HorizontalAlignment','center','Visible','off','PickableParts','none');
                if m==CurrentNdx
                    obj.Tracks(1).Track.Track{m}.AnnotationHandle.Visible='on';
                end
                obj.Tracks(1).Parent=[]; % no parent at this stage
                obj.Tracks(1).ParentID=[];
%                 obj.Tracks(1).
                obj.Tracks(1).Track.trackrange=[n,m];
                % Annotate all other timepoints as NA (No Annotation)
                fnames=fieldnames(hTrackPad.CellProperties(3).Type);
                for i=(n+1):(m-1) %all other frames
                    obj.Tracks(1).Track.Track{i}.Annotation.Name=fnames;
                    obj.Tracks(1).Track.Track{i}.Annotation.Type=structfun(@(x) x{1},hTrackPad.CellProperties(3).Type,'UniformOutput',0);
                    obj.Tracks(1).Track.Track{i}.Annotation.Symbol=structfun(@(x) x{1},hTrackPad.CellProperties(3).Symbol,'UniformOutput',0);
                    Position=obj.Tracks(1).Track.Track{i}.Position;
                    x=Position(1)+Position(3)/2;
                    y=Position(2)+Position(4)/2;
                    obj.Tracks(1).Track.Track{i}.AnnotationHandle=[];
%                     obj.Tracks(1).Track.Track{i}.AnnotationHandle=text(x,y,...  %display fluorescent annotations by defualt
%                         hTrackPad.CellProperties(3).Symbol.(fnames{1}){1},...
%                         'Color','g','HorizontalAlignment','center','Visible','off','PickableParts','none');
                    if i==CurrentNdx
                        obj.Tracks(1).Track.Track{i}.AnnotationHandle.Visible='on';
                    end
                end
                obj.TableData=SubTable(obj);
                
                %update track panel
                hTrackPad.TrackPanel.ClonesPopup.String=mat2cell(hTrackPad.Tracks.TableData.Ancestor_ID,...
                    length(hTrackPad.Tracks.TableData.Ancestor_ID),1);
            else
                %default annotation
                obj.Tracks(end+1).Track=obj.CurrentTrack;
                delete(obj.Tracks(end).Track.PauseListenerHandle);
                delete(obj.Tracks(end).Track.StopListenerHandle);
                n=find(cellfun(@(x) ~isempty(x),obj.Tracks(end).Track.Track),1,'first');
                m=find(cellfun(@(x) ~isempty(x),obj.Tracks(end).Track.Track),1,'last');
                obj.Tracks(end).Track.trackrange=[n,m];
                if n<m % don't want to write AN and NC on the same cells
                    obj.Tracks(end).Track.Track{n}.Annotation.Name=hTrackPad.CellProperties(1).Name;
                    obj.Tracks(end).Track.Track{n}.Annotation.Type=hTrackPad.CellProperties(1).Type{1};
                    obj.Tracks(end).Track.Track{n}.Annotation.Symbol=hTrackPad.CellProperties(1).Symbol{1};
                    Position=obj.Tracks(end).Track.Track{n}.Position;
                    x=Position(1)+Position(3)/2;
                    y=Position(2)+Position(4)/2;
                    obj.Tracks(end).Track.Track{n}.AnnotationHandle=[];
%                     obj.Tracks(end).Track.Track{n}.AnnotationHandle=text(x,y,...
%                         hTrackPad.CellProperties(1).Symbol{1},...
%                         'Color','g','HorizontalAlignment','center','Visible','off','PickableParts','none');
                    if n==CurrentNdx
                    obj.Tracks(end).Track.Track{n}.AnnotationHandle=text(x,y,...
                        hTrackPad.CellProperties(1).Symbol{1},...
                        'Color','g','HorizontalAlignment','center','Visible','on','PickableParts','none');                        
%                         obj.Tracks(end).Track.Track{n}.AnnotationHandle.Visible='on';
                    end
                end
                % Annotated fate as Not complete
                obj.Tracks(end).Track.Track{m}.Annotation.Name=hTrackPad.CellProperties(2).Name;
                obj.Tracks(end).Track.Track{m}.Annotation.Type=hTrackPad.CellProperties(2).Type{1};
                obj.Tracks(end).Track.Track{m}.Annotation.Symbol=hTrackPad.CellProperties(2).Symbol{1};
                Position=obj.Tracks(end).Track.Track{m}.Position;
                x=Position(1)+Position(3)/2;
                y=Position(2)+Position(4)/2;
                obj.Tracks(end).Track.Track{m}.AnnotationHandle=text(x,y,...
                    hTrackPad.CellProperties(2).Symbol{1},...
                    'Color','g','HorizontalAlignment','center','Visible','off','PickableParts','none');
                if m==CurrentNdx
                    obj.Tracks(end).Track.Track{m}.AnnotationHandle.Visible='on';
                end
                obj.Tracks(end).Parent=[]; % no parent at this stage
                obj.Tracks(end).ParentID=[];
                % Annotate all other cells as NA (No Annotation)
                fnames=fieldnames(hTrackPad.CellProperties(3).Type);
                for i=(n+1):(m-1)
                    obj.Tracks(end).Track.Track{i}.Annotation.Name=fnames;
                    obj.Tracks(end).Track.Track{i}.Annotation.Type=structfun(@(x) x{1},hTrackPad.CellProperties(3).Type,'UniformOutput',0);
                    obj.Tracks(end).Track.Track{i}.Annotation.Symbol=structfun(@(x) x{1},hTrackPad.CellProperties(3).Symbol,'UniformOutput',0);
                    Position=obj.Tracks(end).Track.Track{i}.Position;
                    x=Position(1)+Position(3)/2;
                    y=Position(2)+Position(4)/2;
                    obj.Tracks(end).Track.Track{i}.AnnotationHandle=text(x,y,...
                        hTrackPad.CellProperties(3).Symbol.(fnames{1}){1},...
                        'Color','g','HorizontalAlignment','center','Visible','off','PickableParts','none');
                    if i==CurrentNdx
                        obj.Tracks(end).Track.Track{i}.AnnotationHandle.Visible='on';
                    end
                end
            end
            obj.TableData=SubTable(obj);
            pedigree_id=obj.TableData.Ancestor_ID(end);
            progeny_id=obj.TableData.Progeny_ID(end);
            for i=(n+1):(m-1)
                obj.Tracks(end).Track.Track{i}.Annotation.Type.PedigreeID=['Pedigree ' num2str(pedigree_id) ' Track ' num2str(progeny_id)];
                obj.Tracks(end).Track.Track{i}.Annotation.Symbol.PedigreeID=['P' num2str(pedigree_id) 'Tr' num2str(progeny_id)];
            end
            
            obj.CurrentTrack=[]; % reset
            obj.CurrentTrackID=0;
            notify(obj,'AppendedTrackEvent');
        end
        
        function Remove(obj,hObject,EventData)
            % removes CurrentTrack, and reindexes TrackCollection
            if obj.CurrentTrackID<length(obj.Tracks)
                for i=obj.CurrentTrackID:(length(obj.Tracks)-1)
                    obj.Tracks(i)= obj.Tracks(i+1); % fill in gap
                end
            end
            
            if length(obj.Tracks)==1
                obj.Tracks=[];
            else
                obj.Tracks=obj.Tracks(1:end-1);
            end
            obj.CurrentTrackID=0;
            obj.CurrentTrack=[];
        end
               
        function CreateTracks(obj,hObject,EventData)
            beep off;
            if ~isa(obj.CntrlObj.ImageStack,'ImageStack')
                error('Image stack not loaded');
            end
            NumberOfImages=obj.CntrlObj.ImageStack.NumberOfImages;
            h=waitbar(0,'Loading tracks','WindowStyle','Modal');
            fnames=fieldnames(obj.CntrlObj.CellProperties(3).Type);
            obj.CntrlObj.AnnotationDisplay='None'; %turn off annotations for loading tracks
            for i=1:height(obj.tbl)
                % create track
                waitbar(i/height(obj.tbl),h);
                axes(obj.CntrlObj.ImageHandle.Parent); % make sure you reset current axes to image after waitbar
                Parent_ID=obj.tbl.Parent_ID(i);
                Image_Number=obj.tbl.Image_Number{i};
                range=[Image_Number(1),Image_Number(end)];
                Position=obj.tbl.Position{i}; %get position of track i in first frame
                Cell_Image=obj.tbl.Cell_Image{i};
                %                  Mask=obj.tbl.Mask{i};
                Annotation=struct('Name',obj.tbl.Annotation_Name{i},'Type',obj.tbl.Annotation_type{i},...
                    'Symbol',obj.tbl.Annotation_Symbol{i});
                Result=struct('rho',obj.tbl.rho{i},'pval',obj.tbl.pval{i},...
                    'ElapsedTime',obj.tbl.Processor_Time{i},'Time',...
                    obj.tbl.Tracking_Time{i});
                FindCellState=obj.tbl.Tracker_State(i,:); %find tracker state (e.g. 'go','lost')
                obj.CurrentTrackID=i; %current track being processed
                hellipse=imellipse(obj.CntrlObj.ImageHandle.Parent,Position(1,:)); %get ellipse on TrackPad axes
                set(hellipse,'PickableParts','none');
                setResizable(hellipse,0);
                obj.CntrlObj.CurrentTrackingParameters.NucleusRadius=obj.tbl.CellRadius{i};
                obj.CntrlObj.CurrentTrackingParameters.SearchRadius=obj.tbl.SearchRadius{i};
                obj.CntrlObj.CurrentTrackingParameters.CorrelationThreshold=obj.tbl.CorrelationThreshold{i};
                obj.CntrlObj.Track=tracker(range,hellipse,obj.CntrlObj);
                %delete listeners (track won't be modified)
                delete(obj.CntrlObj.Track.EndTrackListener);
                delete(obj.CntrlObj.Track.LostCellListener);
                delete(obj.CntrlObj.Track.StopListenerHandle);
                delete(obj.CntrlObj.Track.PauseListenerHandle);
                obj.CntrlObj.ImageStack.CurrentNdx=range(1); %get first frames that cell is present
                obj.CntrlObj.Track.FindCellState='stop'; % don't allow editing of saved tracks
                % obj.CntrlObj.Track.Track{range(1)}.Mask=Mask(:,:,1);
%                 obj.CntrlObj.Track.Track{range(1)}.Mask=find(createMask(hellipse)>0);
%                 obj.CntrlObj.Track.Track{range(1)}.CellIm=Cell_Image(:,:,1);
                obj.CntrlObj.Track.Track{range(1)}.ImageNumber=Image_Number(1);
                obj.CntrlObj.Track.Track{range(1)}.Position=Position(1,:);
                obj.CntrlObj.Track.Track{range(1)}.Annotation=Annotation(1);
%                 x=Position(1,1)+Position(1,3)/2;
%                 y=Position(1,2)+Position(1,4)/2;
%                 obj.CntrlObj.Track.Track{range(1)}.AnnotationHandle=text(x,y,...
%                     obj.CntrlObj.Track.Track{range(1)}.Annotation.Symbol,'Color','g',...
%                     'HorizontalAlignment','center','PickableParts','none');
                delete(hellipse);
                for j=1:(range(2)-range(1))
%                     hellipse=imellipse(obj.CntrlObj.ImageHandle.Parent,Position(j+1,:));
%                     set(hellipse,'Visible','off');
%                     setResizable(hellipse,0);
%                     set(hellipse,'PickableParts','none');
                    obj.CntrlObj.Track.Track{range(1)+j}=CellImage; %calls @CellImage
%                     obj.CntrlObj.Track.Track{range(1)+j}.EllipseHandle=hellipse;
                    obj.CntrlObj.Track.Track{range(1)+j}.ParentTracker=obj.CntrlObj.Track;
                    %                      obj.CntrlObj.Track.Track{range(1)+j}.Mask=Mask(:,:,j+1);
%                     obj.CntrlObj.Track.Track{range(1)+j}.Mask=find(createMask(hellipse)>0);
%                     obj.CntrlObj.Track.Track{range(1)+j}.CellIm=Cell_Image(:,:,j+1);
                    obj.CntrlObj.Track.Track{range(1)+j}.ImageNumber=Image_Number(j+1);
                    obj.CntrlObj.Track.Track{range(1)+j}.Position=Position(j+1,:);
                    obj.CntrlObj.Track.Track{range(1)+j}.Annotation=Annotation(j+1);
%                     x=Position(j+1,1)+Position(j+1,3)/2;
%                     y=Position(j+1,2)+Position(j+1,4)/2;
%                     if (j+range(1))<range(2)
%                         obj.CntrlObj.Track.Track{range(1)+j}.AnnotationHandle=text(x,y,...
%                             obj.CntrlObj.Track.Track{range(1)+j}.Annotation.Symbol.(fnames{1}),'Color','g',...
%                             'HorizontalAlignment','center','PickableParts','none','Visible','off');%disp fluo annotation by default
%                     elseif (j+range(1))==range(2)
%                         obj.CntrlObj.Track.Track{range(1)+j}.AnnotationHandle=text(x,y,...
%                             obj.CntrlObj.Track.Track{range(1)+j}.Annotation.Symbol,'Color','g',...
%                             'HorizontalAlignment','center','PickableParts','none','Visible','off');%disp fate in last frame
%                     end
                    obj.CntrlObj.Track.Track{range(1)+j}.Result.rho=Result.rho(j+1);
                    obj.CntrlObj.Track.Track{range(1)+j}.Result.pval=Result.pval(j+1);
                    %                      obj.CntrlObj.Track.Track{range(1)+j}.Result.ElapsedTime=Result.ElapsedTime;
                    obj.CntrlObj.Track.Track{range(1)+j}.Result.ElapsedTime=Result.ElapsedTime(j+1);
                    obj.CntrlObj.Track.Track{range(1)+j}.Result.Time=Result.Time(j+1);
%                     obj.CntrlObj.Track.Track{range(1)+j}.Result.FindCellState=FindCellState{j+1};
                    obj.CntrlObj.Track.Track{range(1)+j}.Result.FindCellState=FindCellState{range(1)+j};
                    obj.CntrlObj.Track.Track{range(1)+j}.CntrlObj=obj.CntrlObj;
                    delete(hellipse);
                end
                obj.Tracks(i).Track=obj.CntrlObj.Track; %add current track to list of tracks
                if ~isnan(Parent_ID)
                    obj.Tracks(i).ParentID=Parent_ID;
                    obj.Tracks(i).Parent=obj.Tracks(Parent_ID).Track; %obk.track
                else
                    obj.Tracks(i).ParentID=[];
                    obj.Tracks(i).Parent=[];
                end
            end
            obj.CntrlObj.ImageContextMenu.EditTrack.Visible='off';
            obj.CntrlObj.ImageContextMenu.StopTrack.Visible='off';
            obj.CntrlObj.ImageContextMenu.ContinueTrack.Visible='off';
            obj.CntrlObj.ImageContextMenu.DeleteTrack.Visible='off';
            obj.CntrlObj.ImageContextMenu.SelectTrack.Visible='on';
            obj.TableData=SubTable(obj);
            UpdatePedigreeId(obj); %update pedigree id annotations            
            obj.CurrentTrackID=0;  % ensures that next track will be appended!
            obj.CntrlObj.Track=[]; % current track can no longer be edited.
            close(h);
        end
        
        function CreateTable(obj,hObject,EventData)
            NTracks=length(obj.Tracks);
            [~,~,~,n]=size(obj.Tracks(1).Track.Stack.Stack);
            AcquisitionTimes=obj.Tracks(1).Track.Stack.AcquisitionTimes;
            Position=cell(NTracks,1);
            t=cell(NTracks,1);
            CellIm=cell(NTracks,1);
            CellMask=cell(NTracks,1);
            FileID=struct('Name',cell(NTracks,1));
            AnnotationName=cell(NTracks,1);
            AnnotationType=cell(NTracks,1);
            AnnotationSymbol=cell(NTracks,1);
            ImageNumber=cell(NTracks,1);
            CellRadius=cell(NTracks,1);
            SearchRadius=cell(NTracks,1);
            CorrelationThreshold=cell(NTracks,1);
            rho=cell(NTracks,1);
            ElapsedTime=cell(NTracks,1);
            Time=cell(NTracks,1);
            FindCellState=cell(NTracks,n);
            pval=cell(NTracks,1);
            ParentID=zeros(NTracks,1);
            TrackID=zeros(NTracks,1);
            h=waitbar(0,'Saving tracks');
            for i=1:NTracks
                disp(num2str(i));
                waitbar(i/NTracks,h);
                if ~isempty(obj.Tracks(i).ParentID)
                    ParentID(i)=obj.Tracks(i).ParentID;
                else
                    ParentID(i)=NaN;
                end
                TrackID(i)=i;
                FileID(i).Name=cell(n,1);
                CellRadius{i}=obj.Tracks(i).Track.parameters.celldiameter;
                SearchRadius{i}=obj.Tracks(i).Track.parameters.searchradius;
                CorrelationThreshold{i}=obj.Tracks(i).Track.parameters.confidencethreshold;
                for j=1:n
%                     disp(num2str(j));
                    if ~isempty(obj.Tracks(i).Track.Track{j})
                        t{i}=[t{i} AcquisitionTimes(j)];
                        try
                            CellIm{i}=cat(3,CellIm{i},obj.Tracks(i).Track.Track{j}.CellIm);
%                             CellMask{i}=cat(3,CellMask{i},obj.Tracks(i).Track.Track{j}.Mask);
                        catch
                            disp('here');
                        end
                        FileID(i).Name{j}=[obj.CntrlObj.ImageStack.PathName obj.CntrlObj.ImageStack.FileName{j}];
                        if isempty(AnnotationName{i})
                            AnnotationName{i}=obj.Tracks(i).Track.Track{j}.Annotation.Name;
                            AnnotationType{i}=obj.Tracks(i).Track.Track{j}.Annotation.Type;
                            AnnotationSymbol{i}=obj.Tracks(i).Track.Track{j}.Annotation.Symbol;
                        else
                            AnnotationName{i}=cat(2,AnnotationName{i},{obj.Tracks(i).Track.Track{j}.Annotation.Name});
                            AnnotationType{i}=cat(2,AnnotationType{i},{obj.Tracks(i).Track.Track{j}.Annotation.Type});
                            AnnotationSymbol{i}=cat(2,AnnotationSymbol{i},{obj.Tracks(i).Track.Track{j}.Annotation.Symbol});
                        end
                        Position{i}=cat(1,Position{i},obj.Tracks(i).Track.Track{j}.Position);
                        ImageNumber{i}=[ImageNumber{i} obj.Tracks(i).Track.Track{j}.ImageNumber];
                        if isempty(obj.Tracks(i).Track.Track{j}.Result)
                            rho{i}=[rho{i} NaN];
                            pval{i}=[pval{i} NaN];
                            ElapsedTime{i}=[ElapsedTime{i} NaN];
                            Time{i}=[Time{i} NaN];
                            FindCellState{i,j}=[];
                        elseif ~isfield(obj.Tracks(i).Track.Track{j}.Result,'rho')
                            rho{i}=[rho{i} NaN];
                            pval{i}=[pval{i} NaN];
                            ElapsedTime{i}=[ElapsedTime{i} NaN];
                            Time{i}=[Time{i} NaN];
                            FindCellState{i,j}=[];
                        else
                            rho{i}=[rho{i} obj.Tracks(i).Track.Track{j}.Result.rho];
                            pval{i}=[pval{i} obj.Tracks(i).Track.Track{j}.Result.pval];
                            ElapsedTime{i}=[ElapsedTime{i} obj.Tracks(i).Track.Track{j}.Result.ElapsedTime];
                            %ElapsedTime{i}=obj.Tracks(i).Track.Track{j}.Result.ElapsedTimes;
                            Time{i}=[Time{i} obj.Tracks(i).Track.Track{j}.Result.Time];
                            FindCellState{i,j}=obj.Tracks(i).Track.Track{j}.Result.FindCellState;
                        end
                    end
                end
                
            end
%             obj.tbl=table(TrackID,FileID,ParentID,t,ImageNumber, Position, CellIm,CellMask,AnnotationName,...
%                 AnnotationType, AnnotationSymbol, rho,pval,ElapsedTime,Time,FindCellState,CellRadius,SearchRadius,...
%                 CorrelationThreshold,'VariableNames',{'Track_ID','File_ID',...
%                 'Parent_ID','time','Image_Number', 'Position','Cell_Image',...
%                 'CellMask','Annotation_Name','Annotation_type', 'Annotation_Symbol',...
%                 'rho','pval','Processor_Time','Tracking_Time',...
%                 'Tracker_State','CellRadius','SearchRadius',...
%                 'CorrelationThreshold'});
            obj.tbl=table(TrackID,FileID,ParentID,t,ImageNumber, Position, CellIm,AnnotationName,...
                AnnotationType, AnnotationSymbol, rho,pval,ElapsedTime,Time,FindCellState,CellRadius,SearchRadius,...
                CorrelationThreshold,'VariableNames',{'Track_ID','File_ID',...
                'Parent_ID','time','Image_Number', 'Position','Cell_Image',...
                'Annotation_Name','Annotation_type', 'Annotation_Symbol',...
                'rho','pval','Processor_Time','Tracking_Time',...
                'Tracker_State','CellRadius','SearchRadius',...
                'CorrelationThreshold'});
            close(h);
        end
        
            
        
        
        function gather(obj)
            i=obj.NextTrack;
            while (~obj.Interrupt) && (i<=obj.NumberOfTracks) && (~obj.Pause)
                strtrect=obj.SegmentedImage.StartRectangles(i).position;
                range=[obj.FirstImage, obj.LastImage];
                obj.Tracks{i}=tracker(obj.Stack,range,strtrect,obj.himage);
                obj.Tracks{i}.listento(obj.CntrlObj);
                if obj.FirstImage>obj.LastImage
                    obj.Tracks{i}.backward;
                else
                    obj.Tracks{i}.forward;
                end
                mkdir('tracks');
                obj.Tracks{i}.SaveTrack([cd '\tracks\track' num2str(i,'%.4i') '.mat']);
                i=i+1;
                
            end
            if obj.Pause
                obj.NextTrack=i;
            elseif obj.Interrupt
                obj.NextTrack=1;
            end
            
        end
        
        function tracks=SubTable(obj)
            tracks=[];
            tracks.Track_ID=1:length(obj.Tracks);
            tracks.Ancestor_ID=zeros(length(tracks.Track_ID),1);
            tracks.Progeny_ID=zeros(length(tracks.Track_ID),1);
            tracks.Generation_ID=zeros(length(tracks.Track_ID),1);
            tracks.Daughter_IDs=cell(length(tracks.Track_ID),1);
            tracks.Track_ID=(1:length(tracks.Track_ID))';
            tracks.Fate=cell(length(tracks.Track_ID),1);
            
            for i=1:length(tracks.Track_ID)
                if ~isempty(obj.Tracks(i).ParentID)
                    tracks.Parent_ID(i)=obj.Tracks(i).ParentID;
                else
                    tracks.Parent_ID(i)=NaN;
                end
                lastframe=obj.Tracks(i).Track.trackrange(2);
                tracks.Fate{i}=obj.Tracks(i).Track.Track{lastframe}.Annotation.Symbol;
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
            
            return
        end
        
        function UpdatePedigreeId(obj) %update pedigree id annotations
            for i=1:length(obj.Tracks)
                m=obj.Tracks(i).Track.trackrange(1);
                n=obj.Tracks(i).Track.trackrange(2);     
                pedigree_id=obj.TableData.Ancestor_ID(i);
                progeny_id=obj.TableData.Progeny_ID(i);
                for j=(m+1):(n-1)
                    obj.Tracks(i).Track.Track{j}.Annotation.Type.PedigreeID=['Pedigree ' num2str(pedigree_id) ' Track ' num2str(progeny_id)];
                    obj.Tracks(i).Track.Track{j}.Annotation.Symbol.PedigreeID=['P' num2str(pedigree_id) 'Tr' num2str(progeny_id)];
                end
            end
        end
        
    end
end




