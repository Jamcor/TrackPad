classdef avatar< handle
    % implements the avatar class for automated cell tracking using a truth
    % set (track file)
    properties
        TruthTable
        GUIHandle
        NucleusRadius=NaN
        SearchRadius
        CorrelationThreshold
        Memory=NaN
        Track=[]
        Tracks=[];
        tol=2; % tolerance in pixels
        ImageStack
    end
    
    events
        PauseEvent
        StopEvent
        ShowEllipseEvent
        HideEllipseEvent
        ShowSymbolEvent
        HideSymbolEvent
    end
    
    methods
        function obj=avatar(GUIHandle,TruthTable)
            obj.TruthTable=TruthTable;
            obj.GUIHandle=GUIHandle;
            obj.ImageStack=obj.GUIHandle.ImageStack;
        end
        function set.Track(obj,value)
            obj.Track=value;
            if ~isempty(obj.Track)
                addlistener(value,'LostCellEvent',@obj.listenLostCellEvent);
                addlistener(value,'EndOfTrackEvent',@obj.listenEndOfTrackEvent);
                addlistener(value,'TrackEvent',@obj.listenTrackEvent);
            end
        end
        function SimulateTracking(obj)
%              for i=191:height(obj.TruthTable)
            for i=1:5
                if isnan(obj.NucleusRadius) % use truthset
                    obj.GUIHandle.CurrentTrackingParameters.NucleusRadius=...
                        round(mean(obj.TruthTable.Position{i}(1,3:4))); % use truthset radius
                else %don't use truthset
                    obj.GUIHandle.CurrentTrackingParameters.NucleusRadius=obj.NucleusRadius;
                end
                if isnan(obj.SearchRadius)
                    obj.GUIHandle.CurrentTrackingParameters.SearchRadius=...
                        obj.TruthTable.SearchRadius{i}; % use truthset search radius
                else
                    obj.GUIHandle.CurrentTrackingParameters.SearchRadius=obj.SearchRadius;
                end
                if isnan(obj.CorrelationThreshold)
                    obj.GUIHandle.CurrentTrackingParameters.CorrelationThreshold=...
                        obj.TruthTable.CorrelationThreshold{i}; % use truthset correlation threshold
                else
                    obj.GUIHandle.CurrentTrackingParameters.CorrelationThreshold=obj.CorrelationThreshold;
                end
                if ~isnan(obj.Memory)
                    memory=obj.Memory;
                end
                % set frame
                obj.GUIHandle.ImageStack.CurrentNdx=obj.TruthTable.Image_Number{i}(1);
                % set ellipse position
                Position=obj.TruthTable.Position{i}(1,:);
                Centroid=[Position(1)+Position(3)/2,Position(2)+Position(4)/2];
                NR=obj.GUIHandle.CurrentTrackingParameters.NucleusRadius;
                Position=[Centroid(1)-NR/2,Centroid(2)-NR/2,NR,NR];
                display(['Tracking track ', num2str(i)]);
%                                 obj.Tracks.CurrentTrackID=i;

                obj.StartTrack(Position,obj.GUIHandle,memory);
                obj.Tracks.CurrentTrackID=i;
            end
        end
        function StartTrack(obj,EventData,hTrackPad,memory)
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='off';
            Position=EventData;
            hEllipse=imellipse(hTrackPad.ImageHandle.Parent,Position);
            setColor(hEllipse,'g');
            setResizable(hEllipse,false);
            setColor(hEllipse,'b');
            set(hEllipse,'PickableParts','none'); % doesn't allow the user to interact with the ellipse
            range=[hTrackPad.ImageStack.CurrentNdx,hTrackPad.ImageStack.NumberOfImages];
            %create an instance of the tracker object
            obj.Track=tracker(range,hEllipse,hTrackPad);
            obj.Track.parameters.memory=memory;
%             obj.Track.Tracks.parameters
            % set up a listener in tracker for events that occur in avatar
            obj.Track.CntrlObj=obj;
            %create a TrackCollection object if it doesn't already exist
            if isempty(obj.Tracks)
                obj.Tracks=TrackCollection(obj.Track);
                %setup a listerner in TrackCollection for events that
                %occur in avatar
                obj.Tracks.CntrlObj=obj;
            else
                obj.Tracks.CurrentTrack=obj.Track;
            end
%             % add annotation for first cell
            TrackID=obj.Tracks.CurrentTrackID+1;
%             TrackID=obj.Tracks.CurrentTrackID;
            FrameID=obj.GUIHandle.ImageStack.CurrentNdx;
            obj.Track.Track{FrameID}.Annotation=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.Annotation;
            obj.Track.Track{FrameID}.AnnotationHandle=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.AnnotationHandle;
            obj.Track.forward();
        end
        function ContinueTrack(obj,src,evnt)
            % make sure at last cell of track before continue tracking
            % because may have edited track before this action
            n=find(cellfun(@(x) ~isempty(x),obj.Track.Track),1,'last');
            obj.Track.Stack.CurrentNdx=n;
            obj.Track.Track{n}.Result.FindCellState=...
                obj.Track.FindCellState; % update with current find cell state
            obj.Track.FindCellState='go';
            obj.Track.Interrupt=false;
            obj.GUIHandle.ImageContextMenu.ContinueTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.EditTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.StopTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.DeleteTrack.Visible='off';
        end
        function StopTrack(obj,src,evnt)
            obj.Track.Interrupt=1;
            obj.GUIHandle.ImageContextMenu.EditTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.StopTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.ContinueTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.DeleteTrack.Visible='off';
            obj.GUIHandle.ImageContextMenu.SelectTrack.Visible='on';
            % remove ellipse objects from obj.Track.Track
            
            for i=1:length(obj.Track.Track)
                if ~isempty(obj.Track.Track{i})
                    delete(obj.Track.Track{i}.EllipseHandle);
                    obj.Track.Track{i}.EllipseHandle=[];
                end
            end
            
            %append track to TrackCollection object
            TrackID=obj.Tracks.CurrentTrackID+1;
            %annotate last frame of track using truth set
            FrameID=obj.GUIHandle.ImageStack.CurrentNdx;
            obj.Track.Track{FrameID}.Annotation=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.Annotation;
            obj.Track.Track{FrameID}.AnnotationHandle=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.AnnotationHandle;
            obj.Tracks.Tracks(TrackID).Track=obj.Track;
            obj.Tracks.Tracks(TrackID).ParentID=obj.GUIHandle.Tracks.Tracks(TrackID).ParentID;
            obj.Tracks.Tracks(TrackID).Parent=obj.GUIHandle.Tracks.Tracks(TrackID).Parent;
        end
        function listenLostCellEvent(obj,src,evnt)
            % obj - instance of this class
            % src - object generating event
            %  evnt - the event data
            if ~isempty(obj.Track.Track{obj.GUIHandle.ImageStack.CurrentNdx})% only show menu if there is an ellipse
                obj.GUIHandle.ImageContextMenu.EditTrack.Visible='on';
                obj.GUIHandle.ImageContextMenu.ContinueTrack.Visible='on';
                obj.GUIHandle.ImageContextMenu.StopTrack.Visible='on';
                obj.GUIHandle.ImageContextMenu.DeleteTrack.Visible='off';
            end
            disp('Lost cell event');
            TrackID=obj.Tracks.CurrentTrackID+1;
            FrameID=obj.GUIHandle.ImageStack.CurrentNdx;
            ndx=obj.TruthTable.Image_Number{TrackID}==FrameID;
            CorrectPosition=obj.TruthTable.Position{TrackID}(ndx,:);
            CurrentPosition=getPosition(src.CurrentEllipse);
            setPosition(src.CurrentEllipse,CorrectPosition); %add annotation from GUIHandle.Tracks
            src.Track{FrameID}.Annotation=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.Annotation;
            src.Track{FrameID}.AnnotationHandle=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.AnnotationHandle;
            obj.Track.Track{FrameID}.EllipseHandle=src.CurrentEllipse; % need to correct position in track!
            src.Track{FrameID}.Position=CorrectPosition;
            % need to update mask because next interation of find cell uses
            % this updated mask.
            ChangeInPosition=CorrectPosition-CurrentPosition;
            ChangeInRows=round(ChangeInPosition(2));
            ChangeInCols=round(ChangeInPosition(1));
            [r,c]=find(src.Track{FrameID}.Mask);
            src.Track{FrameID}.Mask=false(size(src.Track{FrameID}.Mask));
            src.Track{FrameID}.Mask(r+ChangeInRows,c+ChangeInCols)=true;
            src.parameters.lastmask=src.Track{FrameID}.Mask;
            src.Track{FrameID}.Result.mask=src.Track{FrameID}.Mask;
            src.Track{FrameID}.Mask=src.Track{FrameID}.Mask;
            % need to update CellIm so that RefImage is modified with
            % corrected cell image
            b=false(size(src.Track{FrameID}.CellIm));
            b(isnan(src.Track{FrameID}.CellIm))=true;
            im=squeeze(obj.GUIHandle.ImageStack.Stack(:,:,1,FrameID));
            newCellIm=single(zeros(size(b)));
            newCellIm(:)=im(src.Track{FrameID}.Mask);
            newCellIm(b)=NaN;
            src.Track{FrameID}.CellIm=newCellIm;
            if obj.TruthTable.Image_Number{TrackID}(end)==FrameID
                obj.StopTrack(src,evnt);
            else % continue tracking
                obj.ContinueTrack(src,evnt);
            end
        end
        function listenEndOfTrackEvent(obj,src,evnt)
            % obj - instance of this class
            % src - object generating event
            %  evnt - the event data
            obj.GUIHandle.ImageContextMenu.StopTrack.Visible='on';
            obj.GUIHandle.ImageContextMenu.EditTrack.Visible='on';
            obj.GUIHandle.ImageContextMenu.DeleteTrack.Visible='on';
            disp('End of Track Event');
            obj.StopTrack(src,evnt);
        end
        function listenTrackEvent(obj,src,evnt)
            % check position is correct using TruthSet
            FrameID=obj.GUIHandle.ImageStack.CurrentNdx;
            TrackID=obj.Tracks.CurrentTrackID+1;
            CurrentPosition=getPosition(src.CurrentEllipse);
            ndx=obj.TruthTable.Image_Number{TrackID}==FrameID;
            
            CorrectPosition=obj.TruthTable.Position{TrackID}(ndx,:);
            %add annotation from GUIHandle.Tracks
            obj.Track.Track{FrameID}.Annotation=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.Annotation;
            obj.Track.Track{FrameID}.AnnotationHandle=...
                obj.GUIHandle.Tracks.Tracks(TrackID).Track.Track{FrameID}.AnnotationHandle;
            %correct position if there is a tracking error and generate
            %a PauseEvent
            IsTrackingError=sqrt((CorrectPosition(1)-CurrentPosition(1))^2+...
                (CorrectPosition(2)-CurrentPosition(2))^2)>obj.tol;
            if IsTrackingError
                obj.Track.FindCellState='pause';
                disp('Pausing');
                setPosition(src.CurrentEllipse,CorrectPosition);
                obj.Track.Track{FrameID}.EllipseHandle=src.CurrentEllipse;
                src.Track{FrameID}.Position=CorrectPosition;
                % need to update mask
                ChangeInPosition=CorrectPosition-CurrentPosition;
                ChangeInRows=round(ChangeInPosition(2));
                ChangeInCols=round(ChangeInPosition(1));
                [r,c]=find(src.Track{FrameID}.Mask);
                src.Track{FrameID}.Mask=false(size(src.Track{FrameID}.Mask));
                src.Track{FrameID}.Mask(r+ChangeInRows,c+ChangeInCols)=true;
                src.parameters.lastmask=src.Track{FrameID}.Mask;
                src.Track{FrameID}.Result.mask=src.Track{FrameID}.Mask;
                src.Track{FrameID}.Mask=src.Track{FrameID}.Mask;
                % need to update CellIm so that RefImage is modified with
                % corrected cell image
                b=false(size(src.Track{FrameID}.CellIm));
                b(isnan(src.Track{FrameID}.CellIm))=true;
                im=squeeze(obj.GUIHandle.ImageStack.Stack(:,:,1,FrameID));
                newCellIm=single(zeros(size(b)));
                newCellIm(:)=im(src.Track{FrameID}.Mask);
                newCellIm(b)=NaN;
                src.Track{FrameID}.CellIm=newCellIm;
                if length(ndx)==find(ndx) % last image of track
                    StopTrack(obj,src,evnt);
                else
                    obj.ContinueTrack(src,evnt);
                end
            elseif length(ndx)==find(ndx) % last image of track
                StopTrack(obj,src,evnt);
            end
            
            
        end
        function SaveTracks(obj,src,evnt)
            CreateTable(obj.Tracks);
            tbl=obj.Tracks.tbl;
            TrackFile=[obj.GUIHandle.TrackFile(1:end-4) '_r_' num2str(obj.CorrelationThreshold) ...
                '_sr_' num2str(obj.SearchRadius) '_cr_' num2str(obj.NucleusRadius) '_mem_' num2str(length(obj.Memory)) '.mat'];
            CellProperties=obj.GUIHandle.CellProperties;
            save(TrackFile,'tbl','CellProperties','-v7.3');
        end
    end
end