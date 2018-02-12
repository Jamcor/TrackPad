classdef TrackPad < handle
    % User interface for tracking cells

    
    properties
        FigureHandle 
        AnnotationFigureHandle=[]
        MenuHandle
        FrameSliderHandle
        FrameTextBox
        FrameTimeBox
        ImageContextMenu
        Track=[]
        Tracks=[];
        TrackFile
        ImageHandle
        ImageStack
        isParallel=false;
        pool=[]
        CellProperties;
        CurrentTrackingParameters
        
        
       
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
        
        function obj=TrackPad(ImageStack)
            if nargin<1
                button=questdlg('Does an ImageStack object exist (*.mat file)');
                switch(button)
                    case 'Yes'
                        [FileName,PathName,FilterIndex] = uigetfile('*.mat','Select ImageStack file');
                        s=load([PathName FileName]);
                        StackData=fieldnames(s);
                        if isa(s.(StackData{1}),'ImageStack')
                            obj.ImageStack=s.(StackData{1});
                        else
                            error('Not an ImageStack object');
                        end
                    otherwise
                         evalin('base','StackData=ImageStack;'); % create a StackDate object
                         evalin('base','StackData.getImageStack;');
                         obj.ImageStack=evalin('base','StackData;');        
                end
                        
            else  
                ImageStack.Parent=[]; % watch out for old reference to TrackPad
                obj.ImageStack=ImageStack;
            end
            obj.ImageStack.CurrentNdx=1;    
            obj.FigureHandle=figure('Name',obj.ImageStack.PathName,'MenuBar','none',...
                'ToolBar','figure','KeyPressFcn',{@obj.HotKeyFcn,obj});
            
            FileMenuHandle = uimenu(obj.FigureHandle,'Label','File');          
            uimenu(FileMenuHandle,'Label','Open Tracks',...
                'Callback',{@obj.OpenTracks,obj});
            uimenu(FileMenuHandle,'Label','Save Tracks',...
                        'Callback',{@obj.SaveTracks,obj});
            AnnotateMenuHandle = uimenu(obj.FigureHandle,'Label','Annotate');
            uimenu(AnnotateMenuHandle,'Label','Edit table',...
                'Callback',{@obj.OpenAnnotationTable,obj});
            ParametersMenuHandle=uimenu(obj.FigureHandle,'Label','Parameters');
            uimenu(ParametersMenuHandle,'Label','Search radius',...
                'Callback',{@obj.setThreshold,obj});
            uimenu(ParametersMenuHandle,'Label','Nucleus radius',...
                'Callback',{@obj.setThreshold,obj});
            uimenu(ParametersMenuHandle,'Label','Correlation threshold',...
                'Callback',{@obj.setThreshold,obj});
            CloseMenuHandle=uimenu(obj.FigureHandle,'Label','Close');
            
            
%             obj.ImageHandle=imshow(ImageStack.Stack(:,:,1,1),[]);
            obj.ImageHandle=imshow(obj.ImageStack.CData(:,:,1),obj.ImageStack.CMap{1});
            % create slider to control frame
            pos=obj.FigureHandle.Position;
            N=obj.ImageStack.NumberOfImages;
            obj.FrameSliderHandle=uicontrol(obj.FigureHandle,'Style','slider',...
            'Position',[0,0,pos(3),round(pos(4)/40)],'Value',1,...
            'Tag','FrameSlider','Min',1,'Max',N,...
            'SliderStep',[1/(N-1) 10/(N-1)]);
            obj.FrameTextBox=uicontrol(obj.FigureHandle,'Style','text',...
                'Position',[0,round(pos(4)/40),120,20],...
                'String',['Frame ' num2str(1)]);
            obj.FrameTimeBox=uicontrol(obj.FigureHandle,'Style','text',...
                'Position',[120,round(pos(4)/40),120,20],...
                'String',['Time 0:0:0 (H:M:S)']);
            obj.FrameSliderHandle.Callback={@obj.FrameChangeCallback,obj};
            obj.FigureHandle.SizeChangedFcn=@obj.FigureResizeCallback;
            % create image context menu
            c=uicontextmenu;
            
            obj.ImageHandle.UIContextMenu=c;
            obj.ImageContextMenu.StartTrack=uimenu(c,'Label','Start Track','Tag','StartTrack',...
                'Visible','on','Callback',{@obj.StartTrack,obj});
            obj.ImageContextMenu.EditTrack=uimenu(c,'Label','Edit Track','Tag','EditTrack',...
                'Visible','off','Callback',{@obj.EditTrack,obj});
            obj.ImageContextMenu.ContinueTrack=uimenu(c,'Label','Continue Track (c)','Tag','ContinueTrack',...
                'Visible','off','Callback',{@obj.ContinueTrack,obj});
            obj.ImageContextMenu.StopTrack=uimenu(c,'Label','Stop Track (s)','Tag','StopTrack',...
                'Visible','off','Callback',{@obj.StopTrack,obj});
            obj.ImageContextMenu.DeleteTrack=uimenu(c,'Label','Delete Track (d)','Tag','DeleteTrack',...
                'Visible','off','Callback',{@obj.DeleteTrack,obj});
            obj.ImageContextMenu.SelectTrack=uimenu(c,'Label','Select Track (s)','Tag','SelectTrack',...
                'Visible','off','Callback',{@obj.SelectTrack,obj});
            obj.ImageContextMenu.AnnotateTrack=uimenu(c,'Label','Annotate Track (a)','Tag','AnotateTrack',...
                'Visible','off','Callback',{@obj.AnnotateTrack,obj});
           
            
            %Always pause tracking when click on screen
            obj.ImageHandle.ButtonDownFcn={@obj.PauseTracking,obj};
            % updates GUI when frame changed programatically
            addlistener(obj.ImageStack,'CurrentNdx','PostSet',@obj.OnChangeCurrentNdx);
            obj.ImageStack.Parent=obj; % gives access to TrackPad via ImageStack
            %start parallel processing pool
%            button = questdlg('Start Parallel Processing?');
            button='No';
            switch(button)
                case 'Yes'
                    obj.isParallel=true;
                    h=waitbar(0,'Starting parallel pool');
                    obj.pool=gcp;
                    obj.pool.IdleTimeout=inf;
                    close(h);
                otherwise
                    obj.isParallel=false;
                    delete(gcp('nocreate'));
                    obj.pool=[];
            end
            % initialise CellProperties
            obj.CellProperties(1).Name='Origin';
            obj.CellProperties(1).Type={'ancestor','daughter'};
            obj.CellProperties(1).Symbol={'AN','DA'};
            obj.CellProperties(1).String={'ancestor (AN)','daughter (DA)'};
            obj.CellProperties(2).Name='Fate';
            obj.CellProperties(2).Type={'Not complete','Division','Death','Lost'};
            obj.CellProperties(2).Symbol={'NC','DI','DE','LO'};
            obj.CellProperties(2).String={'Not complete (NC)','Division (DI)','Death (DE)','Lost (LO)'};
            % these are optional cell properties (subsets)
            obj.CellProperties(3).Name='Subsets';
            obj.CellProperties(3).Type={'No annotation','red','green'};
            obj.CellProperties(3).Symbol={'NA','S1','S2'};
            obj.CellProperties(3).String={'No annotation (NA)','red (S1)','green (S2)'};
            obj.CurrentTrackingParameters.NucleusRadius=35;
            obj.CurrentTrackingParameters.SearchRadius=10;
            obj.CurrentTrackingParameters.CorrelationThreshold=0.6;
            obj.FigureHandle.CloseRequestFcn={@obj.CloseTrackPad,obj};
            CloseMenuHandle.Callback={@obj.CloseTrackPad,obj};
        end
        
        function delete(obj)
            if ~isempty(obj.Tracks)
                button=questdlg('Save tracks?');
                if strcmp(button,'Yes');
                    obj.SaveTracks(obj,[],obj);
                end  
            end
            delete(obj.Tracks);
            d=findobj('Tag','imrect');
            delete(d); % delete all ellipses
            d=findobj('Type','text');
            delete(d); % delete all text
            delete(obj.FigureHandle);
        end
        
        

        function set.Track(obj,value)        
            obj.Track=value;
            if ~isempty(obj.Track)
                addlistener(value,'LostCellEvent',@obj.listenLostCellEvent);
                addlistener(value,'EndOfTrackEvent',@obj.listenEndOfTrackEvent);
            end
        end
        function set.Tracks(obj,value)
            obj.Tracks=value;
            addlistener(value,'AppendedTrackEvent',@obj.listenAppendedTrackEvent);
        end
        function listenLostCellEvent(obj,src,evnt)
            % obj - instance of this class
             % src - object generating event
            %  evnt - the event data
            if ~isempty(obj.Track.Track{obj.ImageStack.CurrentNdx})% only show menu if there is an ellipse
                obj.ImageContextMenu.EditTrack.Visible='on';
                obj.ImageContextMenu.ContinueTrack.Visible='on';
                obj.ImageContextMenu.StopTrack.Visible='on';
                obj.ImageContextMenu.DeleteTrack.Visible='off';
            end
            disp('Lost cell event');
        end        
        function listenEndOfTrackEvent(obj,src,evnt)
            % obj - instance of this class
             % src - object generating event
            %  evnt - the event data
            obj.ImageContextMenu.StopTrack.Visible='on';
            obj.ImageContextMenu.EditTrack.Visible='on';
            obj.ImageContextMenu.DeleteTrack.Visible='on';
            disp('End of Track Event');
        end
        function listenAppendedTrackEvent(obj,src,~)
            obj.ImageContextMenu.StartTrack.Visible='on';
        end
    end    
    
    methods (Static=true)
        function FigureResizeCallback(hObject,EventData)
            hslider=findobj(hObject,'tag','FrameSlider');
            pos=hObject.Position;
            hslider.Position=[0,0,pos(3),round(pos(4)/40)];
        end  
        
        function CloseTrackPad(hObject,EventData,hTrackPad)
            delete(hTrackPad);           
        end
        
        function OnChangeCurrentNdx(hObject,EventData)
            if ~isempty(EventData.AffectedObject.Parent) % update slide etc.
                n=EventData.AffectedObject.CurrentNdx;
                hTrackPad=EventData.AffectedObject.Parent;
                if ~isempty(hTrackPad.AnnotationFigureHandle) % update annotation tool
                     m=hTrackPad.Tracks.CurrentTrackID;
                     trackrange(1)=find(cellfun(@(x) ~isempty(x),hTrackPad.Tracks.Tracks(m).Track.Track),...
                         1,'first');
                     trackrange(2)=find(cellfun(@(x) ~isempty(x),hTrackPad.Tracks.Tracks(m).Track.Track),...
                         1,'last');
                     if (n>trackrange(1))&&(n<trackrange(2))
                         if ~isempty(hTrackPad.Tracks.Tracks(m).Track.Track{n}.Annotation)
                            s=[hTrackPad.Tracks.Tracks(m).Track.Track{n}.Annotation.Type,' (',...
                            hTrackPad.Tracks.Tracks(m).Track.Track{n}.Annotation.Symbol,')'];
                            handles=guidata(hTrackPad.AnnotationFigureHandle);
                            for j=1:length(handles.Subsets.RB)
                                if strcmp(handles.Subsets.RB(j).String,s)
                                    handles.Subsets.RB(j).Value=1;
                                end
                            end
                            guidata(hTrackPad.AnnotationFigureHandle,handles); 
                         end
                     end
                end
%                 notify(hTrackPad,'HideEllipseEvent');
%                 notify(hTrackPad,'HideSymbolEvent');
                % update slider
                hTrackPad.FrameSliderHandle.Value=n;
                % update image
%                 hTrackPad.ImageHandle.CData=squeeze(hTrackPad.ImageStack.Stack(:,:,1,n));
                hTrackPad.ImageHandle.CData=hTrackPad.ImageStack.CData(:,:,n);
                ax=get(hTrackPad.ImageHandle,'parent');
                colormap(ax,hTrackPad.ImageStack.CMap{n});
                % update displayed Frame info
                hTrackPad.FrameTextBox.String=['Frame ' num2str(n)];
                t=hTrackPad.ImageStack.AcquisitionTimes(n)...
                    -hTrackPad.ImageStack.AcquisitionTimes(1);
                h=floor(t*24);
                m=floor((t-h/24)*24*60);
                s=floor((t-h/24-m/24/60)*24*60*60);
                hTrackPad.FrameTimeBox.String=['time ', num2str(h),':',...
                    num2str(m),':',num2str(s),' (H:M:S)'];
                % update Ellipse if it exists
%                 notify(hTrackPad,'ShowEllipseEvent');% Display all other tracked cells ellipses
%                 notify(hTrackPad,'ShowSymbolEvent');% Dislpay all other tracked cell symbols
                if ~isempty(hTrackPad.Tracks)
                    hTrackPad.DisplayAnnotation(hObject,EventData,hTrackPad);
                end
                if ~isempty(hTrackPad.Track)                    
                    if ~isempty(hTrackPad.Track.Track{n})
                       % hTrackPad.ImageContextMenu.EditTrack.Visible='on';
                       try
                        set(hTrackPad.Track.CurrentEllipse,'PickableParts','none'); % doesn't allow the user to interact with the ellipse
                       catch
                           disp('here');
                       end
                       
                        set(hTrackPad.Track.CurrentEllipse,'Visible','off');
                        hTrackPad.Track.CurrentEllipse=hTrackPad.Track.Track{n}.EllipseHandle;
                        if (hTrackPad.Tracks.CurrentTrackID==0) % in track mode
                            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
                            hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
                            hTrackPad.ImageContextMenu.StopTrack.Visible='on';
                        else                             
                            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
                        end
                        hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
                        set(hTrackPad.Track.CurrentEllipse,'Visible','on');
                    else % don't show context menu if the is no ellipse
                        hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                        hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                        hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                        hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                        hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
                    end
                else
                    hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                    hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                    hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                    hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                    hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
                    hTrackPad.ImageContextMenu.StartTrack.Visible='on';
                    hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
                end
                hTrackPad.ImageStack.LastNdx=n;
            end
            
        end 
        
        function DisplayAnnotation(hObject,EventData,hTrackPad)
            n=hTrackPad.ImageStack.CurrentNdx;
            last=hTrackPad.ImageStack.LastNdx;                      
            if (n~=last)
                % update CurrentTrack first            
                if ~isempty(hTrackPad.Track)
                   if ~isempty(hTrackPad.Track.Track{last})
                       set(hTrackPad.Track.Track{last}.EllipseHandle,'Visible',...
                           'off');
                   end
                   if ~isempty(hTrackPad.Track.Track{n})
                       set(hTrackPad.Track.Track{n}.EllipseHandle,'Visible',...
                           'on');
                   end
                end
                % update Stored Tracks
                m=length(hTrackPad.Tracks.Tracks);
                for i=1:m
                    Track=hTrackPad.Tracks.Tracks(i).Track.Track;
                    %switch off last annotations
                    if ~isempty(Track{last})
                        if ~isempty(Track{last}.EllipseHandle)
                            set(Track{last}.EllipseHandle,'Visible','off');
                        end
                        if ~isempty(Track{last}.AnnotationHandle)
                            set(Track{last}.AnnotationHandle,'Visible','off');
                        end
                    end
                    if ~isempty(Track{n})
%                         if isempty(Track{n}.EllipseHandle)
%                              hellipse=imellipse(hTrackPad.ImageHandle.Parent,...
%                                  Track{n}.Position);
%                              set(hellipse,'PickableParts','none');
%                              setResizable(hellipse,0);
%                              Track{n}.EllipseHandle=hellipse;
%                         else
%                             set(Track{n}.EllipseHandle,'Visible','on');
%                         end
                        if isempty(Track{n}.AnnotationHandle)
                             x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                             y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                             hannotation=text(x,y,...
                                Track{n}.Annotation.Symbol,'Color','w',...
                                'HorizontalAlignment','center','PickableParts','none');                         
                             Track{n}.AnnotationHandle=hannotation;
                        else
                            set(Track{n}.AnnotationHandle,'Visible','on');
                        end
                    end                
                end
            end
        end
        
        function FrameChangeCallback(hObject,EventData,hTrackPad)
            n=round(hObject.Value);
            hTrackPad.ImageStack.CurrentNdx=n;            
        end        
        function StartTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='off';
            ImageAxes=get(hTrackPad.ImageHandle,'parent');
            CursorPosition=get(ImageAxes,'CurrentPoint');
            Position=[CursorPosition(1,1:2),...
                hTrackPad.CurrentTrackingParameters.NucleusRadius*ones(1,2)];
            hEllipse=imellipse(hTrackPad.ImageHandle.Parent,Position);            
            setColor(hEllipse,'g');
            wait(hEllipse);
            setPosition(hEllipse,round(getPosition(hEllipse)));
            setResizable(hEllipse,false);
            setColor(hEllipse,'b');
            set(hEllipse,'PickableParts','none'); % doesn't allow the user to interact with the ellipse
            range=[hTrackPad.ImageStack.CurrentNdx,hTrackPad.ImageStack.NumberOfImages];
            %create an instance of the tracker object
            hTrackPad.Track=tracker(range,hEllipse,hTrackPad);
            % set up a listener in tracker for events that occur in TrackPad
            hTrackPad.Track.CntrlObj=hTrackPad;
            %create a TrackCollection object if it doesn't already exist
            if isempty(hTrackPad.Tracks)
                hTrackPad.Tracks=TrackCollection(hTrackPad.Track);
                %setup a listerner in TrackCollection for events that
                %occur in TrackPad
                hTrackPad.Tracks.CntrlObj=hTrackPad;
            else
                hTrackPad.Tracks.CurrentTrack=hTrackPad.Track;
            end
            hTrackPad.Track.forward();
        end       
        function StopTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            % delete ellipse objects from current track
            for i=1:length(hTrackPad.Track.Track)
                if ~isempty(hTrackPad.Track.Track{i})
                    delete(hTrackPad.Track.Track{i}.EllipseHandle);
                    hTrackPad.Track.Track{i}.EllipseHandle=[];
                end
            end

            %append track to TrackCollection object
            if ~hTrackPad.Tracks.CurrentTrackID
                hTrackPad.Tracks.Append;
                hTrackPad.Track=[];% no longer can be edited
            else % selected existing track for editing
                hTrackPad.Tracks.Tracks(hTrackPad.Tracks.CurrentTrackID).Track=hTrackPad.Track;
                hTrackPad.Track=[];% no longer can be edited 
                i=hTrackPad.Tracks.CurrentTrackID;
                for j=1:length(hTrackPad.Tracks.Tracks(i).Track.Track)
                    if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{j})
                        setColor(hTrackPad.Tracks.Tracks(i).Track.Track{j}.EllipseHandle,'b')
                    end
                end
                hTrackPad.Tracks.CurrentTrackID=0;% reset to append mode
                hTrackPad.ImageContextMenu.StartTrack.Visible='on';
            end
            
            
        end   
        
        function SelectTrack(hObject,EventData,hTrackPad)
            % make all tracks selectable in current frame
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='off';
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            n=length(hTrackPad.Tracks.Tracks);
            m=hTrackPad.ImageStack.CurrentNdx; % make all tracks in current frame selectable
            for i=1:n
                if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})
                    hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                    set(hAnnotation,'PickableParts','all');
                    set(hAnnotation,'ButtonDownFcn',{@hTrackPad.getAnnotationInfo,...
                        i,hTrackPad.Tracks});
                end
            end
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
        end
        
        function AnnotateTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off'; 
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hfig=figure('Name','Annotate track','ToolBar','none',...
                'MenuBar','none','NumberTitle','off','WindowStyle','modal');
            handles=guihandles(hfig);
            set(hfig,'CloseRequestFcn',{@hTrackPad.CloseAnnotationFigure,hTrackPad});
            hTrackPad.AnnotationFigureHandle=hfig;
            CellProperties=hTrackPad.CellProperties;
            % calculate height of figure
            h=0;
            for i=1:length(CellProperties)
                h=h+40*length(CellProperties(i).Type);
            end
            hfig.Position(3)=200;
            hfig.Position(4)=round(h);
            hfig.Resize='Off';
            
            h=hfig.Position(4);
            % first write button groups
            CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;
            CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
            trackrange(1)=find(cellfun(@(x) ~isempty(x),...
                hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track),1,'first');
            trackrange(2)=find(cellfun(@(x) ~isempty(x),...
                hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track),1,'last');
            for i=1:length(CellProperties)
                str=[CellProperties(i).Name];
                BGHeight=(length(CellProperties(i).Type)+1)*25;
                h=h-BGHeight-10;
                handles.(str).BG=uibuttongroup(hfig,'Visible','on','Units','pixels');
                handles.(str).BG.Position=[25,...
                    h,...
                    150,BGHeight];
                set(handles.(str).BG,'SelectionChangedFcn',{@hTrackPad.AnnotationHandler,hTrackPad});
                
                handles.(str).BG.Title=CellProperties(i).Name;
                n=length(CellProperties(i).Type);
                % create radio buttons
      
                for j=1:n
                    handles.(str).RB(j)=uicontrol(handles.(str).BG,'Style',...
                        'radiobutton',...
                        'String',CellProperties(i).String{j},...
                        'position',[4,BGHeight-j*20-20,160,15],...
                        'HandleVisibility','off');

                end
                % update state of annotation tool to reflect current track
                % annotation state
                if i==1 % Origin
                    s=[hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{trackrange(1)}.Annotation.Type,...
                        ' (',hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{trackrange(1)}.Annotation.Symbol,...
                        ')'];
                    for j=1:n
                        if strcmp(handles.(str).RB(j).String,s)
                            handles.(str).RB(j).Value=1;
                        end
                    end
                elseif i==2 % Fate
                    s=[hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{trackrange(2)}.Annotation.Type,...
                        ' (',hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{trackrange(2)}.Annotation.Symbol,...
                        ')'];
                    for j=1:n
                        if strcmp(handles.(str).RB(j).String,s)
                            handles.(str).RB(j).Value=1;
                        end
                    end
                else % subset
                    if CurrentNdx<=trackrange(1)
                        CurrentNdx=trackrange(1)+1;
                    elseif CurrentNdx>=trackrange(2)
                        CurrentNdx=trackrange(2)-1;
                    end
                    if (CurrentNdx<trackrange(2)&&CurrentNdx>trackrange(1))
                        if ~isempty(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation)
                            s=[hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation.Type,...
                                ' (',hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation.Symbol,...
                                ')'];
                            for j=1:n
                                if strcmp(handles.(str).RB(j).String,s)
                                    handles.(str).RB(j).Value=1;
                                end
                            end
                        end
                    end
                end
            end
            guidata(hfig,handles);
        end

        function AnnotationHandler(hObject,EventData,hTrackPad)
            CellProperties=hTrackPad.CellProperties;
            ax=get(hTrackPad.ImageHandle,'Parent');
            axes(ax);
            switch(hObject.Title)
                case 'Origin'
                    switch(EventData.NewValue.String)
                        case CellProperties(1).String{1} % ancestor
                            ndx=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1);
                            if ~isempty(hTrackPad.Track.Track{ndx})
                                delete(hTrackPad.Track.Track{ndx}.AnnotationHandle);
                            end
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(1).Type{1};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(1).Symbol{1};
                            Position=hTrackPad.Track.Track{ndx}.Position;
                            x=Position(1)+Position(3)/2;
                            y=Position(2)+Position(4)/2;
                            axes(ax);
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,...
                                hTrackPad.Track.Track{ndx}.Annotation.Symbol,'Color','w',...
                                'HorizontalAlignment','center','PickableParts','none');
                            n=hTrackPad.Tracks.CurrentTrackID;
                            hTrackPad.Tracks.Tracks(n).Parent=[]; % get rid of link to parent.
                        case CellProperties(1).String{2} % daughter, need to select parents
                            isparent=false;
                            ndx=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1);
                            if ndx>1 % may have a parent
                                %prevent closure of anotation form whilst
                                % parent is chosen
                                hTrackPad.AnnotationFigureHandle.Visible='off';
                                for i=1:length(hTrackPad.Tracks.Tracks)
                                    m=find(~(cellfun(@(x) isempty(x), ...
                                            hTrackPad.Tracks.Tracks(i).Track.Track)),1,'last');
                                    if (ndx-1)==m
                                        % could be parent
                                        hTrackPad.ImageStack.CurrentNdx=m;
                                        hTrackPad.FrameSliderHandle.Enable='off';
                                        hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle.Color=[0,1,0];
                                        hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                                        set(hAnnotation,'PickableParts','all');
                                        set(hAnnotation,'ButtonDownFcn',{@hTrackPad.getParent,...
                                            i,hTrackPad.Tracks});
                                        isparent=true;
                                    end
                                end
                                if ~isparent
                                    disp('No parent found');
                                    hTrackPad.AnnotationFigureHandle.Visible='on';
                                end
                            end
                        otherwise
                            error('Origin of cell not recognised');                          
                    end
                case 'Fate'
                    ndx=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1,'last');
                    CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
                    if ~isempty(hTrackPad.Track.Track{ndx}.Annotation)
                        delete(hTrackPad.Track.Track{ndx}.AnnotationHandle);
                    end
                    Position=hTrackPad.Track.Track{ndx}.Position;
                    x=Position(1)+Position(3)/2;
                    y=Position(2)+Position(4)/2;
                    switch(EventData.NewValue.String)
                        case CellProperties(2).String{1} % not complete
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{1};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{1};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{1},...
                                'Color','w','HorizontalAlignment','center','Visible','off','PickableParts','none');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                        case CellProperties(2).String{2}  % Division
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{2};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{2};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{2},...
                                'Color','w','HorizontalAlignment','center','Visible','off','PickableParts','none');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                        case CellProperties(2).String{3}  % Death
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{3};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{3};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{3},...
                                'Color','w','HorizontalAlignment','center','Visible','off','PickableParts','none');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                        case CellProperties(2).String{4}  % Lost
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{4};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{4};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{4},...
                                'Color','w','HorizontalAlignment','center','Visible','off','PickableParts','none'); 
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                         
                    end
                
                otherwise
                    CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
                    m=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1,'first');
                    n=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1,'last');
                    p=hTrackPad.ImageStack.CurrentNdx;
                    if p<=m
                        p=m+1;
                    end
                    if (p<n)
                        for i=p:(n-1)
                            if ~isempty(hTrackPad.Track.Track{i}.Annotation)
                                delete(hTrackPad.Track.Track{i}.AnnotationHandle);
                            end
                            hTrackPad.Track.Track{i}.Annotation.Name=EventData.NewValue.Parent.Title;
                            str=EventData.NewValue.String;
                            ndx=findstr(str,'(');
                            hTrackPad.Track.Track{i}.Annotation.Type=str(1:ndx-2);
                            hTrackPad.Track.Track{i}.Annotation.Symbol=str(ndx+1:end-1);
                            
                            Position=hTrackPad.Track.Track{i}.Position;
                            x=Position(1)+Position(3)/2;
                            y=Position(2)+Position(4)/2;
                            hTrackPad.Track.Track{i}.AnnotationHandle=text(x,y,...
                                hTrackPad.Track.Track{i}.Annotation.Symbol,...
                                'Color','w','HorizontalAlignment','center','Visible','off','PickableParts','none');
                            if CurrentNdx==i
                                hTrackPad.Track.Track{i}.AnnotationHandle.Visible='on';
                            end
                        end
                    end
            end

        end
        function OpenTracks(hObject,EventData,hTrackPad)
            [FileName,PathName,FilterIndex] = uigetfile('*.mat','Get track table');
            s=load([PathName,FileName]);
            hTrackPad.CellProperties=s.CellProperties;
            if isa(hTrackPad.Tracks,'TrackCollection')
                % Track collection already exists .... overwrite
                button=questdlg('Delete current tracks?','Load tracks');
                if strcmp(button,'Yes')                  
                    delete(hTrackPad.Tracks);
                    d=findobj('Tag','imrect');
                    delete(d); % delete all ellipses
                    d=findobj('Type','text');
                    delete(d); % delete all text
                    hTrackPad.Tracks=TrackCollection;
                    hTrackPad.Tracks.tbl=s.tbl;
                    hTrackPad.Tracks.CntrlObj=hTrackPad;
                    CreateTracks(hTrackPad.Tracks);
                end
            else
               hTrackPad.TrackFile=[PathName,FileName];
               hTrackPad.Tracks=TrackCollection;
               hTrackPad.Tracks.tbl=s.tbl;
               hTrackPad.Tracks.CntrlObj=hTrackPad;
               CreateTracks(hTrackPad.Tracks);
            end                
        end
        function SaveTracks(hObject,EventData,hTrackPad)
            CreateTable(hTrackPad.Tracks);
            [FileName,PathName,FilterIndex] = uiputfile('*.mat');
            tbl=hTrackPad.Tracks.tbl;
            CellProperties=hTrackPad.CellProperties;
            save([PathName,FileName],'tbl','CellProperties','-v7.3');
        end
        function HotKeyFcn(hObject,EventData,hTrackPad)
            switch(EventData.Key)
                case 'c'
                    if strcmp(hTrackPad.ImageContextMenu.ContinueTrack.Visible,'on')
                        hTrackPad.ContinueTrack(hObject,EventData,hTrackPad); 
                    end
                case 's'
                    if strcmp(hTrackPad.ImageContextMenu.SelectTrack.Visible,'on')
                        hTrackPad.SelectTrack(hObject,EventData,hTrackPad);
                    end
                    if strcmp(hTrackPad.ImageContextMenu.StopTrack.Visible,'on')
                        hTrackPad.StopTrack(hObject,EventData,hTrackPad);
                    end
                case 'a'
                    if strcmp(hTrackPad.ImageContextMenu.AnnotateTrack.Visible,'on')
                        hTrackPad.AnnotateTrack(hObject,EventData,hTrackPad);
                    end
                case 'd'
                    if strcmp(hTrackPad.ImageContextMenu.DeleteTrack.Visible,'on')
                        hTrackPad.DeleteTrack(hObject,EventData,hTrackPad);
                    end 
            end
        end
        function DeleteTrack(hObject,EventData,hTrackPad)
            %deletes track from currentnxd onward
            %deletes the whole track if CurrentNdx==1
            n=hTrackPad.ImageStack.CurrentNdx;
            m=hTrackPad.ImageStack.NumberOfImages;
            if hTrackPad.Tracks.CurrentTrackID>0
                n=1;
                hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
                if length(hTrackPad.Tracks.Tracks)>1
                    hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
                end
                
               
            end % clears whole track if in track select mode
            NumberOfDeletedCells=0;
            for i=n:m
                if ~isempty(hTrackPad.Track.Track{i})
                    NumberOfDeletedCells=NumberOfDeletedCells+1;
                    delete(hTrackPad.Track.Track{i}.EllipseHandle);
                    delete(hTrackPad.Track.Track{i}.AnnotationHandle);
                    delete(hTrackPad.Track.Track{i});
                    hTrackPad.Track.Track{i}=[];
                end
            end
            hTrackPad.Track.parameters.NumberOfPriorImages=...
                hTrackPad.Track.parameters.NumberOfPriorImages-...
                NumberOfDeletedCells;
            if n==1
                delete(hTrackPad.Track.CurrentEllipse);
                delete(hTrackPad.Track);
                hTrackPad.Track=[];
%                 hTrackPad.ImageStack.CurrentNdx=1;
                hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                hTrackPad.ImageContextMenu.StartTrack.Visible='on';
                hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                if hTrackPad.Tracks.CurrentTrackID>0 % a selected track
                     Remove(hTrackPad.Tracks);
                     hTrackPad.Tracks.CurrentTrack=[];
                     hTrackPad.Tracks.CurrentTrackID=0;
                end
            else
                hTrackPad.Track.CurrentEllipse=hTrackPad.Track.Track{n-1}.EllipseHandle;
                hTrackPad.ImageStack.CurrentNdx=n-1;
                
            end
            
        end       
        function ContinueTrack(hObject,EventData,hTrackPad)
            % make sure at last cell of track before continue tracking
            % because may have edited track before this action
            n=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),1,'last');
            hTrackPad.Track.Stack.CurrentNdx=n; 
            hTrackPad.Track.Track{n}.Result.FindCellState=...
                hTrackPad.Track.FindCellState; % update with current find cell state
            hTrackPad.Track.FindCellState='go';
            hTrackPad.Track.Interrupt=false;
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.Track.forward();
        end        
        function EditTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.FrameSliderHandle.Enable='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            n=hTrackPad.Track.Stack.CurrentNdx;
            setColor(hTrackPad.Track.Track{n}.EllipseHandle,'g');
            set(hTrackPad.Track.Track{n}.EllipseHandle,'Selected','on');
            set(hTrackPad.Track.Track{n}.EllipseHandle,'PickableParts','visible'); % allow the user to interact with the ellipse
            
            CurrentPosition=getPosition(hTrackPad.Track.Track{n}.EllipseHandle);
            wait(hTrackPad.Track.Track{n}.EllipseHandle);
            set(hTrackPad.Track.Track{n}.EllipseHandle,'PickableParts','none'); % don't allow the user to interact with the ellipse            
            setPosition(hTrackPad.Track.Track{n}.EllipseHandle,...
                round(getPosition(hTrackPad.Track.Track{n}.EllipseHandle)));
           
            % need to update mask!
            CorrectPosition=round(getPosition(hTrackPad.Track.Track{n}.EllipseHandle));
                        % need to update mask because next interation of find cell uses
            % this updated mask.
            ChangeInPosition=CorrectPosition-CurrentPosition;
            ChangeInRows=round(ChangeInPosition(2));
            ChangeInCols=round(ChangeInPosition(1));
            [r,c]=find(hTrackPad.Track.Track{n}.Mask);
            hTrackPad.Track.parameters.lastmask=false(size(hTrackPad.Track.parameters.lastmask));
            hTrackPad.Track.parameters.lastmask(r+ChangeInRows,c+ChangeInCols)=true;
            hTrackPad.Track.Track{n}.Mask=hTrackPad.Track.parameters.lastmask;
            hTrackPad.Track.Track{n}.Result.mask=hTrackPad.Track.parameters.lastmask;
            % need to update CellIm so that RefImage is modified with
            % corrected cell image
            b=false(size(hTrackPad.Track.Track{n}.CellIm));
            b(isnan(hTrackPad.Track.Track{n}.CellIm))=true;
            im=squeeze(hTrackPad.ImageStack.Stack(:,:,1,n)); 
            newCellIm=single(zeros(size(b)));
            newCellIm(:)=im(hTrackPad.Track.Track{n}.Mask);
            newCellIm(b)=NaN;
            hTrackPad.Track.Track{n}.CellIm=newCellIm;
            
            set(hTrackPad.Track.Track{n}.EllipseHandle,'Selected','off');
            setColor(hTrackPad.Track.Track{n}.EllipseHandle,'b');
            SetCell(hTrackPad.Track.Track{n}); 
            hTrackPad.FrameSliderHandle.Enable='on';
            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
            hTrackPad.ImageContextMenu.StopTrack.Visible='on';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
        end        
        function PauseTracking(hObject,EventData,hTrackPad)
            if ~isempty(hTrackPad.Track)
                if strcmp(hTrackPad.Track.FindCellState,'go')
                    notify(hTrackPad,'PauseEvent');
                    display('Pausing');
                    hTrackPad.ImageContextMenu.EditTrack.Visible='on';
                    hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
                    hTrackPad.ImageContextMenu.StopTrack.Visible='on';
                    hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
                end
                
            end
        end 
        
        
        
        function LoadImageStack(hObject,EventData,hTrackPad)
            [FileName,PathName,FilterIndex] = uigetfile('*.mat','Select ImageStack file');
            s=load([PathName FileName]);
            StackData=fieldnames(s);
            if isa(s.(StackData{1}),'ImageStack')
                delete(hTrackPad.ImageStack);
                hTrackPad.ImageStack=s.(StackData{1});
            else
                error('Not an ImageStack object');
            end
        end
        
        function OpenAnnotationTable(hObject,EventData,hTrackPad)
            fh=figure('Name','Annotation table','NumberTitle','off');
            set(fh,'Menubar','none');
            set(fh,'Toolbar','none');
            FigurePosition=get(fh,'Position');
            FigurePosition(3:4)=[350,430];
            fh.Position=FigurePosition;          
            Subsets=hTrackPad.CellProperties(3);
            data=cell(20,2);
            for i=1:20
                if i<length(Subsets.Type)
                    data{i,1}=Subsets.Type{i+1};
                    data{i,2}=Subsets.Symbol{i+1};
                end
            end
            t=uitable(fh,'Data',data);
            t.ColumnWidth={200,60};          
            t.Position=[20,20,300,390];
            get(t,'Position');
            t.ColumnName={'Type','Symbol'};
            t.ColumnFormat={'char','char'};
            t.ColumnEditable=[true,true];
            fh.DeleteFcn={@hTrackPad.SaveAnnotationTable,hTrackPad};
        end
        function SaveAnnotationTable(hObject,EventData,hTrackPad)
            data=hObject.Children.Data;
            Type{1}='No annotation';
            Symbol{1}='NA';
            Str{1}=[Type{1} ' (' Symbol{1} ')'];
            for i=1:size(data,1)
                if ~isempty(data{i,1})
                    Type{i+1}=data{i,1};
                    Symbol{i+1}=data{i,2};
                    Str{i+1}=[Type{i+1} ' (' Symbol{i+1} ')'];
                end
            end
            hTrackPad.CellProperties(3).Name='Subsets';
            hTrackPad.CellProperties(3).Type=Type;
            hTrackPad.CellProperties(3).Symbol=Symbol;
            hTrackPad.CellProperties(3).String=Str;
        end
        function EditAnnotationTable(hObject,EventData,hTrackPad)
        end
        
        function setThreshold(Object,EventData,hTrackPad)
            if ~isempty(hTrackPad.Tracks)
                CreateTable(hTrackPad.Tracks);
                tbl=hTrackPad.Tracks.tbl;
                x=[];
                h=figure('Name',[Object.Label, ': Adjust position of red cursor and click']);
                set(h,'NumberTitle','off');
                set(h,'MenuBar','none');
                set(h,'Toolbar','none');
                
                
                switch(Object.Label)
                    case 'Search radius'
                        for i=1:height(tbl)
                            if size(tbl.Position{i},1)>1
                                d=tbl.Position{i}(2:end,1:2)-tbl.Position{i}(1:end-1,1:2);
                                d=sqrt(d(:,1).^2+(d(:,2).^2));
                            end
                            x=[x;d];
                        end
                        histogram(x,40);
                        X=get(gca,'XLim');
                        SR=hTrackPad.CurrentTrackingParameters.SearchRadius;
                        fcn = makeConstrainToRectFcn('impoint',[0,2*X(2)],[0,0.1]);
                        CursorHandle=impoint(gca,SR,0);
                        api=iptgetapi(CursorHandle);
                        setColor(CursorHandle,'r');
                        api.setPositionConstraintFcn(fcn);
                        set(h,'DeleteFcn',{@hTrackPad.getThreshold,hTrackPad,CursorHandle,'Search radius'});
                    case 'Nucleus radius'
                        for i=1:height(tbl)
                            x=[x;tbl.Position{i}(:,3);tbl.Position{i}(:,4)];                           
                        end
                        histogram(x,40);
                        X=get(gca,'XLim');
                        NR=hTrackPad.CurrentTrackingParameters.NucleusRadius;
                        fcn = makeConstrainToRectFcn('impoint',[0,2*X(2)],[0,0.1]);
                        CursorHandle=impoint(gca,NR,0);
                        api=iptgetapi(CursorHandle);
                        setColor(CursorHandle,'r');
                        api.setPositionConstraintFcn(fcn);
                        set(h,'DeleteFcn',{@hTrackPad.getThreshold,hTrackPad,CursorHandle,'Nucleus radius'});
                    case 'Correlation threshold'
                        for i=1:height(tbl)
                            x=[x tbl.rho{i}];                            
                        end
                        x=x(~isnan(x));
                        histogram(x,40);
                        X=get(gca,'XLim');
                        CT=hTrackPad.CurrentTrackingParameters.CorrelationThreshold;
                        fcn = makeConstrainToRectFcn('impoint',[0,2*X(2)],[0,0.1]);
                        CursorHandle=impoint(gca,CT,0);
                        api=iptgetapi(CursorHandle);
                        setColor(CursorHandle,'r');
                        api.setPositionConstraintFcn(fcn);
                        set(h,'DeleteFcn',{@hTrackPad.getThreshold,hTrackPad,CursorHandle,'Correlation threshold'});
                end
                
                
                
                
            end
        end
        
        function getThreshold(hObject,callbackdata,hTrackPad,CursorHandle,TypeOfParameter)
            x=getPosition(CursorHandle);
            switch(TypeOfParameter)
                case 'Search radius'
                    hTrackPad.CurrentTrackingParameters.SearchRadius=round(x(1));
                case 'Nucleus radius'
                     hTrackPad.CurrentTrackingParameters.NucleusRadius=round(x(1));
                case 'Correlation threshold'
                    hTrackPad.CurrentTrackingParameters.CorrelationThreshold=x(1);
            end
        end
        
        function getAnnotationInfo(hObject,EventData,TrackID, CellTrackCollection)
            CellTrackCollection.CurrentTrack=CellTrackCollection.Tracks(TrackID).Track; % make sellected track editable
            hTrackPad=CellTrackCollection.CntrlObj;
            hTrackPad.Track=CellTrackCollection.CurrentTrack;
            % make all annotations not selectable
            m=hTrackPad.ImageStack.CurrentNdx;
            n=length(CellTrackCollection.Tracks);
            for i=1:n
                if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})
                    hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                    set(hAnnotation,'PickableParts','none');                
                    if i==TrackID
                        for j=1:length(hTrackPad.Tracks.Tracks(i).Track.Track)
                            if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{j})
                                set(hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle,'Color',[1,0,0]);
                            end
                        end
                        CellTrackCollection.CurrentTrackID=TrackID;
                    end
                    set(hAnnotation,'ButtonDownFcn',''); % disable callbacks.
                end                
            end
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';           
           
            
        end
        
        function CloseAnnotationFigure(src,callbackdata,hTrackPad)
                CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;
                n=length(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track);
                for i=1:n
                    if ~isempty(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i})
                        set(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i}.AnnotationHandle,'Color',[1,1,1]);
                    end
                end
                hTrackPad.Tracks.CurrentTrackID=0; % reset track or new track selection
                hTrackPad.Tracks.CurrentTrack=[];
                hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
                hTrackPad.ImageContextMenu.StartTrack.Visible='on';
                hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                delete(src);
                hTrackPad.AnnotationFigureHandle=[];
                hTrackPad.Track=[];
        end
        
        function getParent(hObject,EventData,TrackID,CellTrackCollection)
            hTrackPad=CellTrackCollection.CntrlObj;
            hTrackPad.FrameSliderHandle.Enable='on';
            hTrackPad.AnnotationFigureHandle.Visible='on';
            axes(hTrackPad.ImageHandle.Parent); % make sure TrackPad axes are still the current axes for text below
            n=CellTrackCollection.CurrentTrackID; % assign parent that was selected            
            CellTrackCollection.Tracks(n).Parent=CellTrackCollection.Tracks(TrackID).Track;
            CellTrackCollection.Tracks(n).ParentID=TrackID;
                    
            
            % Mark parent

            % disable marked parent candidates    
            ndx=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1);
            for i=1:length(hTrackPad.Tracks.Tracks);
                m=find(~(cellfun(@(x) isempty(x), ...
                        hTrackPad.Tracks.Tracks(i).Track.Track)),1,'last');
                if (ndx-1)==m                   

                    % set parent and daughter annotation
                    if ~isempty(CellTrackCollection.Tracks(n).Parent.Track{m}.Annotation)
                        delete(CellTrackCollection.Tracks(n).Parent.Track{m}.AnnotationHandle);
                    end
                    CellTrackCollection.Tracks(n).Parent.Track{m}.Annotation.Name=...
                         hTrackPad.CellProperties(2).Name; % Fate
                    CellTrackCollection.Tracks(n).Parent.Track{m}.Annotation.Type=...
                         hTrackPad.CellProperties(2).Type{2}; % Division
                     CellTrackCollection.Tracks(n).Parent.Track{m}.Annotation.Symbol=...
                         hTrackPad.CellProperties(2).Symbol{2}; % DI                     
                     
                     Position=CellTrackCollection.Tracks(n).Parent.Track{m}.Position;
                     
                     CellTrackCollection.Tracks(n).Parent.Track{m}.AnnotationHandle=...
                         text(Position(1)+Position(3)/2,Position(2)+Position(4)/2,...
                         hTrackPad.CellProperties(2).Symbol{2},...
                         'Color','w','HorizontalAlignment','center','PickableParts','none');
                     
                     if ~isempty(CellTrackCollection.Tracks(n).Track.Track{ndx}.Annotation)
                         delete(CellTrackCollection.Tracks(n).Track.Track{ndx}.AnnotationHandle);
                     end
                     CellTrackCollection.Tracks(n).Track.Track{ndx}.Annotation.Name=...
                         hTrackPad.CellProperties(1).Name; % Origin
                    CellTrackCollection.Tracks(n).Track.Track{ndx}.Annotation.Type=...
                         hTrackPad.CellProperties(1).Type{2}; % daughter
                    CellTrackCollection.Tracks(n).Track.Track{ndx}.Annotation.Symbol=...
                         hTrackPad.CellProperties(1).Symbol{2}; % DA
                    Position=CellTrackCollection.Tracks(n).Track.Track{ndx}.Position;
                    CellTrackCollection.Tracks(n).Track.Track{ndx}.AnnotationHandle=...
                         text(Position(1)+Position(3)/2,Position(2)+Position(4)/2,...
                         hTrackPad.CellProperties(1).Symbol{2},...
                         'Color','w','HorizontalAlignment','center','Visible','off','PickableParts','none'); % DA
                    hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                    set(hAnnotation,'PickableParts','none');
                    set(hAnnotation,'ButtonDownFcn',[]);
                end
            end 
        end
        
       
        
        
    end
    
    
end



