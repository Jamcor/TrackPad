classdef TrackPad < handle
    % User interface for tracking cells
    
    properties
        FigureHandle
        AnnotationFigureHandle=[];
        MenuHandle
        AnnotationDisplay
        FrameSliderHandle
        FrameTextBox
        FrameTimeBox
        CursorPositionBox
        ImageContextMenu
        ToolBarHandle
        Track=[]
        Tracks=[];
        TrackTable
        TrackPanel
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
            obj.ImageStack.CurrentNdx=1;  %ndx for frame number
            obj.FigureHandle=figure('Name',obj.ImageStack.PathName,'MenuBar','none',...
                'ToolBar','figure','KeyPressFcn',{@obj.HotKeyFcn,obj},'Color',[0.8 0.8 0.8],...
                'WindowButtonMotionFcn', {@obj.getCursorPosition,obj}); %make figure handle with hotkeys and toolbar
            obj.FigureHandle.Color=[0.3 0.3 0.3];
            %get and set toolbar children handles to visible (default is not visible) so new buttons
            %can be added to existing 'figure' toolbar instead of creating
            %a new toolbar
            obj.ToolBarHandle=findall(gcf,'tag','FigureToolBar');
            toolbarhandle=allchild(obj.ToolBarHandle);
            set(toolbarhandle,'HandleVisibility','on');
            delete(toolbarhandle([1:9,12:end]));
            
            %%add user defined toolbar features
            
            %add save and open pushbuttons and use same callback as options
            %in dropdown menu (below)
            [~, rootdir] = ipticondir;
            savebutton=fullfile(rootdir, '/file_save.PNG');
            [cdata,~,alpha] = imread(savebutton);
            savebutton = double(cdata)/256/256;
            savebutton(~alpha)=NaN;
            savebuttontool=uipushtool(obj.ToolBarHandle,'TooltipString','Save track file',...
                'ClickedCallBack',{@obj.SaveTracks,obj});
            savebuttontool.CData=savebutton;
            
            openbutton=fullfile(rootdir, '/file_open.PNG');
            [cdata,~,alpha] = imread(openbutton);
            openbutton = double(cdata)/256/256;
            openbutton(~alpha)=NaN;
            openbuttontool=uipushtool(obj.ToolBarHandle,'TooltipString','Open track file',...
                'ClickedCallBack',{@obj.OpenTracks,obj});
            openbuttontool.CData=openbutton;
            
            %add play forward button
            playforward = fullfile(rootdir, '/greenarrowicon.gif');
            [cdata,map] = imread(playforward);
            map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;% Convert white pixels into a transparent background
            playforward = ind2rgb(cdata,map);
            playbackward = playforward(:,[16:-1:1],:);
            playbackwardtool=uipushtool(obj.ToolBarHandle,'TooltipString','Play backward',...
                'ClickedCallBack',{@obj.PlayBackward,obj},'Interruptible','off');
            playbackwardtool.CData=playbackward;
            playforwardtool=uipushtool(obj.ToolBarHandle,'TooltipString','Play forward',...
                'ClickedCallBack',{@obj.PlayForward,obj},'Interruptible','off');
            playforwardtool.CData=playforward;
            
            %add go to start and end buttons
            go2startpushtool=uipushtool(obj.ToolBarHandle,'TooltipString',...
                'Go to start of track','ClickedCallBack',{@obj.ReturnToStart,obj},'Separator','on','Interruptible','off');
            go2startpushtool.CData=imresize(imread('LeftArrow.jpg'),[16 16]);
            go2endpushtool=uipushtool(obj.ToolBarHandle,'TooltipString',...
                'Go to end of track','ClickedCallBack',{@obj.GoToEnd,obj},'Separator','on','Interruptible','off');
            go2endpushtool.CData=imresize(imread('RightArrow.jpg'),[16 16]);
            
            %modify toolbar appearance by accessing java components
            drawnow;
            %             ModifyFigureToolBar(obj);
            
            %initialise dropdown menus
            FileMenuHandle = uimenu(obj.FigureHandle,'Label','File');
            uimenu(FileMenuHandle,'Label','Open Tracks',...
                'Callback',{@obj.OpenTracks,obj});
            uimenu(FileMenuHandle,'Label','Save Tracks',...
                'Callback',{@obj.SaveTracks,obj});
            ParametersMenuHandle=uimenu(obj.FigureHandle,'Label','Parameters');
            uimenu(ParametersMenuHandle,'Label','Search radius',...
                'Callback',{@obj.setThreshold,obj});
            uimenu(ParametersMenuHandle,'Label','Nucleus radius',...
                'Callback',{@obj.setThreshold,obj});
            uimenu(ParametersMenuHandle,'Label','Correlation threshold',...
                'Callback',{@obj.setThreshold,obj});
            TrackTableMenuHandle=uimenu(obj.FigureHandle,'Label','TrackTable');
            uimenu(TrackTableMenuHandle,'Label','Open track table',...
                'Callback',{@obj.openTrackTable,obj});
            
            % create slider to control frame
            obj.FigureHandle.Units='Normalized';
            pos=obj.FigureHandle.Position;
            N=obj.ImageStack.NumberOfImages;
            
            %frame slider
            obj.FrameSliderHandle=uicontrol(obj.FigureHandle,'Style','slider',...
                'Value',1,'Tag','FrameSlider','Min',1,'Max',N,'SliderStep',[1/(N-1) 10/(N-1)]);
            obj.FrameSliderHandle.Units='Normalized';
            obj.FrameSliderHandle.Position=[0,0,1,pos(4)/40];
            obj.FrameSliderHandle.Callback={@obj.FrameChangeCallback,obj}; %callback for framechange
            
            %frame text box
            obj.FrameTextBox=uicontrol(obj.FigureHandle,'Style','text',...
                'String',['Frame 0000'],'ForegroundColor','white','Tag','slidertext');
            obj.FrameTextBox.Units='Normalized';
            obj.FrameTextBox.Position=[0,pos(4)/40,obj.FrameTextBox.Extent(3),obj.FrameTextBox.Extent(4)];
            obj.FrameTextBox.BackgroundColor=[0.3 0.3 0.3];
            
            %frame time box
            obj.FrameTimeBox=uicontrol(obj.FigureHandle,'Style','text',...
                'String',['Timestamp 0:0:0 (H:M:S)'],'ForegroundColor','white','Tag','slidertime');
            obj.FrameTimeBox.Units='Normalized';
            obj.FrameTimeBox.Position=[obj.FrameTextBox.Extent(3)*1.05,pos(4)/40,obj.FrameTimeBox.Extent(3),obj.FrameTimeBox.Extent(4)];
            obj.FrameTimeBox.BackgroundColor=[0.3 0.3 0.3];
            
            %add resize call back, scrollframes callback, and add image
            %data to GUI
            obj.FigureHandle.SizeChangedFcn={@obj.FigureResizeCallback,obj};
            obj.FigureHandle.WindowScrollWheelFcn={@obj.ScrollFrames,obj};
            obj.ImageHandle=imshow(obj.ImageStack.CData(:,:,1),obj.ImageStack.CMap{1}); %make image handle
            
            %add frame annotations (e.g. cursor position)
            obj.CursorPositionBox=uicontrol(obj.FigureHandle,'Style','text',...
                'ForegroundColor','white','Tag','cursorpositiontext');
            %             obj.CursorPositionBox.String=textwrap(obj.CursorPositionBox,{['X: ' num2str(0.00) ' Y: ' num2str(0.00)]});
            obj.CursorPositionBox.String={['X: ----'  ' Y: ----']};
            obj.CursorPositionBox.Units='Normalized';
            x=obj.FrameTimeBox.Extent(3) + obj.FrameTextBox.Extent(3);
            %             obj.CursorPositionBox.Position=[x*1.05,pos(4)/40,obj.CursorPositionBox.Extent(3),obj.CursorPositionBox.Extent(4)];
            obj.CursorPositionBox.Position=[1-obj.CursorPositionBox.Extent(3)*1.05,pos(4)/40,obj.CursorPositionBox.Extent(3),obj.CursorPositionBox.Extent(4)];
            
            obj.CursorPositionBox.BackgroundColor=[0.3 0.3 0.3];
            
            %create uipanel for track selection and display
            %determine position for uipanel
            obj.FigureHandle.CurrentAxes.Units='Normalized';
            axesposition=obj.FigureHandle.CurrentAxes.Position;
            x=(axesposition(1))/4;
            panelwidth=axesposition(1)/2;
            panelheight=axesposition(4)/2;
            y=axesposition(2)+axesposition(4)-panelheight;
            obj.FigureHandle.Units='Normalized';
            obj.TrackPanel.TrackPanel=uipanel(obj.FigureHandle,'Title','Track panel',...
                'BackgroundColor',[0.3 0.3 0.3],'ForegroundColor','white','Clipping','on','Position',[x,y,panelwidth,panelheight]);
            
            %clones selection menu
            obj.TrackPanel.ClonesPopup=uicontrol(obj.TrackPanel.TrackPanel,'Style','popupmenu',...
                'String',{'Select clone'},'Callback',{@obj.ChooseClone,obj});
            obj.TrackPanel.ClonesPopup.Units='Normalized';
            y=1-obj.TrackPanel.ClonesPopup.Extent(4)*1.05;
            width=0.90;
            height=obj.TrackPanel.ClonesPopup.Extent(4);
            obj.TrackPanel.ClonesPopup.Position=[0.05 y width height];
            
            %tracks selection menu
            obj.TrackPanel.TracksPopup=uicontrol(obj.TrackPanel.TrackPanel,'Style','popupmenu',...
                'String',{'Select track'},'Callback',{@obj.ChooseTrack,obj});
            obj.TrackPanel.TracksPopup.Units='Normalized';
            y=1-obj.TrackPanel.ClonesPopup.Extent(4)*1.05-obj.TrackPanel.TracksPopup.Extent(4);
            width=0.90;
            height=obj.TrackPanel.TracksPopup.Extent(4);
            obj.TrackPanel.TracksPopup.Position=[0.05 y width height];
            
            
            %current track display panel
            obj.TrackPanel.CurrentTrackPanel=uipanel(obj.TrackPanel.TrackPanel,'Title',...
                'Current track','BackgroundColor',[0.3 0.3 0.3],'ForegroundColor','white');
            obj.TrackPanel.CurrentTrackPanel.Units='Normalized';
            height=(1-obj.TrackPanel.ClonesPopup.Extent(4)-obj.TrackPanel.TracksPopup.Extent(4))/2;
            y=1-obj.TrackPanel.ClonesPopup.Extent(4)-obj.TrackPanel.TracksPopup.Extent(4)-height;
            obj.TrackPanel.CurrentTrackPanel.Position=[0.05 y 0.9 height];
            pos=(obj.TrackPanel.CurrentTrackPanel);
            
            %current track display text
            obj.TrackPanel.CurrentTrackDisplay=uicontrol(obj.TrackPanel.CurrentTrackPanel,'Style',...
                'text','BackgroundColor',[0.3 0.3 0.3],'ForegroundColor','green','FontWeight',...
                'bold','Tag','CurrentTrackDisplay');
            obj.TrackPanel.CurrentTrackDisplay.Units='Normalized';
            obj.TrackPanel.CurrentTrackDisplay.String=textwrap(obj.TrackPanel.CurrentTrackDisplay,...
                {'Current tracks'});
            
            obj.TrackPanel.CurrentTrackDisplay.Position=[0 0 1 1];
            Hjava = findjobj(obj.TrackPanel.CurrentTrackDisplay); %stackexchange function
            Hjava.setVerticalAlignment(javax.swing.JLabel.CENTER);
            obj.TrackPanel.TrackPanel.SizeChangedFcn={@obj.TrackPanelResize,obj}; %callback when trackpanel resized
            
            
            %             %indicator for tracking state (on=tracking, off=not tracking)
            %             obj.TrackPanel.TrackIndicator=uicontrol(obj.TrackPanel.TrackPanel,'Style','checkbox','Position',...
            %                 [10 100 100 50],'HitTest','off','BackgroundColor','white');
            
            % create image context menu
            c=uicontextmenu;
            obj.ImageHandle.UIContextMenu=c;
            obj.ImageContextMenu.StartTrack=uimenu(c,'Label','Start Track','Tag','StartTrack',...
                'Visible','on','Callback',{@obj.StartTrack,obj});
            obj.ImageContextMenu.EditTrack=uimenu(c,'Label','Edit Track','Tag','EditTrack',...
                'Visible','off','Callback',{@obj.EditTrack,obj});
            obj.ImageContextMenu.Reposition=uimenu(c,'Label','Reposition Ellipse (r)','Tag','Reposition',...
                'Visible','off','Callback',{@obj.RepositionEllipse,obj});
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
            obj.ImageContextMenu.Cancel=uimenu(c,'Label','Cancel','Tag','Cancel',...
                'Visible','off','Callback',{@obj.Cancel,obj}); %cancel
            obj.ImageContextMenu.ReturnToStart=uimenu(c,'Label','Return to start','Tag','ReturnToStart',...
                'Visible','off','Callback',{@obj.ReturnToStart,obj}); %return to start
            obj.ImageContextMenu.GoToEnd=uimenu(c,'Label','Go to end','Tag','GoToEnd',...
                'Visible','off','Callback',{@obj.GoToEnd,obj}); %go to end
            
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
            
            %optional cell properties (subsets)
            obj.CellProperties(3).Name='Subsets';
            obj.CellProperties(3).Type.Fluorescence={'No annotation','red','green'};
            obj.CellProperties(3).Symbol.Fluorescence={'NA','S1','S2'};
            obj.CellProperties(3).String.Fluorescence={'No annotation (NA)','red (S1)','green (S2)'};
            obj.CellProperties(3).Type.Differentiation={'No annotation'};
            obj.CellProperties(3).Symbol.Differentiation={'NA'};
            obj.CellProperties(3).String.Differentiation={'No annotation (NA)'};
            obj.CellProperties(3).Type.Morphology={'No annotation'};
            obj.CellProperties(3).Symbol.Morphology={'NA'};
            obj.CellProperties(3).String.Morphology={'No annotation (NA)'};
            obj.CellProperties(3).Type.Binucleation={'No annotation','binucleated'};
            obj.CellProperties(3).Symbol.Binucleation={'NA','BI'};
            obj.CellProperties(3).String.Binucleation={'No annotation (NA)','Binucleated (S1)'};
            obj.CellProperties(3).Type.PedigreeID={'No annotation'};
            obj.CellProperties(3).Symbol.PedigreeID={'NA'};
            obj.CellProperties(3).String.PedigreeID={'No annotation (NA)'};
            obj.CurrentTrackingParameters.NucleusRadius=35;
            obj.CurrentTrackingParameters.SearchRadius=10;
            obj.CurrentTrackingParameters.CorrelationThreshold=0.6;
            obj.FigureHandle.CloseRequestFcn={@obj.CloseTrackPad,obj};
            
            %add annotation table menu
            AnnotateMenuHandle = uimenu(obj.FigureHandle,'Label','Annotations');
            uimenu(AnnotateMenuHandle,'Label','Edit table',...
                'Callback',{@obj.OpenAnnotationTable,obj});
            
            %add annotation display menu
            AnnotationDisplayMenuHandle = uimenu(obj.FigureHandle,'Label','Display annotations');
            fnames=fieldnames(obj.CellProperties(3).Type);
            for i=1:length(fnames)
                uimenu(AnnotationDisplayMenuHandle,'Label',fnames{i},...
                    'Callback',{@obj.ChangeAnnotationDisplay,obj},'Tag','Change annotation display');
            end
            obj.AnnotationDisplay=fnames{1}; %set fluorescent annotation subsets by default
            %add close menu
            CloseMenuHandle=uimenu(obj.FigureHandle,'Label','Close');
            CloseMenuHandle.Callback={@obj.CloseTrackPad,obj};
            
        end
        
        function delete(obj)
            if ~isempty(obj.Tracks)
                button=questdlg('Save tracks?');
                if strcmp(button,'Yes')
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
                obj.ImageContextMenu.Reposition.Visible='on';
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
            obj.ImageContextMenu.Reposition.Visible='on';
            obj.ImageContextMenu.DeleteTrack.Visible='on';
            disp('End of Track Event');
        end
        function listenAppendedTrackEvent(obj,src,~)
            obj.ImageContextMenu.StartTrack.Visible='on';
        end
    end
    
    methods (Static=true)
        function FigureResizeCallback(hObject,EventData,hTrackPad)
            hslider=findobj(hObject,'tag','FrameSlider');
            slidertext=findobj(hObject,'tag','slidertext');
            slidertime=findobj(hObject,'tag','slidertime');
            hObject.Units='Normalized'; %set figure units to normalized
            hslider.Units='Normalized'; %set slider units to normalized
            slidertext.Units='Normalized';
            slidertime.Units='Normalized';
            pos=hObject.Position;
            hslider.Position=[0,0,1,pos(4)/40];
            slidertext.Position=[0,pos(4)/40,slidertext.Extent(3),slidertext.Extent(4)];
            slidertime.Position=[slidertext.Extent(3)*1.1,pos(4)/40,slidertime.Extent(3),slidertime.Extent(4)];
            
            %cursor position
            cursorposition=hTrackPad.CursorPositionBox;
            cursorposition.Units='Normalized';
            %             cursorposition.String=textwrap(cursorposition,{['X: ' num2str(0.00) ' Y: ' num2str(0.00)]});
            cursorposition.String={['X: ' num2str(0.00) ' Y: ' num2str(0.00)]};
            %             x=slidertime.Extent(3) + slidertext.Extent(3);
            cursorposition.Position=[1-cursorposition.Extent(3)*1.1,pos(4)/40,cursorposition.Extent(3),cursorposition.Extent(4)];
            %             cursorposition.Position=[x*1.05,pos(4)/40,cursorposition.Extent(3),cursorposition.Extent(4)];
            cursorposition.BackgroundColor=[0.3 0.3 0.3];
            
            %restore default units
            hObject.Units='pixels'; %set figure units to normalized
            hslider.Units='pixels'; %set slider units to normalized
            slidertext.Units='pixels';
            slidertime.Units='pixels';
            cursorposition.Units='pixels';
            
        end
        
        function TrackPanelResize(hObject,EventData,hTrackPad)
            hTrackPad.FigureHandle.CurrentAxes.Units='Normalized';
            pos=hTrackPad.FigureHandle.CurrentAxes.Position;
            
            x=pos(1)/4;
            panelwidth=pos(1)/1.5;
            panelheight=pos(4)/2;
            y=pos(4)/3;
            hTrackPad.TrackPanel.TrackPanel.Position=[x y panelwidth panelheight];
            
            %current track display text
            pos=getpixelposition(hTrackPad.TrackPanel.CurrentTrackPanel);
            hTrackPad.TrackPanel.CurrentTrackDisplay.Position=[0 0 1 1];
            Hjava = findjobj(hTrackPad.TrackPanel.CurrentTrackDisplay); %stackexchange function
            Hjava.setVerticalAlignment(javax.swing.JLabel.CENTER);
        end
        
        function ScrollFrames(hObject,EventData,obj) %scroll through frames with mouse wheel
            increment=EventData.VerticalScrollCount;
            currentframe=obj.ImageStack.CurrentNdx;
            newframe=currentframe-increment;
            if newframe >= 1 && newframe <= obj.ImageStack.NumberOfImages %can't scroll outside limits of stack
                obj.ImageStack.CurrentNdx=newframe;
            end
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
                
                % update slider
                hTrackPad.FrameSliderHandle.Value=n;
                
                % update image
                hTrackPad.ImageHandle.CData=hTrackPad.ImageStack.CData(:,:,n); %update image with new frame
                ax=get(hTrackPad.ImageHandle,'parent');
                colormap(ax,hTrackPad.ImageStack.CMap{n});
                
                % update displayed Frame info and cursor position
                hTrackPad.FigureHandle.Units='Normalized';
                pos=hTrackPad.FigureHandle.Position;
                framenumb=sprintf('%04d',n);
                hTrackPad.FrameTextBox.String=['Frame ' num2str(framenumb)];
                t=hTrackPad.ImageStack.AcquisitionTimes(n)...
                    -hTrackPad.ImageStack.AcquisitionTimes(1);
                h=floor(t*24);
                m=floor((t-h/24)*24*60);
                s=floor((t-h/24-m/24/60)*24*60*60);
                hTrackPad.FrameTextBox.Units='Normalized';
                hTrackPad.FrameTimeBox.String=['Timestamp ', num2str(h),':',...
                    num2str(m),':',num2str(s),' (H:M:S)'];
                
                hTrackPad.FrameTimeBox.Units='Normalized';
                hTrackPad.FrameTextBox.Units='Normalized';
                hTrackPad.CursorPositionBox.Units='Normalized';
                hTrackPad.FrameTimeBox.Units='pixels';
                hTrackPad.FrameTextBox.Units='pixels';
                hTrackPad.CursorPositionBox.Units='pixels';
                hTrackPad.FigureHandle.Units='pixels';
                
                if ~isempty(hTrackPad.Tracks)
                    hTrackPad.DisplayAnnotation(hObject,EventData,hTrackPad);
                end
                if ~isempty(hTrackPad.Track)  %if current track is not empty
                    if ~isempty(hTrackPad.Track.Track{n})
                        try
                            set(hTrackPad.Track.CurrentEllipse,'PickableParts','none'); % doesn't allow the user to interact with the ellipse
                        catch
                            %                             disp('here');
                        end

                        trackrange(1)=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),...
                            1,'first');
                        trackrange(2)=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),...
                            1,'last');
                        
                        condition1=hTrackPad.ImageStack.CurrentNdx>=trackrange(1) && hTrackPad.ImageStack.CurrentNdx<=trackrange(2);
                        condition2=hTrackPad.ImageStack.LastNdx>=trackrange(1) && hTrackPad.ImageStack.LastNdx<=trackrange(2);
      
                        if (hTrackPad.Tracks.CurrentTrackID==0) || hTrackPad.Tracks.Editing % in track or edit mode
                            hTrackPad.Track.CurrentEllipse=hTrackPad.Track.Track{n}.EllipseHandle;
                            if condition1 && condition2
                                set(hTrackPad.Track.Track{hTrackPad.ImageStack.LastNdx}.EllipseHandle,'Visible','off');
                                set(hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.EllipseHandle,'Visible','on');
                            elseif condition1 && ~condition2
                                set(hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.EllipseHandle,'Visible','on');
                            end
                            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
                            hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
                            hTrackPad.ImageContextMenu.StopTrack.Visible='on';
                            obj.ImageContextMenu.Reposition.Visible='on';
                            
                        else
                            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
                        end
                        
                        hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
                        if isvalid(hTrackPad.Track.CurrentEllipse)
                            set(hTrackPad.Track.CurrentEllipse,'Visible','on');
                        end
                    elseif isempty(hTrackPad.Track.Track{n}) % don't show context menu if the is no ellipse
                        if (hTrackPad.Tracks.CurrentTrackID==0) || hTrackPad.Tracks.Editing
                        set(hTrackPad.Track.CurrentEllipse,'Visible','off');
                        end
                        hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                        hTrackPad.ImageContextMenu.Reposition.Visible='off';
                        hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                        hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                        hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                        hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
                    end
                else
                    hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                    hTrackPad.ImageContextMenu.Reposition.Visible='off';
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
            %figure(hTrackPad.FigureHandle);
            currentrackid=hTrackPad.Tracks.CurrentTrackID;
            n=hTrackPad.ImageStack.CurrentNdx;
            last=hTrackPad.ImageStack.LastNdx;
            fnames=fieldnames(hTrackPad.CellProperties(3).Type);
            subsetdisplay=hTrackPad.AnnotationDisplay;
            if (n~=last)
                % update Stored Tracks
                m=length(hTrackPad.Tracks.Tracks);
                for i=1:m
                    Track=hTrackPad.Tracks.Tracks(i).Track.Track;
                    range=hTrackPad.Tracks.Tracks(i).Track.trackrange;
                    %switch off last annotations
                    if ~isempty(Track{last})
                        %                         if ~isempty(Track{last}.AnnotationHandle)
                        %                             set(Track{last}.AnnotationHandle,'Visible','off');
                        delete(Track{last}.AnnotationHandle);
                        %                         end
                    end
                    if ~isempty(Track{n}) && sum(n~=range)==2 %update annotations for all but first frame
                        if isempty(Track{n}.AnnotationHandle)
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol.(subsetdisplay),...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique');
                            if i~=currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                        else
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol.(subsetdisplay),...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique','Visible','on');
                            %Track{n}.AnnotationHandle.String=Track{n}.Annotation.Symbol.(subsetdisplay);
                            if i~=currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                        end
                    elseif ~isempty(Track{n}) &&(n==range(1)|| n==range(2))%update annotations for first frame
                        if isempty(Track{n}.AnnotationHandle)
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique');
                            if i~=currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                        else
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique');
                            set(Track{n}.AnnotationHandle,'Visible','on','Clipping','on');
                            if i~=currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==currentrackid
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                        end
                        
                    end
                end
            end
        end
        
        function FrameChangeCallback(hObject,EventData,hTrackPad)
            n=round(hObject.Value);
            hTrackPad.ImageStack.CurrentNdx=n;
        end
        %StartTrack is run after the user selects Start Track from the
        %UIContext menu
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
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            %append track to TrackCollection object
            if ~hTrackPad.Tracks.CurrentTrackID
                hTrackPad.Tracks.Append;
                hTrackPad.Track=[];% no longer can be edited
                hellipse=findall(gca,'Tag','imellipse');%remove ellipse
                delete(hellipse);
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
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='off';
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
            
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
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
        end
        
        %cancels track selection
        function Cancel(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            hTrackPad.ImageContextMenu.StartTrack.Visible='on';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
            n=length(hTrackPad.Tracks.Tracks);
            m=hTrackPad.ImageStack.CurrentNdx; % make all tracks in current frame unselectable
            for i=1:n
                if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})
                    hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                    set(hAnnotation,'PickableParts','none');
                    set(hAnnotation,'ButtonDownFcn',''); % disable callbacks.
                    set(hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle,'Color',[0,1,0]);
                end
            end
            
            if hTrackPad.Tracks.Editing
                hTrackPad.Tracks.Editing=false;
                delete(findobj(gcf,'Tag','imellipse'));
            end
            
            hTrackPad.Tracks.CurrentTrackID=0;
            hTrackPad.Tracks.CurrentTrack=[];
            hTrackPad.Tracks.Editing=false;
            hTrackPad.Track=[]; %no current track
            hTrackPad.TrackPanel.CurrentTrackDisplay.String='No track selected';
            hTrackPad.TrackPanel.CurrentTrackDisplay.ForegroundColor='red';
        end
        
        function PlayForward(varargin)
            
            if nargin==3
                hTrackPad=varargin{3};
            elseif nargin==1
                
                hTrackPad=varargin{1};
            end
            
            m=hTrackPad.ImageStack.CurrentNdx;
            numb_images=hTrackPad.ImageStack.NumberOfImages;
            for i=m:numb_images
                hTrackPad.ImageStack.CurrentNdx=i;
                pause(0.005);
            end
            hTrackPad.ImageStack.LastNdx=numb_images;
            hTrackPad.ImageStack.CurrentNdx=1;
        end
        
        function PlayBackward(varargin)
            
            if nargin==3
                hTrackPad=varargin{3};
            elseif nargin==1
                
                hTrackPad=varargin{1};
            end
            m=hTrackPad.ImageStack.CurrentNdx;
            for i=1:m-1
                hTrackPad.ImageStack.CurrentNdx=hTrackPad.ImageStack.CurrentNdx-1;
                pause(0.005);
            end
            hTrackPad.ImageStack.CurrentNdx=1;
        end
        
        %returns to start of a cell's track
        function ReturnToStart(hObject,EventData,hTrackPad)
            %set context menus
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off';
            hTrackPad.ImageContextMenu.GoToEnd.Visible='on';
            
            %get track info
            CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;
            startframe=find(cellfun(@(x) ~isempty(x),...
                hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track),1,'first');
            position=hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{startframe}.Position;
            
            %repositioning of axes
            hTrackPad.ImageStack.LastNdx=hTrackPad.ImageStack.CurrentNdx;
            hTrackPad.ImageStack.CurrentNdx=startframe;
            x=position(1); y=position(2);
            x=[x-200,x+200]; y=[y-200,y+200];
            if x(1)<1
                x(1)=1;
            elseif x(2)>1392
                x(2)=1392;
            end
            if y(2)<1
                y(1)=1;
            elseif y(2)>1040
                y(2)=1040;
            end
            zoomdata=getappdata(gca, 'matlab_graphics_resetplotview');
            if ~isempty(zoomdata)
                zoomdata.XLim=[0.5000 1.3925e+03];
                zoomdata.YLim=[0.5000 1.0405e+03];
                setappdata(gca, 'matlab_graphics_resetplotview',zoomdata);
            else
                zoom reset
            end
            set(hTrackPad.FigureHandle.CurrentAxes,'XLim',sort(x));
            set(hTrackPad.FigureHandle.CurrentAxes,'YLim',sort(y));
            hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            
        end
        
        %goes to the end of a cell's track
        function GoToEnd(hObject,EventData,hTrackPad)
            %set context menus
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            hTrackPad.ImageContextMenu.Cancel.Visible='off';
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='on';
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off';
            %get track info
            CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;
            endframe=find(cellfun(@(x) ~isempty(x),...
                hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track),1,'last');
            position=hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{endframe}.Position;
            
            %repositioning of axes
            hTrackPad.ImageStack.LastNdx=hTrackPad.ImageStack.CurrentNdx;
            hTrackPad.ImageStack.CurrentNdx=endframe;
            x=position(1); y=position(2);
            x=[x-200,x+200]; y=[y-200,y+200];
            if x(1)<1
                x(1)=1;
            elseif x(2)>1392
                x(2)=1392;
            end
            if y(2)<1
                y(1)=1;
            elseif y(2)>1040
                y(2)=1040;
            end
            zoomdata=getappdata(gca, 'matlab_graphics_resetplotview');
            if ~isempty(zoomdata)
                zoomdata.XLim=[0.5000 1.3925e+03];
                zoomdata.YLim=[0.5000 1.0405e+03];
                setappdata(gca, 'matlab_graphics_resetplotview',zoomdata);
            else
                zoom reset
            end
            set(hTrackPad.FigureHandle.CurrentAxes,'XLim',sort(x));
            set(hTrackPad.FigureHandle.CurrentAxes,'YLim',sort(y));
            hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            
        end
        
        function AnnotateTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='off';
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off';
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off';
                        hfig=figure('Name','Annotate track','ToolBar','none',...
                            'MenuBar','none','NumberTitle','off','WindowStyle','modal');
%             hfig=figure('Name','Annotate track','ToolBar','none',...
%                 'MenuBar','none','NumberTitle','off'); %without modal set
            handles=guihandles(hfig);
            set(hfig,'CloseRequestFcn',{@hTrackPad.CloseAnnotationFigure,hTrackPad});
            hTrackPad.AnnotationFigureHandle=hfig;
            CellProperties=hTrackPad.CellProperties;
            % calculate height of figure
            h=0;
            for i=1:2
                h=h+45*length(CellProperties(i).Type);
            end
            
            fnames=fieldnames(CellProperties(3).Type);
            
            for i=1:length(fnames)-1 %don't include pedigreeID in annotation table, i.e. exclude last subset
                h=h+45*length(CellProperties(3).Type.(fnames{i}));
            end
            
            hfig.Position(2)=100;
            hfig.Position(3)=300;
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
            
            for i=1:length(CellProperties)-1
                str=[CellProperties(i).Name];
                BGHeight=(length(CellProperties(i).Type)+1)*25;
                h=h-BGHeight-10;
                handles.(str).BG=uibuttongroup(hfig,'Visible','on','Units','pixels');
                handles.(str).BG.Position=[25,h,150,BGHeight];
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
                
            end
            
            %add buttons for annotation subsets
            subsets=CellProperties(3);
            str='Subsets';
            fnames=fieldnames(subsets.Type);
            numb_subsets=length(fnames)-1; %don't add pedigreeID to annotation table, i.e. exclude last subset
            
            for i=1:numb_subsets
                BGHeight=(length(subsets.Type.(fnames{i}))+1)*25;
                h=h-BGHeight-10;
                handles.(str).(fnames{i}).BG=uibuttongroup(hfig,'Visible','on','Units','pixels');
                handles.(str).(fnames{i}).BG.Position=[25,h,150,BGHeight];
                set(handles.(str).(fnames{i}).BG,'SelectionChangedFcn',{@hTrackPad.AnnotationHandler,hTrackPad});
                
                handles.(str).(fnames{i}).BG.Title=fnames{i};
                n=length(subsets.Type.(fnames{i}));
                % create radio buttons
                
                for j=1:n
                    handles.(str).(fnames{i}).RB(j)=uicontrol(handles.(str).(fnames{i}).BG,'Style',...
                        'radiobutton',...
                        'String',subsets.String.(fnames{i}){j},...
                        'position',[4,BGHeight-j*20-20,160,15],...
                        'HandleVisibility','off');
                end
                
            end
            
            % update state of annotation tool to reflect current track
            % annotation state
            for i=1:length(CellProperties)
                str=[CellProperties(i).Name];
                n=length(CellProperties(i).Type);
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
                        for ii=1:numb_subsets
                            if ~isempty(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation)
                                n=length(CellProperties(i).Type.(fnames{ii}));
                                s=[hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation.Type.(fnames{ii}),...
                                    ' (',hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation.Symbol.(fnames{ii}),...
                                    ')'];
                                for j=1:n
                                    if strcmp(handles.(str).(fnames{ii}).RB(j).String,s)
                                        handles.(str).(fnames{ii}).RB(j).Value=1;
                                    end
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
                                hTrackPad.Track.Track{ndx}.Annotation.Symbol,'Color','g',...
                                'HorizontalAlignment','center','PickableParts','none','FontAngle','oblique');
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
                    ndx=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1,'last'); %the last frame for the cell
                    CurrentNdx=hTrackPad.ImageStack.CurrentNdx; %current frame number of axes
                    n=hTrackPad.Tracks.CurrentTrackID;
                    
                    if ~isempty(hTrackPad.Track.Track{ndx}.Annotation)
                        delete(hTrackPad.Track.Track{ndx}.AnnotationHandle);
                    end
                    
                    if ~isempty(hTrackPad.Tracks.Tracks(n).Track.Track{ndx}.Annotation)
                        delete(hTrackPad.Tracks.Tracks(n).Track.Track{ndx}.AnnotationHandle);
                    end
                    
                    Position=hTrackPad.Track.Track{ndx}.Position;
                    x=Position(1)+Position(3)/2;
                    y=Position(2)+Position(4)/2;
                    switch(EventData.NewValue.String)
                        case CellProperties(2).String{1} % not complete
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{1};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{1};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{1},...
                                'Color','g','HorizontalAlignment','center','Visible','off',...
                                'PickableParts','none','FontAngle','oblique');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                        case CellProperties(2).String{2}  % Division
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{2};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{2};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{2},...
                                'Color','g','HorizontalAlignment','center','Visible','off',...
                                'PickableParts','none','FontAngle','oblique');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                        case CellProperties(2).String{3}  % Death
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{3};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{3};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{3},...
                                'Color','g','HorizontalAlignment','center','Visible','off',...
                                'PickableParts','none','FontAngle','oblique');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                        case CellProperties(2).String{4}  % Lost
                            hTrackPad.Track.Track{ndx}.Annotation.Type=CellProperties(2).Type{4};
                            hTrackPad.Track.Track{ndx}.Annotation.Symbol=CellProperties(2).Symbol{4};
                            hTrackPad.Track.Track{ndx}.AnnotationHandle=text(x,y,CellProperties(2).Symbol{4},...
                                'Color','g','HorizontalAlignment','center','Visible','off',...
                                'PickableParts','none','FontAngle','oblique');
                            if CurrentNdx==ndx
                                hTrackPad.Track.Track{ndx}.AnnotationHandle.Visible='on';
                            end
                    end
                otherwise
                    subsetdisplay=hTrackPad.AnnotationDisplay;
                    CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
                    m=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1,'first');
                    n=find(~(cellfun(@(x) isempty(x), hTrackPad.Track.Track)),1,'last');
                    fnames=fieldnames(hTrackPad.CellProperties(3).Type);
                    p=hTrackPad.ImageStack.CurrentNdx;
                    if p<=m
                        p=m+1;
                    end
                    if (p<n)
                        for i=p:(n-1)
                            if ~isempty(hTrackPad.Track.Track{i}.Annotation)
                                delete(hTrackPad.Track.Track{i}.AnnotationHandle);
                            end
                            title=EventData.NewValue.Parent.Title;
                            hTrackPad.Track.Track{i}.Annotation.Name=fnames;
                            str=EventData.NewValue.String;
                            ndx=findstr(str,'(');
                            hTrackPad.Track.Track{i}.Annotation.Type.(title)=str(1:ndx-2);
                            hTrackPad.Track.Track{i}.Annotation.Symbol.(title)=str(ndx+1:end-1);
                            
                            Position=hTrackPad.Track.Track{i}.Position;
                            x=Position(1)+Position(3)/2;
                            y=Position(2)+Position(4)/2;
                            hTrackPad.Track.Track{i}.AnnotationHandle=text(x,y,...
                                hTrackPad.Track.Track{i}.Annotation.Symbol.(subsetdisplay),... %disp fluo ann. by default
                                'Color','g','HorizontalAlignment','center','Visible','off',...
                                'PickableParts','none','FontAngle','oblique');
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
            fnames=fieldnames(hTrackPad.CellProperties(3).Type);
            hTrackPad.AnnotationDisplay=fnames{1}; %set fluo annotation as default when loading tracks
            if isa(hTrackPad.Tracks,'TrackCollection')
                
                %reset axes if tracks are loaded when the GUI is zoomed in
                hTrackPad.ImageStack.LastNdx=hTrackPad.ImageStack.CurrentNdx;
                hTrackPad.ImageStack.CurrentNdx=1;
                [r,c,~]=size(hTrackPad.ImageStack.CData);
                x=[1 c]; y=[1 r];
                set(hTrackPad.FigureHandle.CurrentAxes,'XLim',x);
                set(hTrackPad.FigureHandle.CurrentAxes,'YLim',y);
                
                %Track collection already exists .... overwrite
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
                    set(findall(gcf,'Type','text'),'Visible','off'); %turn off all text
                    hTrackPad.ImageStack.CurrentNdx=1; %return to start frame
                    % display text for first frame only
                    for i=1:length(hTrackPad.Tracks.Tracks)
                        Track=hTrackPad.Tracks.Tracks(i).Track.Track;
                        if ~isempty(Track{1})
                            if ~isempty(Track{1}.AnnotationHandle)
                                set(Track{1}.AnnotationHandle,'Color',[0,1,0],'Visible','on','Clipping','on');
                            end
                        end
                    end
                    
                    %update track panel
                    clones=unique(hTrackPad.Tracks.TableData.Ancestor_ID);
                    clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);
                    hTrackPad.TrackPanel.ClonesPopup.String=clones;
                end
            else
                hTrackPad.TrackFile=[PathName,FileName];
                hTrackPad.Tracks=TrackCollection;
                hTrackPad.Tracks.tbl=s.tbl;
                hTrackPad.Tracks.CntrlObj=hTrackPad;
                CreateTracks(hTrackPad.Tracks);
                set(findall(gcf,'Type','text'),'Visible','off'); %turn off all text
                hTrackPad.ImageStack.CurrentNdx=1; %return to start frame
                % display text for first frame only
                for i=1:length(hTrackPad.Tracks.Tracks)
                    Track=hTrackPad.Tracks.Tracks(i).Track.Track;
                    if ~isempty(Track{1})
                        if ~isempty(Track{1}.AnnotationHandle)
                            set(Track{1}.AnnotationHandle,'Color',[0,1,0],'Visible','on','Clipping','on');
                        end
                    end
                end
                
                %update track panel
                clones=unique(hTrackPad.Tracks.TableData.Ancestor_ID);
                clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);
                hTrackPad.TrackPanel.ClonesPopup.String=clones;
            end
        end
        
        function SaveTracks(hObject,EventData,hTrackPad)
            CreateTable(hTrackPad.Tracks);
            [FileName,PathName,FilterIndex] = uiputfile('*.mat');
            tbl=hTrackPad.Tracks.tbl;
            CellProperties=hTrackPad.CellProperties;
            TimeStamps=hTrackPad.ImageStack.AcquisitionTimes;
            ImagePath=hTrackPad.ImageStack.PathName;
            save([PathName,FileName],'tbl','CellProperties','TimeStamps','ImagePath','-v7.3');
        end
        
        function HotKeyFcn(hObject,EventData,hTrackPad)
            switch(EventData.Key)
                case 'c'
                    if strcmp(hTrackPad.ImageContextMenu.ContinueTrack.Visible,'on')
                        hTrackPad.ContinueTrack(hObject,EventData,hTrackPad);
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%
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
                case 'r'
                    if strcmp(hTrackPad.ImageContextMenu.Reposition.Visible,'on')
                        hTrackPad.RepositionEllipse(hObject,EventData,hTrackPad);
                    end
            
            end
        end
        
        function DeleteTrack(hObject,EventData,hTrackPad)
            %deletes track from currentnxd onward
            %deletes the whole track if CurrentNdx==1
            n=hTrackPad.ImageStack.CurrentNdx;
            m=hTrackPad.ImageStack.NumberOfImages;
            if hTrackPad.Tracks.CurrentTrackID>0 && ~hTrackPad.Tracks.Editing
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
                hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                hTrackPad.ImageContextMenu.StartTrack.Visible='on';
                hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                hTrackPad.ImageContextMenu.Reposition.Visible='off';
                hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
                hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
                hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
                if hTrackPad.Tracks.CurrentTrackID>0 % a selected track
                    CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;
                    Remove(hTrackPad.Tracks);
                    hTrackPad.Tracks.CurrentTrack=[];
                    hTrackPad.Tracks.CurrentTrackID=0;
                    
                    xx=cellfun(@(x) isempty(x),{hTrackPad.Tracks.Tracks.ParentID});
                    nextparent=find(xx(CurrentTrackID:end),1)+(CurrentTrackID-1);
                    for i=nextparent:length(hTrackPad.Tracks.Tracks)
                     if ~isempty(hTrackPad.Tracks.Tracks(i).ParentID)
                        hTrackPad.Tracks.Tracks(i).ParentID=hTrackPad.Tracks.Tracks(i).ParentID-1;
                     end
                    end
                    
                    hTrackPad.Tracks.TableData=SubTable(hTrackPad.Tracks); %update tabledata
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
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
            hTrackPad.Track.forward();
        end
        
        function EditTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.FrameSliderHandle.Enable='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
            
            current_track=hTrackPad.Tracks.CurrentTrackID;
            current_ndx=hTrackPad.ImageStack.CurrentNdx;
            range=hTrackPad.Tracks.Tracks(current_track).Track.trackrange;
            hTrackPad.Track=hTrackPad.Tracks.Tracks(current_track).Track;
            hTrackPad.Tracks.Editing=true;
            ImageAxes=get(hTrackPad.ImageHandle,'parent');
            
            for i=1:(range(2)-range(1))+1
            Position=hTrackPad.Tracks.tbl.Position{current_track}(i,:);
            hEllipse=imellipse(hTrackPad.ImageHandle.Parent,Position);
            set(hEllipse,'Visible','off','PickableParts','none');
            setColor(hEllipse,'b');
            setResizable(hEllipse,false);
            hTrackPad.Tracks.Tracks(current_track).Track.Track{i+range(1)-1}.EllipseHandle=hEllipse;
            
            if (i+range(1)-1)==current_ndx
            set(hEllipse,'Visible','on');
            end
            end
            
%             %create an instance of the tracker object
%             hTrackPad.Track=tracker(range,hEllipse,hTrackPad);
%             % set up a listener in tracker for events that occur in TrackPad
%             hTrackPad.Track.CntrlObj=hTrackPad;
%             %create a TrackCollection object if it doesn't already exist
%             if isempty(hTrackPad.Tracks)
%                 hTrackPad.Tracks=TrackCollection(hTrackPad.Track);
%                 %setup a listerner in TrackCollection for events that
%                 %occur in TrackPad
%                 hTrackPad.Tracks.CntrlObj=hTrackPad;
%             else
%                 hTrackPad.Tracks.CurrentTrack=hTrackPad.Track;
%             end
%             hTrackPad.Track.forward();          
            
            hTrackPad.FrameSliderHandle.Enable='on';
            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
            hTrackPad.ImageContextMenu.Reposition.Visible='on';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
            hTrackPad.ImageContextMenu.StopTrack.Visible='on';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
        end
        
                function RepositionEllipse(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.FrameSliderHandle.Enable='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
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
            hTrackPad.ImageContextMenu.Reposition.Visible='on';
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
                    hTrackPad.ImageContextMenu.Reposition.Visible='on';
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
            FigurePosition(3:4)=[400,430];
            fh.Position=FigurePosition;
            Subsets=hTrackPad.CellProperties(3);
            data=cell(20,3);
            rownumb=1;
            annotationsubsets=fieldnames(Subsets.Type);
            for j=1:length(annotationsubsets)-1
                features=Subsets.Type.(annotationsubsets{j});
                for k=1:length(features)
                    data{rownumb,1}=annotationsubsets{j};
                    data{rownumb,2}=Subsets.Type.(annotationsubsets{j}){k};
                    data{rownumb,3}=Subsets.Symbol.(annotationsubsets{j}){k};
                    rownumb=rownumb+1;
                end
            end
            
            %add more rows
            nrows=20-rownumb+1;
            for i=1:nrows
                k=rownumb-1;
                data{i+k,1}='Choose annotation subset';
                data{i+k,2}=[];
                data{i+k,3}=[];
            end
            columnformat=({annotationsubsets' [] []});
            t=uitable(fh,'Data',data,'ColumnWidth',{180 120 50},'ColumnFormat',columnformat,'ColumnEditable',true);
            t.Position=[20,20,400,390];
            get(t,'Position');
            fh.DeleteFcn={@hTrackPad.SaveAnnotationTable,hTrackPad};
        end
        
        function SaveAnnotationTable(hObject,EventData,hTrackPad)
            data=hObject.Children.Data;
            fnames=fieldnames(hTrackPad.CellProperties(3).Type);
            hTrackPad.CellProperties(3).Name='Subsets';
            for i=1:length(fnames)-1 %don't include pedigreeID
                ndx=cellfun(@(x) strcmp(x,fnames{i}),data(:,1));
                hTrackPad.CellProperties(3).Type.(fnames{i})=data(ndx,2);
                hTrackPad.CellProperties(3).Symbol.(fnames{i})=data(ndx,3);
                hTrackPad.CellProperties(3).String.(fnames{i})=cellfun(@(x,y) [x ' (' y ')'],...
                    data(ndx,2),data(ndx,3),'UniformOutput',0);
            end
        end
        
        function EditAnnotationTable(hObject,EventData,hTrackPad)
        end
        
        function setThreshold(Object,EventData,hTrackPad) %currently only works if tracktable exists, i.e. cannot change settings before tracking a cell
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
                    if ~isempty(hTrackPad.Track)
                    hTrackPad.Track.parameters.searchradius=x(1);
                    end
                case 'Nucleus radius'
                    hTrackPad.CurrentTrackingParameters.NucleusRadius=round(x(1));
                    if ~isempty(hTrackPad.Track)
                    hTrackPad.Track.parameters.celldiameter=x(1);
                    end
                case 'Correlation threshold'
                    hTrackPad.CurrentTrackingParameters.CorrelationThreshold=x(1);
                    if ~isempty(hTrackPad.Track)
                    hTrackPad.Track.parameters.confidencethreshold=x(1);
                    end
            end
        end
        
        function getAnnotationInfo(hObject,EventData,TrackID, CellTrackCollection)
            CellTrackCollection.CurrentTrack=CellTrackCollection.Tracks(TrackID).Track; % make selected track editable
            hTrackPad=CellTrackCollection.CntrlObj;
            hTrackPad.Track=CellTrackCollection.CurrentTrack;
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='on'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='on'; %go to end
            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            % make all annotations not selectable
            m=hTrackPad.ImageStack.CurrentNdx;
            n=length(CellTrackCollection.Tracks); %number of tracks
            fnames=fieldnames(hTrackPad.CellProperties(3).Type); %annotation field names
            subsetdisplay=hTrackPad.AnnotationDisplay; %annotation subset
            for i=1:n
                if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})
                    range=hTrackPad.Tracks.Tracks(i).Track.trackrange;
                    if i==TrackID
                        delete(hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle); %delete annotation
                        
                        for j=1:length(hTrackPad.Tracks.Tracks(i).Track.Track)
                            
                            if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{j}) && sum(j==range)==0
                                x=hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,1)+hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,3)/2;
                                y=hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,2)+hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,4)/2;
                                hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle=text(x,y,...
                                    hTrackPad.Tracks.Tracks(i).Track.Track{j}.Annotation.Symbol.(subsetdisplay),...
                                    'HorizontalAlignment','center','PickableParts','all',...
                                    'Clipping','on','FontAngle','oblique','Visible','off','ButtonDownFcn','');
                                
                                set(hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle,'Color',[1,0,0]);
                                if j==m
                                    set(hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle,'Visible','on');
                                end
                                
                            elseif ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{j}) && sum(j==range)==1
                                x=hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,1)+hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,3)/2;
                                y=hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,2)+hTrackPad.Tracks.Tracks(i).Track.Track{j}.Position(1,4)/2;
                                hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle=text(x,y,...
                                    hTrackPad.Tracks.Tracks(i).Track.Track{j}.Annotation.Symbol,...
                                    'HorizontalAlignment','center','PickableParts','all',...
                                    'Clipping','on','FontAngle','oblique','Visible','off','ButtonDownFcn','');
                                
                                set(hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle,'Color',[1,0,0]);
                                
                                if j==m
                                    set(hTrackPad.Tracks.Tracks(i).Track.Track{j}.AnnotationHandle,'Visible','on');
                                end
                                
                                
                            end
                            
                        end
                        
                        CellTrackCollection.CurrentTrackID=TrackID;
                        PedigreeID=hTrackPad.Tracks.TableData.Ancestor_ID(i);
                        ProgenyID=hTrackPad.Tracks.TableData.Progeny_ID(i);
                        displaystring={['Pedigree ' num2str(PedigreeID)] ['Track ' num2str(ProgenyID)]};
                        displaystring=textwrap(hTrackPad.TrackPanel.CurrentTrackDisplay,displaystring);
                        hTrackPad.TrackPanel.CurrentTrackDisplay.String=displaystring;
                        hTrackPad.TrackPanel.CurrentTrackDisplay.ForegroundColor='green';
                    end
                    %                     set(hAnnotation,'ButtonDownFcn',''); % disable callbacks.
                end
            end
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            
            %get track info to reposition axes
            endframe=find(cellfun(@(x) ~isempty(x),...
                hTrackPad.Tracks.Tracks(TrackID).Track.Track),1,'last');
            position=hTrackPad.Tracks.Tracks(TrackID).Track.Track{endframe}.Position;
            x=position(1); y=position(2);
            x=[x-250,x+250]; y=[y-250,y+250];
            if x(1)<1
                x(1)=1;
            elseif x(2)>1392
                x(2)=1392;
            end
            if y(2)<1
                y(1)=1;
            elseif y(2)>1040
                y(2)=1040;
            end
            zoomdata=getappdata(gca, 'matlab_graphics_resetplotview');
            if ~isempty(zoomdata)
                zoomdata.XLim=[0.5000 1.3925e+03];
                zoomdata.YLim=[0.5000 1.0405e+03];
                setappdata(gca, 'matlab_graphics_resetplotview',zoomdata);
            else
                zoom reset
            end
            set(hTrackPad.FigureHandle.CurrentAxes,'XLim',sort(x));
            set(hTrackPad.FigureHandle.CurrentAxes,'YLim',sort(y));
            hTrackPad.Tracks.TableData=SubTable(hTrackPad.Tracks); %update tabledata
            
            %update track panel
            clones=unique(hTrackPad.Tracks.TableData.Ancestor_ID);
            clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);
            hTrackPad.TrackPanel.ClonesPopup.String=clones;
        end
        
        function CloseAnnotationFigure(src,callbackdata,hTrackPad)
            CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;
            CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
            hTrackPad.Tracks.CurrentTrackID;
            n=length(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track);
            for i=1:n
                if ~isempty(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i})
                    if i==CurrentNdx
                        %                     set(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i}.AnnotationHandle,'Color',[0,1,0]);
                        delete(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i}.AnnotationHandle);
                    elseif i~=CurrentNdx
                        delete(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i}.AnnotationHandle);
                        %                     set(hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{i}.AnnotationHandle,'Color',[0,1,0]);
                    end
                end
            end
            hTrackPad.Tracks.CurrentTrackID=0; % reset track or new track selection
            hTrackPad.Tracks.CurrentTrack=[];
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            hTrackPad.ImageContextMenu.StartTrack.Visible='on';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
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
            for i=1:length(hTrackPad.Tracks.Tracks)
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
                        'Color','g','HorizontalAlignment','center',...
                        'PickableParts','none','FontAngle','oblique');
                    
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
                        'Color','g','HorizontalAlignment','center','Visible',...
                        'off','PickableParts','none','FontAngle','oblique'); % DA
                    hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                    set(hAnnotation,'PickableParts','none');
                    set(hAnnotation,'ButtonDownFcn',[]);
                end
            end
        end
        
        
        function openTrackTable(Object,EventData,hTrackPad)
            hTrackPad.TrackTable=TrackTable;
            hTrackPad.TrackTable.CntrlObj=hTrackPad;
            hTrackPad.TrackTable.TableData=hTrackPad.Tracks.TableData;
            %             hTrackPad.TrackTable.Tracks=SubTable(hTrackPad.TrackTable);
            CreateTrackTable(hTrackPad.TrackTable);
        end
        
        
        function ChangeAnnotationDisplay(Object,EventData,hTrackPad)
            annotationdisplayhandle=findall(gcf,'Tag','Change annotation display');
            for i=1:length(annotationdisplayhandle)
                if strcmp(EventData.Source.Label,annotationdisplayhandle(i).Label)
                    annotationdisplayhandle(i).Checked='on';
                    hTrackPad.AnnotationDisplay=annotationdisplayhandle(i).Label;
                else
                    annotationdisplayhandle(i).Checked='off';
                end
            end
        end
        
        function ChooseTrack(Object,EventData,hTrackPad)
            value=EventData.Source.Value;
            progenyid=sscanf(EventData.Source.String{value},'Track %d');
            lineageid=sscanf(hTrackPad.TrackPanel.ClonesPopup.String{hTrackPad.TrackPanel.ClonesPopup.Value},'Pedigree %d');
            trackid=find((hTrackPad.Tracks.TableData.Ancestor_ID==lineageid &...
                hTrackPad.Tracks.TableData.Progeny_ID==progenyid));
            hTrackPad.Tracks.CurrentTrackID=trackid;
            displaystring={['Pedigree ' num2str(lineageid)] ['Track ' num2str(progenyid)]};
            displaystring=textwrap(hTrackPad.TrackPanel.CurrentTrackDisplay,displaystring);
            hTrackPad.TrackPanel.CurrentTrackDisplay.String=displaystring;
            go2endhandle=findall(hTrackPad.FigureHandle,'TooltipString','Go to end of track');
            go2endcallback=get(go2endhandle,'ClickedCallback');
            go2endcallback{1}(go2endhandle,[],hTrackPad);
        end
        
        function ChooseClone(Object,EventData,hTrackPad)
            value=EventData.Source.Value;
            cloneid=sscanf(EventData.Source.String{value},'Pedigree %d');
            ndx=hTrackPad.Tracks.TableData.Ancestor_ID==cloneid;
            progenyid=sort(hTrackPad.Tracks.TableData.Progeny_ID(ndx));
            progenyid=arrayfun(@(x) ['Track ' num2str(x)],progenyid,'UniformOutput',0);
            hTrackPad.TrackPanel.TracksPopup.String=progenyid;
            hTrackPad.TrackPanel.TracksPopup.Value=1;
        end
        
        function getCursorPosition(hObject, EventData, hTrackPad)
            cursorposition=get(hTrackPad.FigureHandle.CurrentAxes,'CurrentPoint');
            hTrackPad.CursorPositionBox.Units='Normalized';
            x=round(cursorposition(1,1)); y=round(cursorposition(1,2));
            if x >0 && x<1392 && y>0 && y<1040
                x=sprintf('%04d',x); y=sprintf('%04d',y);
                hTrackPad.CursorPositionBox.String=(['X: ' num2str(x) '  Y: ' num2str(y)]);
                hTrackPad.CursorPositionBox.Position(1)=1-hTrackPad.CursorPositionBox.Extent(3)*1.1;
                hTrackPad.CursorPositionBox.Position(3)=hTrackPad.CursorPositionBox.Extent(3)*1.1;
            elseif (x <0 || x>1392) || (y<0 && y>1040)
                hTrackPad.CursorPositionBox.String=('X: ----  Y: -----');
                hTrackPad.CursorPositionBox.Position(1)=1-hTrackPad.CursorPositionBox.Extent(3)*1.05;
                hTrackPad.CursorPositionBox.Position(3)=hTrackPad.CursorPositionBox.Extent(3);
            end
        end
        
    end
    
    
end



