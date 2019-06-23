classdef TrackPad < handle
    % User interface for tracking cells
    
    properties
        FigureHandle
        AnnotationFigureHandle=[];
        AnnotationDisplayMenuHandle
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
        TrackNavigator
        TrackPanel
        TrackFile
        TrackPath
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
                        display(['Loading ' FileName]);
                        s=load([PathName FileName]);
                        StackData=fieldnames(s);
                        if isa(s.(StackData{1}),'ImageStack')
                            obj.ImageStack=s.(StackData{1});
                        else
                            error('Not an ImageStack object');
                        end
                    case 'No'
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
            
            matlab_version=version('-release'); %matlab toolbar changed starting from 2018b - no zoom in fig toolbar
            year=str2num(matlab_version(1:4)); 
            if year==2018
                if strcmp(char(matlab_version(end)),'b')
                    addToolbarExplorationButtons(gcf);
                    obj.ToolBarHandle=findall(gcf,'tag','FigureToolBar');
                    toolbarhandle=allchild(obj.ToolBarHandle);
                    delete(toolbarhandle(1:end-2));                  
                end
            elseif year>2018
                 addToolbarExplorationButtons(gcf);
                 addToolbarExplorationButtons(gcf);
                 obj.ToolBarHandle=findall(gcf,'tag','FigureToolBar');
                 toolbarhandle=allchild(obj.ToolBarHandle);
                 delete(toolbarhandle(1:end-2));                 
            end
            
            %%add other user defined toolbar features
            
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
            
            %change callback for zoom function
%             x=findall(obj.ToolBarHandle,'tag','Exploration.ZoomIn');
%             set(x,'ClickedCallback',{@obj.ZoomIn,obj});
            
            %modify toolbar appearance by accessing java components
            drawnow;
            %             ModifyFigureToolBar(obj);
            
            %initialise dropdown menus
            FileMenuHandle = uimenu(obj.FigureHandle,'Label','File');
            uimenu(FileMenuHandle,'Label','Open Tracks',...
                'Callback',{@obj.OpenTracks,obj});
            uimenu(FileMenuHandle,'Label','Save Tracks',...
                'Callback',{@obj.SaveTracks,obj});
            uimenu(FileMenuHandle,'Label','Quit',...
                'Callback',{@obj.CloseTrackPad,obj});
            ParametersMenuHandle=uimenu(obj.FigureHandle,'Label','Parameters');
            uimenu(ParametersMenuHandle,'Label','Search radius',...
                'Callback',{@obj.setThreshold,obj});
            uimenu(ParametersMenuHandle,'Label','Nucleus radius',...
                'Callback',{@obj.setThreshold,obj});
            uimenu(ParametersMenuHandle,'Label','Correlation threshold',...
                'Callback',{@obj.setThreshold,obj});
            TrackTableMenuHandle=uimenu(obj.FigureHandle,'Label','Pedigree Navigator');
            uimenu(TrackTableMenuHandle,'Label','Open track table and pedigree display',...
                'Callback',{@obj.openTrackTable,obj});
            
            % create slider to control frame
            obj.FigureHandle.Units='Normalized';
            pos=obj.FigureHandle.Position;
            N=obj.ImageStack.NumberOfImages;
            
            %frame slider
            obj.FrameSliderHandle=uicontrol(obj.FigureHandle,'Style','slider',...
                'Value',1,'Tag','FrameSlider','Min',1,'Max',N,'TooltipString','Use the mouse wheel to move slider',...
            'SliderStep',[1/(N-1) 10/(N-1)]);
            
%             obj.FrameSliderHandle.Tooltip='Also can use the mouse wheel to move slider';
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
%             Hjava = findjobj(obj.TrackPanel.CurrentTrackDisplay); %stackexchange function
%             Hjava.setVerticalAlignment(javax.swing.JLabel.CENTER);
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
            obj.ImageContextMenu.StopEditTrack=uimenu(c,'Label','Stop editing','Tag','StopEditTrack',...
                'Visible','off','Callback',{@obj.StopEditTrack,obj});            
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
            
            %optional (default) cell properties (subsets), can be edited
            obj.CellProperties(3).Name='Features';
            obj.CellProperties(3).Type.GFP={'No annotation','GFP positive','GFP negative'};
            obj.CellProperties(3).Symbol.GFP={'NA','G+','G-'};
            obj.CellProperties(3).String.GFP={'No annotation (NA)','GFP positive (G+)','GFP negative (G-)'};
            obj.CellProperties(3).Type.Adhesion={'No annotation','Adherent','Semi-adherent','Detatched'};
            obj.CellProperties(3).Symbol.Adhesion={'NA','AD','SA','DE'};
            obj.CellProperties(3).String.Adhesion={'No annotation (NA)','Adherent (AD)','Semi-adherent (SA)','Detatched (DE)'};
            


            obj.CellProperties(3).Type.PedigreeID={'No annotation'};
            obj.CellProperties(3).Symbol.PedigreeID={'NA'};
            obj.CellProperties(3).String.PedigreeID={'No annotation (NA)'};
            obj.CurrentTrackingParameters.NucleusRadius=35;
            obj.CurrentTrackingParameters.SearchRadius=10;
            obj.CurrentTrackingParameters.CorrelationThreshold=0.6;
            obj.FigureHandle.CloseRequestFcn={@obj.CloseTrackPad,obj};
            
            %add annotation table menu
            AnnotateMenuHandle = uimenu(obj.FigureHandle,'Label','Annotations');
            uimenu(AnnotateMenuHandle,'Label','Edit features',...
                'Callback',{@obj.setFeatures,obj});
            uimenu(AnnotateMenuHandle,'Label','Edit types',...
                'Callback',{@obj.OpenAnnotationTable,obj});
            
            %add annotation display menu
            obj.AnnotationDisplayMenuHandle = uimenu(obj.FigureHandle,'Label','Display annotations');
            fnames=fieldnames(obj.CellProperties(3).Type);
            for i=1:length(fnames)
                uimenu(obj.AnnotationDisplayMenuHandle,'Label',fnames{i},...
                    'Callback',{@obj.ChangeAnnotationDisplay,obj},'Tag','Change annotation display');
            end

            uimenu(obj.AnnotationDisplayMenuHandle,'Label','None',...
                'Checked','off','Callback',{@obj.ChangeAnnotationDisplay,obj},'Tag','Change annotation display');
            ndx=contains({obj.AnnotationDisplayMenuHandle.Children.Label},'PedigreeID');
            obj.AnnotationDisplayMenuHandle.Children(ndx).Checked='on';

            
            obj.AnnotationDisplay='PedigreeID'; %set PedigreeID on
            
            %add optimisation menu
            OptimiseMenuHandle = uimenu(obj.FigureHandle,'Label','Optimise');
            uimenu(OptimiseMenuHandle,'Label','Run avatar optimisation',...
                'Callback',{@obj.AvatarOptimisation,obj});

            
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
              obj.Track.LostCellListener=event.listener(value,'LostCellEvent',@obj.listenLostCellEvent); %lost cell event is generated by tracker and listened to by trackpad
              obj.Track.EndTrackListener=event.listener(value,'EndOfTrackEvent',@obj.listenEndOfTrackEvent); %endtrack event is generated by tracker and listened to by trackpad
            end
        end
%         function set.Tracks(obj,value)
%             obj.Tracks=value;
%             addlistener(value,'AppendedTrackEvent',@obj.listenAppendedTrackEvent);
%         end
        function listenLostCellEvent(obj,src,evnt)
            % obj - instance of this class
            % src - object generating event
            %  evnt - the event data
            if ~isempty(obj.Track.Track{obj.ImageStack.CurrentNdx})% only show menu if there is an ellipse
                obj.ImageContextMenu.EditTrack.Visible='off';
                obj.ImageContextMenu.StopEditTrack.Visible='off';
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
            obj.ImageContextMenu.EditTrack.Visible='off';
            obj.ImageContextMenu.StopEditTrack.Visible='off';
            obj.ImageContextMenu.Reposition.Visible='on';
            obj.ImageContextMenu.DeleteTrack.Visible='on';
            disp('End of Track Event');
        end
%         function listenAppendedTrackEvent(obj,src,~)
%             obj.ImageContextMenu.StartTrack.Visible='on';
%         end
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
%             Hjava = findjobj(hTrackPad.TrackPanel.CurrentTrackDisplay); %stackexchange function
%             Hjava.setVerticalAlignment(javax.swing.JLabel.CENTER);
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
        
        function ZoomIn(hObject,EventData,hTrackPad)
           
%           disp('here');
            zoom(hTrackPad.FigureHandle);
            
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
                        
                        condition1=hTrackPad.ImageStack.CurrentNdx>=trackrange(1) && hTrackPad.ImageStack.CurrentNdx<=trackrange(2); %between first and last frame
                        condition2=hTrackPad.ImageStack.LastNdx>=trackrange(1) && hTrackPad.ImageStack.LastNdx<=trackrange(2); %not first frame 
                        
%                         if (hTrackPad.Tracks.CurrentTrackID==0) || hTrackPad.Tracks.Editing % in track or edit mode
                        if (hTrackPad.Tracks.CurrentTrackID==0) 
                            hTrackPad.Track.CurrentEllipse=hTrackPad.Track.Track{n}.EllipseHandle;
                            if condition1 && condition2
                                set(hTrackPad.Track.Track{hTrackPad.ImageStack.LastNdx}.EllipseHandle,'Visible','off');
                                set(hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.EllipseHandle,'Visible','on'); %new conditions req'd for editing tracks
                            elseif condition1 && ~condition2
                                set(hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.EllipseHandle,'Visible','on');
                            end
                            
                            %turn on context menus
%                             if trackrange(2)==hTrackPad.ImageStack.CurrentNdx
%                             hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
%                             else
%                             hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
%                             end
                            

%                             if hTrackPad.Track.Editing
%                                % hTrackPad.ImageContextMenu.StopTrack.Visible='off';
%                                 hTrackPad.ImageContextMenu.StopTrack.Visible='on';
%                                 hTrackPad.ImageContextMenu.StopEditTrack.Visible='on';
%                                 hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
%                                 hTrackPad.ImageContextMenu.EditTrack.Visible='off'; 
%                             elseif ~hTrackPad.Track.Editing
%                                 hTrackPad.ImageContextMenu.StopTrack.Visible='on';
%                                 hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';   
%                                 hTrackPad.ImageContextMenu.EditTrack.Visible='off'; 
%                             end % does not have editing mode anymore!
%                             


                            hTrackPad.ImageContextMenu.Reposition.Visible='on';
                        else
                            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
                            hTrackPad.ImageContextMenu.EditTrack.Visible='on';
                        end
                        
                        hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
                        if isvalid(hTrackPad.Track.CurrentEllipse)
                            set(hTrackPad.Track.CurrentEllipse,'Visible','on');
                        end
                    elseif isempty(hTrackPad.Track.Track{n}) % don't show context menu if the is no ellipse
%                         if (hTrackPad.Tracks.CurrentTrackID==0) || hTrackPad.Tracks.Editing
%                             set(hTrackPad.Track.CurrentEllipse,'Visible','off');
%                          % editing mode discontinued
%                         end
                        if (hTrackPad.Tracks.CurrentTrackID==0)
                            set(hTrackPad.Track.CurrentEllipse,'Visible','off');
                        end
                        hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                        hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
                        hTrackPad.ImageContextMenu.Reposition.Visible='off';
                        hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
                        hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                        hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
                        hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
                    end
                else
                    hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                    hTrackPad.ImageContextMenu.Reposition.Visible='off';
                    hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
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
        
        function DisplayAnnotation(~,~,hTrackPad)
            %figure(hTrackPad.FigureHandle);
            n=hTrackPad.ImageStack.CurrentNdx;
            last=hTrackPad.ImageStack.LastNdx;
            fnames=fieldnames(hTrackPad.CellProperties(3).Type);
            subsetdisplay=hTrackPad.AnnotationDisplay;
            if (n~=last)
              %switch off last annotations
              annotation_handles=findobj(gcf,'Type','Text');
              delete(annotation_handles);
              % update Stored Tracks
              m=length(hTrackPad.Tracks.Tracks);
                for i=1:m
%                     disp(num2str(i));
                    Track=hTrackPad.Tracks.Tracks(i).Track.Track;
%                     firstframe=find(cellfun(@(x) ~isempty(x),Track),1,'first');
%                     lastframe=find(cellfun(@(x) ~isempty(x),Track),1,'last');
                    range=hTrackPad.Tracks.Tracks(i).Track.trackrange;
                    if ~isempty(Track{n}) && sum(n~=range)==2 &&  ~strcmp(hTrackPad.AnnotationDisplay,'None') %update annotations for all but first frame
                        if isempty(Track{n}.AnnotationHandle)
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            if ~isempty(Track{n}.Annotation)
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol.(subsetdisplay),...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique');
                            if i~=hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                            end
                        else
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            if ~isempty(Track{n}.Annotation)
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol.(subsetdisplay),...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique','Visible','on');
                            %Track{n}.AnnotationHandle.String=Track{n}.Annotation.Symbol.(subsetdisplay);
                            if i~=hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                            end
                        end
                    elseif ~isempty(Track{n}) &&(n==range(1)|| n==range(2))&&  ~strcmp(hTrackPad.AnnotationDisplay,'None')%update annotations for first frame
                        if isempty(Track{n}.AnnotationHandle)
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            if ~isempty(Track{n}.Annotation)
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique');
                            if i~=hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
                            end
                        else
                            x=Track{n}.Position(1,1)+Track{n}.Position(1,3)/2;
                            y=Track{n}.Position(1,2)+Track{n}.Position(1,4)/2;
                            if ~isempty(Track{n}.Annotation)
                            Track{n}.AnnotationHandle=text(x,y,...
                                Track{n}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique');
                            set(Track{n}.AnnotationHandle,'Visible','on','Clipping','on');
                            if i~=hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[0,1,0]);
                            elseif i==hTrackPad.Tracks.CurrentTrackID
                                set(Track{n}.AnnotationHandle,'Color',[1,0,0]);
                            end
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
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            %append track to TrackCollection object
            if (hTrackPad.Tracks.CurrentTrackID==0)&&(hTrackPad.Tracks.EditedTrackID==0) % not editing track, need to append to trackcollection
                hTrackPad.Tracks.Append;
                hTrackPad.ImageContextMenu.StartTrack.Visible='on';

                hTrackPad.Track=[];% no longer can be edited
                hellipse=findall(gca,'Tag','imellipse');%remove ellipse
                delete(hellipse);
%                 hTrackPad.Tracks=
                %delete listeners
                
            elseif hTrackPad.Tracks.EditedTrackID>0 % need to replace with edited track
%                 if hTrackPad.Track.Editing
             % selected existing track for editing
%                 hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track=hTrackPad.Track;
                delete(hTrackPad.Track.PauseListenerHandle);
                delete(hTrackPad.Track.StopListenerHandle);
                delete(hTrackPad.Track.LostCellListener);
                delete(hTrackPad.Track.EndTrackListener);
                hTrackPad.Tracks.Replace;         
                hTrackPad.Track=[];% no longer can be edited
                hTrackPad.Tracks.EditedTrackID=0; % get out of edit mode
                hTrackPad.Tracks.CurrentTrackID=0; % ready to track a new track
                hellipse=findall(gca,'Tag','imellipse');%remove ellipse
                delete(hellipse);     

%                 i=hTrackPad.Tracks.CurrentTrackID;
%                 for j=1:length(hTrackPad.Tracks.Tracks(i).Track.Track)
%                     if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{j})
%                         setColor(hTrackPad.Tracks.Tracks(i).Track.Track{j}.EllipseHandle,'b')
%                     end
%                 end
%                 hTrackPad.Tracks.Editing=false; % Editing mode
%                 discontinued
                hTrackPad.Tracks.CurrentTrackID=0;% reset to new track mode
                hTrackPad.Tracks.EditedTrackID=0; % get out of edit mode.
                hTrackPad.ImageContextMenu.StartTrack.Visible='on';
            end
        end
        
        function SelectTrack(hObject,EventData,hTrackPad)
            if ~isempty(hTrackPad.Tracks)
            % make all tracks selectable in current frame
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='off';
            hTrackPad.ImageContextMenu.StartTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
            hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
                                 
            if strcmp(hTrackPad.AnnotationDisplay,'None')
%                 annotation_handles=findobj(gcf,'Type','Text');
%                 delete(annotation_handles);
                hTrackPad.AnnotationDisplay='PedigreeID'; %turn on pedigree annotations
            end
            
                n=length(hTrackPad.Tracks.Tracks);
                m=hTrackPad.ImageStack.CurrentNdx; % make all tracks in current frame selectable
                for i=1:n
                    if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})  
                        x=hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,1)+hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,3)/2;
                        y=hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,2)+hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,4)/2;
                        if (m==hTrackPad.Tracks.Tracks(i).Track.trackrange(1)|| m==hTrackPad.Tracks.Tracks(i).Track.trackrange(2))
                            hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle=text(x,y,...
                                hTrackPad.Tracks.Tracks(i).Track.Track{m}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','all',...
                                'Clipping','on','FontAngle','oblique','Visible','On','Color','g');
                        elseif sum(m~=hTrackPad.Tracks.Tracks(i).Track.trackrange)==2
                            hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle=text(x,y,...
                                hTrackPad.Tracks.Tracks(i).Track.Track{m}.Annotation.Symbol.(hTrackPad.AnnotationDisplay),...
                                'HorizontalAlignment','center','PickableParts','all',...
                                'Clipping','on','FontAngle','oblique','Visible','On','Color','g');
                        end
                        hAnnotation=hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle;
                        %                     set(hAnnotation,'PickableParts','all','Visible','On');
                        set(hAnnotation,'ButtonDownFcn',{@hTrackPad.getAnnotationInfo,...
                            i,hTrackPad.Tracks});
                    end
                end      
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            elseif isempty(hTrackPad.Tracks)
                errordlg('No tracks loaded');
            end
        end
        
        %cancels track selection
        function Cancel(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
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
            
%             if hTrackPad.Tracks.Editing
%                 hTrackPad.Tracks.Editing=false;
%                 delete(findobj(gcf,'Tag','imellipse'));
%             end % editing mode discontinued
            
            hTrackPad.Tracks.CurrentTrackID=0;
            hTrackPad.Tracks.CurrentTrack=[];
%             hTrackPad.Tracks.Editing=false; % editing mode discontinued
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
            if ~isempty(hTrackPad.Track)
                hTrackPad.ImageContextMenu.Reposition.Visible='off';
                hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';

                hTrackPad.ImageContextMenu.SelectTrack.Visible='off';

                hTrackPad.ImageContextMenu.StartTrack.Visible='off';
                hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
                hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
                hTrackPad.ImageContextMenu.ReturnToStart.Visible='off';
                hTrackPad.ImageContextMenu.GoToEnd.Visible='on';


                if hTrackPad.Tracks.EditedTrackID>0
                    hTrackPad.ImageContextMenu.EditTrack.Visible='off';
%                     hTrackPad.ImageContextMenu.StopEditTrack.Visible='on';
                else
                    hTrackPad.ImageContextMenu.EditTrack.Visible='on';
%                     hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';                

               
                end

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
                elseif x(2)>size(hTrackPad.ImageHandle.CData,2)
                    x(2)=size(hTrackPad.ImageHandle.CData,2);
                end
                if y(2)<1
                    y(1)=1;
                elseif y(2)>size(hTrackPad.ImageHandle.CData,1)
                    y(2)=size(hTrackPad.ImageHandle.CData,1);
                end
                zoomdata=getappdata(gca, 'matlab_graphics_resetplotview');
                if ~isempty(zoomdata)
                    zoomdata.XLim=[0.5000 size(hTrackPad.ImageHandle.CData,2)];
                    zoomdata.YLim=[0.5000 size(hTrackPad.ImageHandle.CData,2)];
                    setappdata(gca, 'matlab_graphics_resetplotview',zoomdata);
                else
                    zoom reset
                end
                set(hTrackPad.FigureHandle.CurrentAxes,'XLim',sort(x));
                set(hTrackPad.FigureHandle.CurrentAxes,'YLim',sort(y));
                hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            end
        end
        
        %goes to the end of a cell's track
        function GoToEnd(hObject,EventData,hTrackPad)
            %set context menus
            if ~isempty(hTrackPad.Track)
                hTrackPad.ImageContextMenu.EditTrack.Visible='off';
                hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
                hTrackPad.ImageContextMenu.Reposition.Visible='off';
                hTrackPad.ImageContextMenu.StopTrack.Visible='off';
                hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';

                hTrackPad.ImageContextMenu.SelectTrack.Visible='off';

                hTrackPad.ImageContextMenu.StartTrack.Visible='off';
                hTrackPad.ImageContextMenu.AnnotateTrack.Visible='on';
                hTrackPad.ImageContextMenu.Cancel.Visible='off';
                hTrackPad.ImageContextMenu.ReturnToStart.Visible='on';
                hTrackPad.ImageContextMenu.GoToEnd.Visible='off';

                if hTrackPad.Tracks.EditedTrackID>0
                    hTrackPad.ImageContextMenu.EditTrack.Visible='off';
%                     hTrackPad.ImageContextMenu.StopEditTrack.Visible='on';
                else
                    hTrackPad.ImageContextMenu.EditTrack.Visible='on';
%                     hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';                

                end

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
                elseif x(2)>size(hTrackPad.ImageHandle.CData,2)
                    x(2)=size(hTrackPad.ImageHandle.CData,2);
                end
                if y(2)<1
                    y(1)=1;
                elseif y(2)>size(hTrackPad.ImageHandle.CData,1)
                    y(2)=size(hTrackPad.ImageHandle.CData,1);
                end
                zoomdata=getappdata(gca, 'matlab_graphics_resetplotview');
                if ~isempty(zoomdata)
                    zoomdata.XLim=[0.5000 size(hTrackPad.ImageHandle.CData,2)];
                    zoomdata.YLim=[0.5000 size(hTrackPad.ImageHandle.CData,1)];
                    setappdata(gca, 'matlab_graphics_resetplotview',zoomdata);
                else
                    zoom reset
                end
                set(hTrackPad.FigureHandle.CurrentAxes,'XLim',sort(x));
                set(hTrackPad.FigureHandle.CurrentAxes,'YLim',sort(y));
                hTrackPad.ImageContextMenu.Cancel.Visible='on'; %cancel
            end            
        end
        

function AnnotateTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='off';
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off';
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off';
            hfig=figure('Name','Annotate track','ToolBar','none',...
                 'MenuBar','none','NumberTitle','off','WindowStyle','modal','Units','normalized');
%             hfig=figure('Name','Annotate track','ToolBar','none',...
%                 'MenuBar','none','NumberTitle','off','Units','normalized'); %without modal set
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
            
            hfig.Position(1)=0.6;
            hfig.Position(2)=0.15;
            hfig.Position(3)=0.2;
            hfig.Position(4)=0.3;
%             hfig.Resize='Off';
            
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
                BGHeight=(length(CellProperties(i).Type)+1)*0.075;
                h=h-BGHeight;
                handles.(str).BG=uibuttongroup(hfig,'Visible','on','Units','normalized');
                handles.(str).BG.Position=[0.1,(1-i*0.25),0.8,BGHeight];
                set(handles.(str).BG,'SelectionChangedFcn',{@hTrackPad.AnnotationHandler,hTrackPad});
                
                handles.(str).BG.Title=CellProperties(i).Name;
                n=length(CellProperties(i).Type);
                % create radio buttons
                
                for j=1:n
                    handles.(str).RB(j)=uicontrol(handles.(str).BG,'Style',...
                        'radiobutton',...
                        'String',CellProperties(i).String{j},...
                       'HandleVisibility','off','Units','normalized');
                   handles.(str).RB(j).Position=[0.05,(1-j*(0.9/n)),1,0.2];
                end
                
            end
            
            handles.Origin.BG.Position(2)=0.975-handles.Origin.BG.Position(4); %adjust position
            handles.Fate.BG.Position(2)=handles.Origin.BG.Position(2)-handles.Fate.BG.Position(4); %adjust position

            %add buttons for annotation subsets
            subsets=CellProperties(3);
            str='Subsets';
            fnames=fieldnames(subsets.Type);
            numb_subsets=length(fnames)-1; %don't add pedigreeID to annotation table, i.e. exclude last subset
            
            CellPropertyText=uicontrol('Parent',hfig,'Style','text','String',...
                'Cell properties','units','normalized',...
                'Position',[handles.Fate.BG.Position(1),handles.Fate.BG.Position(2)-0.06,0.27,0.06]);
            Data = cell(1,length(fnames)-1);
            Data=cellfun(@(x) '',Data,'Uniform',false);
            
            t = uitable('Parent', hfig,'ColumnEditable', true,'Data', Data,'ColumnName',{fnames{1:end-1}},'RowName',[],...
            'CellEditCallback',{@hTrackPad.AnnotationHandler,hTrackPad},'units','normalized');
            for i=1:(length(fnames)-1)
                ColumnFormat{i}=subsets.String.(fnames{i});
            end
            t.ColumnFormat=ColumnFormat;
            % work out table position
           
            t.Position=[handles.Fate.BG.Position(1), ...
                handles.Fate.BG.Position(2)-handles.Fate.BG.Position(4)*0.8-0.05,...
                handles.Fate.BG.Position(3),handles.Fate.BG.Position(4)*0.8];
            
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
                                s=[hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation.Type.(fnames{ii})...
                                    ' (' hTrackPad.Tracks.Tracks(CurrentTrackID).Track.Track{CurrentNdx}.Annotation.Symbol.(fnames{ii}) ')'];
                                if sum(strcmp(t.ColumnFormat{ii},s))==1
                                        t.Data{ii}=s;
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
            
            switch (class(hObject))
                
                case 'matlab.ui.container.ButtonGroup'
                    
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
                    end
                case ('matlab.ui.control.Table')
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
                            title=EventData.Source.ColumnName(EventData.Indices(2));
                            hTrackPad.Track.Track{i}.Annotation.Name=fnames;
                            str=EventData.NewData;
                            ndx=findstr(str,'(');
                            hTrackPad.Track.Track{i}.Annotation.Type.(title{:})=str(1:ndx-2); %e.g. Type = 'red'
                            hTrackPad.Track.Track{i}.Annotation.Symbol.(title{:})=str(ndx+1:end-1); %e.g. Symbol = 'S1', String = 'red (S1)'
                            
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
            display('Loading tracks ... ');
            s=load([PathName,FileName]);            
            hTrackPad.CellProperties=s.CellProperties;
            hTrackPad.CellProperties(3).String=structfun(@(x) reshape(x',[1 length(x)]),hTrackPad.CellProperties(3).String,'UniformOutput',0); %force to be row vectors for compatability between versions
            fnames=fieldnames(hTrackPad.CellProperties(3).Type);
            hTrackPad.AnnotationDisplay='PedigreeID'; %set pedigree annotation as default when loading tracks
            hTrackPad.TrackFile=FileName;
            hTrackPad.TrackPath=PathName;
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
                    tic;
                    if ~isempty(hTrackPad.TrackNavigator)
                        if isvalid(hTrackPad.TrackNavigator.TableFigureHandle)
                            close(hTrackPad.TrackNavigator.TableFigureHandle); % close TrackNavigator if necessary
                        end
                    end
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
                            x=Track{1}.Position(1,1)+Track{1}.Position(1,3)/2;
                            y=Track{1}.Position(1,2)+Track{1}.Position(1,4)/2;
                            Track{1}.AnnotationHandle=text(x,y,...
                                Track{1}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique','Visible','on','Color','g');
                        end
                    end
                    
                    %update track panel
                    clones=unique([hTrackPad.Tracks.TableData.Ancestor_ID{:}]);
                    clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);
                    hTrackPad.TrackPanel.ClonesPopup.String=clones;

                    hTrackPad.TrackPanel.ClonesPopup.Value=1;
                    ndx=[hTrackPad.Tracks.TableData.Ancestor_ID{:}]==1;
                    progenyid=sort([hTrackPad.Tracks.TableData.Progeny_ID{ndx}]);
                    progenyid=arrayfun(@(x) ['Track ' num2str(x)],progenyid,'UniformOutput',0);
                    hTrackPad.TrackPanel.TracksPopup.String=progenyid;
                    hTrackPad.TrackPanel.TracksPopup.Value=1;
%                     v.Source=hTrackPad.TrackPanel.TracksPopup;
%                     hTrackPad.ChooseTrack(hTrackPad,v,hTrackPad);

                    if isempty(hTrackPad.TrackNavigator)
                        hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                    elseif ~isvalid(hTrackPad.TrackNavigator.TableFigureHandle)
                        hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                    else 
                        close(hTrackPad.TrackNavigator.TableFigureHandle); % don't duplicate figures;
                        hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks); %already deleted 
                    end
                  if isfield(s,'clone')
                      hTrackPad.TrackNavigator.PedigreeData=s.clone;
                  end
                    
                end
            else
                tic;
                hTrackPad.TrackFile=FileName;
                hTrackPad.TrackPath=PathName;
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
               
                clones=unique([hTrackPad.Tracks.TableData.Ancestor_ID{:}]);
                clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);

                hTrackPad.TrackPanel.ClonesPopup.Value=1;
                ndx=[hTrackPad.Tracks.TableData.Ancestor_ID{:}]==1;
                progenyid=sort([hTrackPad.Tracks.TableData.Progeny_ID{ndx}]);
                progenyid=arrayfun(@(x) ['Track ' num2str(x)],progenyid,'UniformOutput',0);
                hTrackPad.TrackPanel.TracksPopup.String=progenyid;
                hTrackPad.TrackPanel.TracksPopup.Value=1;
%                 v.Source=hTrackPad.TrackPanel.TracksPopup;
%                 hTrackPad.ChooseTrack(hTrackPad,v,hTrackPad);

                hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                close(hTrackPad.TrackNavigator.TableFigureHandle);
            end
            % create a TrackAnnotation object
            % rewrite submenus for TrackAnnotation
            handles=guihandles(hTrackPad.FigureHandle);
            submenus=get(hTrackPad.AnnotationDisplayMenuHandle,'Children');
            for i=1:length(submenus)
                delete(submenus(i));
            end
            for i=1:length(fnames)-1
                uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label',fnames{i},...
                    'Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},'Tag','Change annotation display');
            end
            uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label','PedigreeID',...
                'Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},...
                'Tag','Change annotation display');
            uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label','None',...
                'Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},...

            % manually change Display annotations to PedigreeID
            MenuLabels={hTrackPad.AnnotationDisplayMenuHandle.Children.Text};
            Checked={hTrackPad.AnnotationDisplayMenuHandle.Children.Checked};
            ndx=contains(Checked,'on');
            hTrackPad.AnnotationDisplayMenuHandle.Children(ndx).Checked='off';
            ndx=contains(MenuLabels,'PedigreeID');
            hTrackPad.AnnotationDisplayMenuHandle.Children(ndx).Checked='on';
            v=[];
            v.Source=hTrackPad.AnnotationDisplayMenuHandle.Children(ndx);
            hTrackPad.ChangeAnnotationDisplay(hTrackPad,v,hTrackPad);

            guidata(hTrackPad.FigureHandle,handles);
            toc;
        end
        
        function SaveTracks(hObject,EventData,hTrackPad)
            if ~isempty(hTrackPad.Tracks)
                CreateTable(hTrackPad.Tracks);
                [FileName,PathName,FilterIndex] = uiputfile('*.mat','Save tracks file');
    %             if ~strfind(FileName,'trackfile.mat')
    %             FileName=strrep(FileName,'.mat',' trackfile.mat'); %add trackfile suffix
    %             elseif strfind(FileName,'trackfile.mat') 
    %                 
    %             end
                tbl=hTrackPad.Tracks.tbl;
                CellProperties=hTrackPad.CellProperties;
                TimeStamps=hTrackPad.ImageStack.AcquisitionTimes;
                ImagePath=hTrackPad.ImageStack.PathName;

                %prepare clone file
                clone=CreateCloneFiles(hTrackPad.Tracks);
    %             hTrackPad.TrackTable=TrackTable;
    %             hTrackPad.TrackTable.CntrlObj=hTrackPad;
    %             hTrackPad.TableNavigator.TableData=SubTable(hTrackPad.Tracks);
    %             hTrackPad.TrackTable.PedigreeData=CreateCloneFiles(hTrackPad.TrackTable,hTrackPad.Tracks.tbl,...
    %                 hTrackPad.ImageStack.AcquisitionTimes);
    %             clone=hTrackPad.TrackTable.PedigreeData;


                h=waitbar(1,['Please wait for ' FileName ' to save.']); 
    %             save([PathName,FileName],'tbl','CellProperties','TimeStamps','ImagePath','clone','-v7.3');
    %             too slow
                save([PathName,FileName],'tbl','CellProperties','TimeStamps','ImagePath','clone');
                close(h);
            else
                errordlg('No tracks found');
            end
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
%             if hTrackPad.Tracks.CurrentTrackID>0 && ~hTrackPad.Tracks.Editing %cell selected but not currently editing
            if hTrackPad.Tracks.CurrentTrackID>0
                n=1;
                hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
                if length(hTrackPad.Tracks.Tracks)>1
                    hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
                end
            end % clears whole track if in track select mode
            
            NumberOfDeletedCells=0;
            for i=(n):m
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
                hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
                hTrackPad.ImageContextMenu.Reposition.Visible='off';
                hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
                hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
                hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
                if hTrackPad.Tracks.CurrentTrackID>0 % a selected track
                    CurrentTrackID=hTrackPad.Tracks.CurrentTrackID;                 
%                     xx=cellfun(@(x) isempty(x),{hTrackPad.Tracks.Tracks.ParentID});
%                     nextparent=find(xx(CurrentTrackID:end),1)+(CurrentTrackID-1);
                    for i=(CurrentTrackID+1):length(hTrackPad.Tracks.Tracks)
                        if ~isempty(hTrackPad.Tracks.Tracks(i).ParentID) && (hTrackPad.Tracks.Tracks(i).ParentID)>CurrentTrackID
                            hTrackPad.Tracks.Tracks(i).ParentID=hTrackPad.Tracks.Tracks(i).ParentID-1;   
                        elseif hTrackPad.Tracks.Tracks(i).ParentID==CurrentTrackID
                            hTrackPad.Tracks.Tracks(i).ParentID=[];
                            hTrackPad.Tracks.Tracks(i).Parent=[];
                        firstframe=find(cellfun(@(x) ~isempty(x),hTrackPad.Tracks.Tracks(i).Track.Track),1,'first');
                        hTrackPad.Tracks.Tracks(i).Track.Track{firstframe}.Annotation.Symbol='NA';
                        hTrackPad.Tracks.Tracks(i).Track.Track{firstframe}.Annotation.Type='ancestor';
                        end
                    end
                    
                    Remove(hTrackPad.Tracks);
                    hTrackPad.Tracks.CurrentTrack=[];
                    hTrackPad.Tracks.CurrentTrackID=0;
                    
                    hTrackPad.TrackNavigator.TableData=SubTable(hTrackPad.Tracks); %update tabledata
                    
                    for h=CurrentTrackID:length(hTrackPad.Tracks.Tracks)
                        n=find(cellfun(@(x) ~isempty(x),hTrackPad.Tracks.Tracks(h).Track.Track),1,'first');
                        m=find(cellfun(@(x) ~isempty(x),hTrackPad.Tracks.Tracks(h).Track.Track),1,'last');
                        %update annotations
                        pedigree_id=hTrackPad.Tracks.TableData.Ancestor_ID{h};
                        progeny_id=hTrackPad.Tracks.TableData.Progeny_ID{h};
                        for i=(n+1):(m-1)
                            hTrackPad.Tracks.Tracks(h).Track.Track{i}.Annotation.Type.PedigreeID=['Pedigree ' num2str(pedigree_id) ' Track ' num2str(progeny_id)];
                            hTrackPad.Tracks.Tracks(h).Track.Track{i}.Annotation.Symbol.PedigreeID=['P' num2str(pedigree_id) 'Tr' num2str(progeny_id)];
                        end
                    end
                    
               annotation_handles=findobj(gcf,'Type','Text');
               delete(annotation_handles);   
               n=length(hTrackPad.Tracks.Tracks);
               m=hTrackPad.ImageStack.CurrentNdx;
               
               for i=1:n %update annotations
                   if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})
                    x=hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,1)+hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,3)/2;
                    y=hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,2)+hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,4)/2;
                    if (m==hTrackPad.Tracks.Tracks(i).Track.trackrange(1)|| m==hTrackPad.Tracks.Tracks(i).Track.trackrange(2))
                    hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle=text(x,y,...
                                hTrackPad.Tracks.Tracks(i).Track.Track{m}.Annotation.Symbol,...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique','Visible','On','Color','g');                        
                    elseif sum(m~=hTrackPad.Tracks.Tracks(i).Track.trackrange)==2
                    hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle=text(x,y,...
                                hTrackPad.Tracks.Tracks(i).Track.Track{m}.Annotation.Symbol.(hTrackPad.AnnotationDisplay),...
                                'HorizontalAlignment','center','PickableParts','none',...
                                'Clipping','on','FontAngle','oblique','Visible','On','Color','g');
                    end
                   end
               end
                    %update track panel
                    clones=unique([hTrackPad.Tracks.TableData.Ancestor_ID{:}]);
                    clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);
                    hTrackPad.TrackPanel.ClonesPopup.String=clones;
                end
            else
                hTrackPad.Track.trackrange(2)=hTrackPad.ImageStack.NumberOfImages; %reset track range      
                hTrackPad.Track.CurrentEllipse=hTrackPad.Track.Track{n-1}.EllipseHandle;
                hTrackPad.ImageStack.CurrentNdx=n-1;
                
                %turn on relevant context menus
                hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
    %            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
     %           hTrackPad.ImageContextMenu.StopEditTrack.Visible='on';
                hTrackPad.ImageContextMenu.Reposition.Visible='on';                
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
            % if editing set range to end of stack
            if hTrackPad.Tracks.EditedTrackID>0
                hTrackPad.Track.trackrange(2)=hTrackPad.ImageStack.NumberOfImages;
            end
%             lastimage=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),1,'last'); 
  % discontinued editing mode          
%             if hTrackPad.Track.Editing %if tracking is continued after editing a track
%                 %reinstate pause and stop listeners if deleted (will be
%                 %deleted for tracks being edited)
%                 hTrackPad.Track.LostCellListener=event.listener(hTrackPad.Track,'LostCellEvent',@hTrackPad.listenLostCellEvent); %lost cell event is generated by tracker and listened to by trackpad
%                 hTrackPad.Track.EndTrackListener=event.listener(hTrackPad.Track,'EndOfTrackEvent',@hTrackPad.listenEndOfTrackEvent);%endtrack event is generated by tracker and listened to by trackpad
%                 hTrackPad.Track.StopListenerHandle=event.listener(hTrackPad.Track.CntrlObj,'StopEvent',@(varargin)tracker.listenStopEvent(varargin{:})); %stop event is generated by trackpad and list
%                 hTrackPad.Track.PauseListenerHandle=event.listener(hTrackPad.Track.CntrlObj,'PauseEvent',@(varargin)tracker.listenPauseEvent(varargin{:}));
% %                 hTrackPad.Track.PauseListenerHandle=event.listener(hTrackPad.Track.CntrlObj,'PauseEvent',@hTrackPad.Track.listenPauseEvent);
%                 hTrackPad.Track.parameters.NumberOfPriorImages=1; %set prior images to 1 - easier for @tracker.getrefimg function 
%                 current_track=hTrackPad.Tracks.CurrentTrackID;
%                 current_ndx=hTrackPad.ImageStack.CurrentNdx;
%                 range=hTrackPad.Tracks.Tracks(current_track).Track.trackrange;               
%                  
%                 h=waitbar(0,'Loading ellipses','WindowStyle','Modal');
%                 for i=range(1):current_ndx
%     %                 disp(num2str(i));                        
% 
%                         if i==range(1)
%                            [r,c]=size(hTrackPad.Track.Track{i}.CellIm);
% %                                            hTrackPad.Track.parameters.refimg=hTrackPad.Track.Track{lastimage}.CellIm;
%                            hTrackPad.Track.parameters.refimg=hTrackPad.Track.Track{i}.CellIm;
%                         elseif i>range(1)
%                         hTrackPad.Track.Track{i}.ParentTracker.parameters.startrectangle=hTrackPad.Track.Track{i}.Position;
%                         Im=squeeze(hTrackPad.Track.Track{i}.ParentTracker.GUIHandle.ImageStack.Stack(:,:,1,i));
%                         hTrackPad.Track.Track{i}.Mask=createMask(hTrackPad.Track.Track{i}.EllipseHandle);
%                         Im(~hTrackPad.Track.Track{i}.Mask)=NaN;
%                         hTrackPad.Track.Track{i}.CellIm=Im;
%                         hTrackPad.Track.trackrange=[range(1) hTrackPad.ImageStack.NumberOfImages]; %reset track range if tracking is continued after editing
%                         % trim image
%                         rows=sum(hTrackPad.Track.Track{i}.Mask,2)>0;
%                         cols=sum(hTrackPad.Track.Track{i}.Mask,1)>0;
%                         hTrackPad.Track.Track{i}.CellIm=hTrackPad.Track.Track{i}.CellIm(rows,cols);                            
%                             hTrackPad.Track.Track{i}.CellIm=imresize(hTrackPad.Track.Track{i}.CellIm,[r c]);
%                         end
%                 waitbar(i/current_ndx,h);   
%                 end
%                 close(h);
%                 hTrackPad.Track.Editing=false; 
%                 
%             end            
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='off';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
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
            hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
            % load track from TrackCollection into CurrentTrack
            hTrackPad.Tracks.EditedTrackID=hTrackPad.Tracks.CurrentTrackID;
            % get first ellipse
            
            
            % TrackPad thinks this is a new track
            % when user clicks StopTrack will replace track instead of
            % append track to track collection.
            CurrentNdx=hTrackPad.ImageStack.CurrentNdx;
            range=hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.trackrange;
            hTrackPad.ImageStack.CurrentNdx=range(1);
             % make trackpad think that we are editing a new track           
            hTrackPad.Tracks.CurrentTrackID=0;
            % create new tracker object
            Position=hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{range(1)}.Position;
            hEllipse=imellipse(hTrackPad.ImageHandle.Parent,Position);
            set(hEllipse,'Visible','on','PickableParts','none');
            setColor(hEllipse,'b');
            setResizable(hEllipse,false);
            hTrackPad.Track=tracker(range,hEllipse,hTrackPad); % create new Track object
            hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.Mask=...
                    hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.Mask;
            hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.CellIm=...
                hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.CellIm;
            hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.Annotation=...
                hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.Annotation;
            hTrackPad.Track.parameters=hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.parameters; % use old parameters
            h=waitbar(0,'Loading track for editing');
            for i=2:(range(2)-range(1))+1
                hTrackPad.ImageStack.CurrentNdx=hTrackPad.ImageStack.CurrentNdx+1;
                Position=hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.Position;
                hTrackPad.Track.CurrentEllipse=imellipse(hTrackPad.ImageHandle.Parent,Position);
                set(hTrackPad.Track.CurrentEllipse,'Visible','on','PickableParts','none');
                setColor(hTrackPad.Track.CurrentEllipse,'b');
                setResizable(hTrackPad.Track.CurrentEllipse,false);
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}=CellImage(hTrackPad.Track);
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.CntrlObj=hTrackPad; % allow cell image to listen to TrackPad events such as hide or show ellipses.
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.Position=Position;
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.Mask=...
                    hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.Mask;
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.CellIm=...
                    hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.CellIm;
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.Annotation=...
                    hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.Annotation;
                hTrackPad.Track.Track{hTrackPad.ImageStack.CurrentNdx}.Result=...
                    hTrackPad.Tracks.Tracks(hTrackPad.Tracks.EditedTrackID).Track.Track{hTrackPad.ImageStack.CurrentNdx}.Result;
                waitbar(i/((range(2)-range(1))+1),h);
            end
            close(h);
%             if CurrentNdx==range(2)
%                 hTrackPad.ImageStack.CurrentNdx=CurrentNdx-1; % gets rid of bug! No ellipse found in range(2)+1  
%             else
%                 
%             end    
            hTrackPad.ImageStack.CurrentNdx=CurrentNdx;
            hTrackPad.FrameSliderHandle.Enable='on';
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off'; % stop edit track discontinued
            hTrackPad.ImageContextMenu.Reposition.Visible='on';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
            hTrackPad.ImageContextMenu.StopTrack.Visible='on';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
           
        end
        
        
        function StopEditTrack(hObject,EventData,hTrackPad)
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
            hTrackPad.ImageContextMenu.Reposition.Visible='off';
            hTrackPad.ImageContextMenu.StopTrack.Visible='off';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='off';
            hTrackPad.ImageContextMenu.SelectTrack.Visible='on';
            hTrackPad.ImageContextMenu.StartTrack.Visible='on';
            hTrackPad.ImageContextMenu.AnnotateTrack.Visible='off';
            hTrackPad.ImageContextMenu.Cancel.Visible='off'; %cancel
            hTrackPad.ImageContextMenu.ReturnToStart.Visible='off'; %return to start
            hTrackPad.ImageContextMenu.GoToEnd.Visible='off'; %go to end
            m=hTrackPad.ImageStack.CurrentNdx; % make all tracks in current frame unselectable
            firstframe=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),1,'first');
            lastframe=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),1,'last');
            x=hTrackPad.Track.Track{lastframe}.Position(1,1)+hTrackPad.Track.Track{lastframe}.Position(1,3)/2;
            y=hTrackPad.Track.Track{lastframe}.Position(1,2)+hTrackPad.Track.Track{lastframe}.Position(1,4)/2;
     
                if ~isempty(hTrackPad.Track.Track{m})
                    hAnnotation=hTrackPad.Track.Track{m}.AnnotationHandle;
                    if m==lastframe
                    delete(hAnnotation);    
                    elseif m~=lastframe
                    set(hAnnotation,'PickableParts','none');
                    set(hAnnotation,'ButtonDownFcn',''); % disable callbacks
                    set(hTrackPad.Track.Track{m}.AnnotationHandle,'Color',[0,1,0]);
                    end
                end 
           
            if  isfield(hTrackPad.Track.Track{lastframe},'Annotation')
%                 isfield(hTrackPad.Track.Track{lastframe}.Annotation.Symbol,'PedigreeID') %reannoate last frame if it was deleted               
                hTrackPad.Track.Track{lastframe}.Annotation.Type=hTrackPad.CellProperties(2).Type{1};
                hTrackPad.Track.Track{lastframe}.Annotation.Symbol=hTrackPad.CellProperties(2).Symbol{1};
                hTrackPad.Track.Track{lastframe}.AnnotationHandle=text(x,y,hTrackPad.CellProperties(2).Symbol{1},...
                                    'HorizontalAlignment','center','PickableParts','none',...
                                    'Clipping','on','FontAngle','oblique','Color','g'); 
                hTrackPad.Track.trackrange(2)=lastframe;

                        if m==lastframe
                        set(hTrackPad.Track.Track{lastframe}.AnnotationHandle,'Visible','On');    
                        elseif m~=lastframe
                        set(hTrackPad.Track.Track{lastframe}.AnnotationHandle,'Visible','Off');   
                        end
            
            end
            
%             if hTrackPad.Tracks.Editing
                hTrackPad.Tracks.Editing=false;
                delete(findobj(gcf,'Tag','imellipse'));              
%             end
            hTrackPad.Track.Editing=false; %there are two flags to indicate editing - one in hTrackPad.Track and one in hTrackPad.Tracks 
            delete(hTrackPad.Track.PauseListenerHandle); %delete listeners
            delete(hTrackPad.Track.StopListenerHandle);
            delete(hTrackPad.Track.LostCellListener);
            delete(hTrackPad.Track.EndTrackListener);
            if hTrackPad.Tracks.CurrentTrackID==0
                hTrackPad.Tracks.Append;
            else
                hTrackPad.Tracks.Tracks(hTrackPad.Tracks.CurrentTrackID).Track=hTrackPad.Track;
            end
            hTrackPad.Tracks.CurrentTrackID=0;
            hTrackPad.Tracks.CurrentTrack=[];
            hTrackPad.Track=[]; %no current track
            hTrackPad.TrackPanel.CurrentTrackDisplay.String='No track selected';
            hTrackPad.TrackPanel.CurrentTrackDisplay.ForegroundColor='red';
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
            [r,c]=find(hTrackPad.Track.Track{n}.Mask); %why is this mask square not circular?
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
            
            rows=sum(hTrackPad.Track.Track{n}.Mask,2)>0;
            cols=sum(hTrackPad.Track.Track{n}.Mask,1)>0;
            im=im(rows,cols);
            if sum(size(im)==size(b))==2  
            newCellIm(:)=im; %mask is square and then converted to a circle by CellIm - this is potential error between ellipses.
            newCellIm(b)=NaN;
            hTrackPad.Track.Track{n}.CellIm=newCellIm;
            else
            newCellIm(:)=imresize(im,size(b)); %mask is square and then converted to a circle by CellIm - this is potential error between ellipses.
            newCellIm(b)=NaN;
            hTrackPad.Track.Track{n}.CellIm=newCellIm;                
            end
            set(hTrackPad.Track.Track{n}.EllipseHandle,'Selected','off');
            setColor(hTrackPad.Track.Track{n}.EllipseHandle,'b');
            SetCell(hTrackPad.Track.Track{n},hTrackPad.Track.Track{n}.Mask);
            hTrackPad.FrameSliderHandle.Enable='on';
            hTrackPad.ImageContextMenu.Reposition.Visible='on';
            hTrackPad.ImageContextMenu.ContinueTrack.Visible='on';
            hTrackPad.ImageContextMenu.StopTrack.Visible='on';
            hTrackPad.ImageContextMenu.DeleteTrack.Visible='on';
            
%             if hTrackPad.Track.Editing 
%               hTrackPad.ImageContextMenu.StopTrack.Visible='off';
%               hTrackPad.Track.Track{n}.Position=CorrectPosition;
%             end  % editing mode discontinued
        end
        
        
        function PauseTracking(hObject,EventData,hTrackPad)
            if ~isempty(hTrackPad.Track)
                if strcmp(hTrackPad.Track.FindCellState,'go')
                    notify(hTrackPad,'PauseEvent');
                    display('Pausing');
                    hTrackPad.ImageContextMenu.EditTrack.Visible='off';
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
            if length(annotationsubsets)==1
                close(fh);
                errordlg('No features were found. Please edit features');
            else
                for j=1:length(annotationsubsets)-1
                    features=Subsets.Type.(annotationsubsets{j});
                    features=unique(features);
                    for k=1:length(features)
                        data{rownumb,1}=annotationsubsets{j};
                        data{rownumb,2}=Subsets.Type.(annotationsubsets{j}){k};
                        data{rownumb,3}=Subsets.Symbol.(annotationsubsets{j}){k};
                        rownumb=rownumb+1;
                    end

                end

                %add more rows
                for i=rownumb:20
                    data{i,1}='Choose annotation subset';
                    data{i,2}=[];
                    data{i,3}=[];
                end

                ndx=contains(data(:,1),'PedigreeID');
                data=data(~ndx,:); % remove PedigreeID rows
                ndx=contains(annotationsubsets,'PedigreeID');
                annotationsubsets=annotationsubsets(~ndx)';
                columnformat=({annotationsubsets [] []});
                t=uitable(fh,'Data',data,'ColumnWidth',{180 120 50},'ColumnFormat',columnformat,...
                    'ColumnEditable',true,'Units','normalized','RowName',[]);
                t.Position=[(1-t.Extent(3))/2,(1-t.Extent(4))/2,t.Extent(3),t.Extent(3)];
                t.ColumnName={'Feature','Type','Symbol'}       ;   
                fh.DeleteFcn={@hTrackPad.SaveAnnotationTable,hTrackPad};
            end
        end
        
        function setFeatures(hObject,EventData,hTrackPad)
            Fields=fieldnames(hTrackPad.CellProperties(3).Type);
            str='';
            ndx=contains(Fields,'PedigreeID');
            Fields=Fields(~ndx);
            for i=1:length(Fields)
                str=[str Fields{i} ' '];
            end
            answer=inputdlg('Features:','Set Features',1,{str});
            if isempty(answer{1})
                errordlg('No features were entered? Entering default features and types')
                hTrackPad.CellProperties(3).Type.GFP={'No annotation','GFP positive','GFP negative'};
                hTrackPad.CellProperties(3).Symbol.GFP={'NA','G+','G-'};
                hTrackPad.CellProperties(3).String.GFP={'No annotation (NA)','GFP positive (G+)','GFP negative (G-)'};
                hTrackPad.CellProperties(3).Type.Adhesion={'No annotation','Adherent','Semi-adherent','Detatched'};
                hTrackPad.CellProperties(3).Symbol.Adhesion={'NA','AD','SA','DE'};
                hTrackPad.CellProperties(3).String.Adhesion={'No annotation (NA)','Adherent (AD)','Semi-adherent (SA)','Detatched (DE)'};
            else
                NewFields=textscan(answer{1},'%s');
                NewFields=NewFields{1};
                % do not erase Type and Symbol for features that are retained!
                ndx=contains(Fields,NewFields);
                % remove Fields that are not in NewFields
                RmFields=Fields(~ndx);
                % add NewFields that are not in Fields
                ndx=contains(NewFields,Fields);
                AddFields=NewFields(~ndx);
                if ~isempty(AddFields)
                    for i=1:length(AddFields)
                        hTrackPad.CellProperties(3).Type.(AddFields{i})={'No annotation'};
                        hTrackPad.CellProperties(3).Symbol.(AddFields{i})={'NA'};
                        hTrackPad.CellProperties(3).String.(AddFields{i})={'No annotation (NA)'};
                        % addfields to all tracks and cellimage objects
                        if ~isempty(hTrackPad.Tracks)
                            for j=1:length(hTrackPad.Tracks.Tracks)
                                for k=1:length(hTrackPad.Tracks.Tracks(j).Track.Track)
                                    if (~isempty(hTrackPad.Tracks.Tracks(j).Track.Track{k}))&&...
                                        iscell(hTrackPad.Tracks.Tracks(j).Track.Track{k}.Annotation.Name)
                                        hTrackPad.Tracks.Tracks(j).Track.Track{k}.Annotation.Type.(AddFields{i})='No annotation';
                                        hTrackPad.Tracks.Tracks(j).Track.Track{k}.Annotation.Symbol.(AddFields{i})='NA';
                                        hTrackPad.Tracks.Tracks(j).Track.Track{k}.Annotation.Name{end+1}=AddFields{i};
                                    end
                                end
                            end
                        end
                    end
                end
                if ~isempty(RmFields)
                    button = questdlg(['Are you sure you want to delete ' RmFields'],...
                        'Warning: Removing features','Yes');
                    switch(button)
                        case 'Yes'                       
                            for i=1:length(RmFields)
                                hTrackPad.CellProperties(3).Type=rmfield(hTrackPad.CellProperties(3).Type,RmFields{i});
                                hTrackPad.CellProperties(3).Symbol=rmfield(hTrackPad.CellProperties(3).Symbol,RmFields{i});
                                hTrackPad.CellProperties(3).String=rmfield(hTrackPad.CellProperties(3).String,RmFields{i});
                            end
                    end
                end
                % rewrite submenus
                handles=guihandles(hTrackPad.FigureHandle);
                submenus=get(hTrackPad.AnnotationDisplayMenuHandle,'Children');
                for i=1:length(submenus)
                    delete(submenus(i));
                end
                NewFields=fieldnames(hTrackPad.CellProperties(3).Type);
                for i=1:length(NewFields)
                    uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label',NewFields{i},...
                        'Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},'Tag','Change annotation display');
                end
                uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label','None',...
                    'Checked','on','Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},'Tag','Change annotation display');
                guidata(hTrackPad.FigureHandle,handles);
                hTrackPad.AnnotationDisplay='None'; %set fluorescent annotation subsets by default
            end
        end
        
        function SaveAnnotationTable(hObject,EventData,hTrackPad)
            data=hObject.Children.Data;
            hTrackPad.CellProperties(3).Name='Subsets';
            % empty prior annotation definitions
            hTrackPad.CellProperties(3).Type=[];
            hTrackPad.CellProperties(3).Symbol=[];
            hTrackPad.CellProperties(3).String=[];

            %initialise CellProperties
            ndx=contains(data(:,1),'Choose annotation subset');
            data=data(~ndx,:);
            %remove all rows with 'No annotation' or are empty
            ndx=cell2mat(cellfun(@(x) ~isempty(x),data(:,3),'UniformOutput',false));
            data=data(ndx,:);
            ndx=contains(data(:,3),'NA');
            data=data(~ndx,:);
            fnames=unique(data(:,1));
            for i=1:length(fnames)
                hTrackPad.CellProperties(3).Type.(fnames{i})={'No annotation'};
                hTrackPad.CellProperties(3).Symbol.(fnames{i})={'NA'};
                hTrackPad.CellProperties(3).String.(fnames{i})={'No annotation (NA)'};

            end
            for i=1:size(data,1)
                hTrackPad.CellProperties(3).Type.(data{i,1}){end+1}=data{i,2};
                hTrackPad.CellProperties(3).Symbol.(data{i,1}){end+1}=data{i,3};
                hTrackPad.CellProperties(3).String.(data{i,1}){end+1}=...
                    [data{i,2} ' (' data{i,3} ')'];
            end
            hTrackPad.CellProperties(3).Type.PedigreeID={'No annotation'};
            hTrackPad.CellProperties(3).Symbol.PedigreeID={'NA'};
            hTrackPad.CellProperties(3).String.PedigreeID={'No annotation (NA)'};
            % rewrite submenus
            handles=guihandles(hTrackPad.FigureHandle);
            submenus=get(hTrackPad.AnnotationDisplayMenuHandle,'Children');
            for i=1:length(submenus)
                delete(submenus(i));
            end
            for i=1:length(fnames)
                uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label',fnames{i},...
                    'Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},'Tag','Change annotation display');
            end

            uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label','PedigreeID',...
                'Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},'Tag','Change annotation display');
            uimenu(hTrackPad.AnnotationDisplayMenuHandle,'Label','None',...
                'Checked','on','Callback',{@hTrackPad.ChangeAnnotationDisplay,hTrackPad},'Tag','Change annotation display');
            guidata(hTrackPad.FigureHandle,handles);
            hTrackPad.AnnotationDisplay='None'; %set fluorescent annotation subsets by default
            
            
%             for i=1:length(fnames)-1 %don't include pedigreeID
%                 ndx=cellfun(@(x) strcmp(x,fnames{i}),data(:,1));
%                 if sum(cellfun(@(x) isempty(x),data(ndx,2)))==0
%                 hTrackPad.CellProperties(3).Type.(fnames{i})=data(ndx,2);
%                 hTrackPad.CellProperties(3).Symbol.(fnames{i})=data(ndx,3);
%                 hTrackPad.CellProperties(3).String.(fnames{i})=cellfun(@(x,y) [x ' (' y ')'],...
%                     data(ndx,2),data(ndx,3),'UniformOutput',0)';
%                 end
%             end
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
            hTrackPad.ImageContextMenu.EditTrack.Visible='off';
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
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
                        displaystring={['Pedigree ' num2str(PedigreeID{:})] ['Track ' num2str(ProgenyID{:})]};
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
            hTrackPad.ImageContextMenu.StopEditTrack.Visible='off';
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
            elseif x(2)>size(hTrackPad.ImageHandle.CData,2)
                x(2)=size(hTrackPad.ImageHandle.CData,2);
            end
            if y(2)<1
                y(1)=1;
            elseif y(2)>size(hTrackPad.ImageHandle.CData,1)
                y(2)=size(hTrackPad.ImageHandle.CData,1);
            end
            zoomdata=getappdata(gca, 'matlab_graphics_resetplotview');
            if ~isempty(zoomdata)
                zoomdata.XLim=[0.5000 size(hTrackPad.ImageHandle.CData,2)];
                zoomdata.YLim=[0.5000 size(hTrackPad.ImageHandle.CData,1)];
                setappdata(gca, 'matlab_graphics_resetplotview',zoomdata);
            else
                zoom reset
            end
            set(hTrackPad.FigureHandle.CurrentAxes,'XLim',sort(x));
            set(hTrackPad.FigureHandle.CurrentAxes,'YLim',sort(y));
            hTrackPad.TrackNavigator.TableData=SubTable(hTrackPad.Tracks); %update tabledata
            
            %update track panel
            clones=unique([hTrackPad.Tracks.TableData.Ancestor_ID{:}]);
            clones=arrayfun(@(x) ['Pedigree ' num2str(x)],clones,'UniformOutput',0);
            hTrackPad.TrackPanel.ClonesPopup.String=clones;
        end
        
        function CloseAnnotationFigure(src,callbackdata,hTrackPad)
            try
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
            
             %update 
            try
                if isempty(hTrackPad.TrackNavigator)
                    hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                elseif isa(hTrackPad.TrackNavigator,'TrackNavigator') 
                    if isvalid(hTrackPad.TrackNavigator.TableFigureHandle)
                        close(hTrackPad.TrackNavigator.TableFigureHandle);
                    end
                    CreateTable(hTrackPad.Tracks); % update tbl
                    hTrackPad.TrackNavigator.PedigreeData=CreateCloneFiles(hTrackPad.Tracks);
                    hTrackPad.TrackNavigator.TableData=hTrackPad.Tracks.SubTable();
%                     if ~isvalid(hTrackPad.TrackNavigator.TableFigureHandle)
%                         hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
%                     else 
%                         close(hTrackPad.TrackNavigator.TableFigureHandle); % don't duplicate figures;
%                         hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks); %already deleted 
%                     end
                end
            catch
                disp('Unsucessful update of TrackNavigation object');
            end
            pedigree_id=hTrackPad.Tracks.TableData.Ancestor_ID{CurrentTrackID};
            progeny_id=hTrackPad.Tracks.TableData.Progeny_ID{CurrentTrackID};
            n=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),1,'first');
            m=find(cellfun(@(x) ~isempty(x),hTrackPad.Track.Track),1,'last');            
            for i=(n+1):(m-1)
                hTrackPad.Track.Track{i}.Annotation.Type.PedigreeID=['Pedigree ' num2str(pedigree_id) ' Track ' num2str(progeny_id)];
                hTrackPad.Track.Track{i}.Annotation.Symbol.PedigreeID=['P' num2str(pedigree_id) 'Tr' num2str(progeny_id)];
            end            
        
            delete(src);
            hTrackPad.AnnotationFigureHandle=[];
            hTrackPad.Track=[];
            catch
                disp('Error closing annotation tool');
                delete(src);
                hTrackPad.AnnotationFigureHandle=[];
                hTrackPad.Track=[];
            end
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
            if isempty(hTrackPad.Tracks)
                warndlg('No tracks','Warning','modal');
                
            elseif ~isempty(hTrackPad.Tracks) && isempty(hTrackPad.Tracks.tbl)
                warndlg('Save tracks before opening track table','Warning','modal');
            else
                CreateTable(hTrackPad.Tracks); %update track tbl to include any newly tracked cells
%                 hTrackPad.TrackTable=TrackTable;
%                 hTrackPad.TrackTable.CntrlObj=hTrackPad;
%                 hTrackPad.TableNaviator.TableData=SubTable(hTrackPad.Tracks);
%                 hTrackPad.TrackTable.PedigreeData=CreateCloneFiles(hTrackPad.TrackTable,hTrackPad.Tracks.tbl,...
%                     hTrackPad.ImageStack.AcquisitionTimes);
                if isempty(hTrackPad.TrackNavigator)
                    hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                elseif ~isa(hTrackPad.TrackNavigator,'TrackNavigator')
                    hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                elseif  isvalid(hTrackPad.TrackNavigator.TableFigureHandle)
                    close(hTrackPad.TrackNavigator.TableFigureHandle); % don't duplicate figures;
                    hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks); %already deleted 
                else
                    hTrackPad.TrackNavigator=TrackNavigator(hTrackPad.Tracks);
                end
            end
        end
    
        
        
        function ChangeAnnotationDisplay(Object,EventData,hTrackPad)
            if ~isempty(hTrackPad.Tracks)
                
%                 annotationdisplayhandle=findall(gcf,'Tag','Change annotation display');
                annotationdisplayhandle=hTrackPad.AnnotationDisplayMenuHandle.Children;
%                 fnames=fliplr(fieldnames(hTrackPad.CellProperties(3).Type)');
                
%                 for i=1:length(fnames)
%                    annotationdisplayhandle(i+1).Label=fnames{i};
%                     
%                 end
%                 structfun((@(x)  x annotationdisplayhandle.Label),fliplr(fnames))
                
                for i=1:length(annotationdisplayhandle)
                    if strcmp(EventData.Source.Label,annotationdisplayhandle(i).Label)
                        annotationdisplayhandle(i).Checked='on';
                        hTrackPad.AnnotationDisplay=annotationdisplayhandle(i).Label;
                    else
                        annotationdisplayhandle(i).Checked='off';
                    end
                end
                
                if strcmp(EventData.Source.Label,'None')
                    annotation_handles=findobj(gcf,'Type','Text');
                    delete(annotation_handles);
                elseif ~strcmp(EventData.Source.Label,'None')
                    annotation_handles=findobj(gcf,'Type','Text');
                    delete(annotation_handles);
                    
                    n=length(hTrackPad.Tracks.Tracks);
                    
                    m=hTrackPad.ImageStack.CurrentNdx;
                    
                    for i=1:n
                        if ~isempty(hTrackPad.Tracks.Tracks(i).Track.Track{m})
                            x=hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,1)+hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,3)/2;
                            y=hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,2)+hTrackPad.Tracks.Tracks(i).Track.Track{m}.Position(1,4)/2;
                            if (m==hTrackPad.Tracks.Tracks(i).Track.trackrange(1)|| m==hTrackPad.Tracks.Tracks(i).Track.trackrange(2))
                                hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle=text(x,y,...
                                    hTrackPad.Tracks.Tracks(i).Track.Track{m}.Annotation.Symbol,...
                                    'HorizontalAlignment','center','PickableParts','none',...
                                    'Clipping','on','FontAngle','oblique','Visible','On','Color','g');
                            elseif sum(m~=hTrackPad.Tracks.Tracks(i).Track.trackrange)==2
                                hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle=text(x,y,...
                                    hTrackPad.Tracks.Tracks(i).Track.Track{m}.Annotation.Symbol.(hTrackPad.AnnotationDisplay),...
                                    'HorizontalAlignment','center','PickableParts','none',...
                                    'Clipping','on','FontAngle','oblique','Visible','On','Color','g');
                            end
                            
                            if i~=hTrackPad.Tracks.CurrentTrackID
                                set(hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle,'Color',[0,1,0],'PickableParts','all');
                            elseif i==hTrackPad.Tracks.CurrentTrackID
                                set(hTrackPad.Tracks.Tracks(i).Track.Track{m}.AnnotationHandle,'Color',[1,0,0],'PickableParts','all');
                            end
                        end
                        
                    end

                    
                end
                
            else isempty(hTrackPad.Tracks)
                
                warndlg('No tracks loaded','modal');
                
            end
            
        end
        
        function ChooseTrack(Object,EventData,hTrackPad)
            value=EventData.Source.Value;
            progenyid=sscanf(EventData.Source.String{value},'Track %d');
            lineageid=sscanf(hTrackPad.TrackPanel.ClonesPopup.String{hTrackPad.TrackPanel.ClonesPopup.Value},'Pedigree %d');
            trackid=find(([hTrackPad.Tracks.TableData.Ancestor_ID{:}]==lineageid &...
                [hTrackPad.Tracks.TableData.Progeny_ID{:}]==progenyid));
            hTrackPad.Tracks.CurrentTrackID=trackid;
            hTrackPad.Track=hTrackPad.Tracks.Tracks(trackid).Track;
            displaystring={['Pedigree ' num2str(lineageid)] ['Track ' num2str(progenyid)]};
            displaystring=textwrap(hTrackPad.TrackPanel.CurrentTrackDisplay,displaystring);
            hTrackPad.TrackPanel.CurrentTrackDisplay.String=displaystring;
            go2endhandle=findall(hTrackPad.FigureHandle,'TooltipString','Go to end of track');
            go2endcallback=get(go2endhandle,'ClickedCallback');
            go2endcallback{1}(go2endhandle,[],hTrackPad);
            hTrackPad.ImageContextMenu.SelectTrack.Visible='off';
        end
        
        function ChooseClone(Object,EventData,hTrackPad)
            value=EventData.Source.Value;
            cloneid=sscanf(EventData.Source.String{value},'Pedigree %d');
            ndx=[hTrackPad.Tracks.TableData.Ancestor_ID{:}]==cloneid;
            progenyid=sort([hTrackPad.Tracks.TableData.Progeny_ID{ndx}]);
            progenyid=arrayfun(@(x) ['Track ' num2str(x)],progenyid,'UniformOutput',0);
            hTrackPad.TrackPanel.TracksPopup.String=progenyid;
            hTrackPad.TrackPanel.TracksPopup.Value=1;
        end
        
        function getCursorPosition(hObject, EventData, hTrackPad)
            cursorposition=get(hTrackPad.FigureHandle.CurrentAxes,'CurrentPoint');
            if ~isempty(cursorposition)
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
        
        
        function AvatarOptimisation (Object,EventData,hTrackPad)
           
            if ~isempty(hTrackPad.Tracks)
                if length(hTrackPad.Tracks.Tracks)<5
                    errordlg('Minimum of 5 tracks required for optimisation');
                    uiwait();
                else

                    %prompt user for optimisation settings
                    prompt={'Min search radius: '; 'Step size:'; 'Max search radius:';'Max frames:';'Max tracks:'};
                    title='Search radius optimisation settings';
                    defaultans={'2','2','20','50','10'};
                    answer=inputdlg(prompt,title,1,defaultans);  
                    sr_min=str2num(answer{1});
                    sr_stepsize=str2num(answer{2});
                    sr_max=str2num(answer{3});
                    scan_sr=sr_min:sr_stepsize:sr_max;                
                    maxframes_sr=str2num(answer{4});
                    maxtracks_sr=str2num(answer{5});

                    prompt={'Min rho: '; 'Step size:'; 'Max rho:';'Max frames:';'Max tracks:'};
                    title='Correlation threshold optimisation settings';
                    defaultans={'0.5','0.1','1','50','10'};
                    answer=inputdlg(prompt,title,1,defaultans);  
                    rho_min=str2num(answer{1});
                    rho_stepsize=str2num(answer{2});
                    rho_max=str2num(answer{3});
                    scan_rho=rho_min:rho_stepsize:rho_max;
                    maxframes_rho=str2num(answer{4});
                    maxtracks_rho=str2num(answer{5});

                    %delete existing avatar track files if they exist
                    avatarpath=[hTrackPad.TrackPath 'AvatarTracks'];
                    if isdir(avatarpath)
                        rmdir(avatarpath,'s');
                    end

                    %remove annotation text and set annotation to None
                    annotation_handles=findobj(gcf,'Type','Text');
                    delete(annotation_handles);
                    hTrackPad.AnnotationDisplay='None';

                    %first optimise search radius by evaluating the precision
                    %with rho=0 (true positives/total outcomes)
                   parameter={'Search radius'};
                   h=waitbar(0,['Simulating search radii: ' num2str(scan_sr(1)) ' - ' num2str(scan_sr(end)) ' pixels']);
                    for i=1:length(scan_sr)
                        Avatar1=avatar(hTrackPad,hTrackPad.Tracks.tbl,parameter);
                        Avatar1.MaxFrames=maxframes_sr;
                        Avatar1.MaxTracks=maxtracks_sr;
                        Avatar1.CorrelationThreshold=-0.1;
                        Avatar1.SearchRadius=scan_sr(i);
                        Avatar1.SimulateTracking;
                        Avatar1.SaveTracks;
                        delete(Avatar1);
                        clear Avatar1;
                        waitbar(i/length(scan_sr),h);
                    end
                    close(h);

                    %get avatar tracks from avatar directory
                    avatarpath=[hTrackPad.TrackPath 'AvatarTracks\Search radius\'];
                    avatartrackfiles=dir(avatarpath);
                    avatartrackfiles={avatartrackfiles(3:end).name};
                    truthtable=hTrackPad.Tracks.tbl;

                    [TruthSet,ROCtbl]=avatar.AnalyseAvatarTracks(truthtable,avatartrackfiles,avatarpath);                

    %                 figure();
    %                 plot(ROCtbl.SearchRadius,(ROCtbl.TruePositives./(ROCtbl.TruePositives+ROCtbl.FalsePositives)),'.','MarkerSize',20);
    %                 hold on;
    %                 plot(ROCtbl.SearchRadius,(ROCtbl.TruePositives./(ROCtbl.TruePositives+ROCtbl.FalsePositives)));
    %                 hold off;
    %                 
    %                 
    %                 figure();
    %                 plot(ROCtbl.SearchRadius,(ROCtbl.TPR),'.','MarkerSize',20);
    %                 hold on;
    %                 plot(ROCtbl.SearchRadius,(ROCtbl.TPR));
    %                 hold off;



                    [~,I]=max(ROCtbl.TruePositives./(ROCtbl.TruePositives+ROCtbl.FalsePositives)); %find optimum search radius - radius that maximises precision
                    sr_optimum=scan_sr(I);

                    %optimise rho using optimal search radius from above
                    parameter={'Correlation threshold'};
                    Avatar1=avatar(hTrackPad,hTrackPad.Tracks.tbl,parameter);
                    Avatar1.CorrelationThreshold=-0.1;
                    Avatar1.SearchRadius=sr_optimum;
                    Avatar1.MaxFrames=maxframes_rho;
                    Avatar1.MaxTracks=maxtracks_rho;
                    Avatar1.SimulateTracking;
                    % save tracks
                    Avatar1.SaveTracks;
                    % delete avatar
                    delete(Avatar1);
                    h=waitbar(0,['Simulating rho : ' num2str(scan_rho(1)) ' - ' num2str(scan_rho(end))]);
                    for i=1:length(scan_rho)
                        Avatar1=avatar(hTrackPad,hTrackPad.Tracks.tbl,parameter);
                        Avatar1.SearchRadius=sr_optimum;
                        Avatar1.CorrelationThreshold=scan_rho(i);
                        Avatar1.MaxFrames=maxframes_rho;
                        Avatar1.MaxTracks=maxtracks_rho;
                        Avatar1.SimulateTracking;
                        Avatar1.SaveTracks;
                        delete(Avatar1);
                        waitbar(i/length(scan_rho),h);
                    end
                    close(h);


                    %get avatar tracks from avatar directory
                    avatarpath=[hTrackPad.TrackPath 'AvatarTracks\Correlation threshold\'];
                    avatartrackfiles=dir(avatarpath);
                    avatartrackfiles={avatartrackfiles(3:end).name};
                    truthtable=hTrackPad.Tracks.tbl;

                    [TruthSet,ROCtbl]=avatar.AnalyseAvatarTracks(truthtable,avatartrackfiles,avatarpath);
                    [rho_optimum,~]=avatar.AnalyseROC(TruthSet,ROCtbl(2:end,:)); %remove rho=-0.1 condition

                    %update tracking parameters 

                     hTrackPad.CurrentTrackingParameters.CorrelationThreshold=rho_optimum;
                        if ~isempty(hTrackPad.Track)
                            hTrackPad.Track.parameters.confidencethreshold=rho_optimum;
                        end

                    hTrackPad.CurrentTrackingParameters.SearchRadius=sr_optimum;
                        if ~isempty(hTrackPad.Track)
                            hTrackPad.Track.parameters.searchradius=sr_optimum;
                        end   

                end

                disp(['Optimum search radius: ' num2str(sr_optimum)]);
                disp(['Optimum rho: ' num2str(rho_optimum)]);
                msgbox(['Optimum search radius: ' num2str(sr_optimum) '.' ...
                    'Optimum rho: ' num2str(rho_optimum)]);

            else
                errordlg('No tracks');
            end
        end
        
        
    end
    
end





