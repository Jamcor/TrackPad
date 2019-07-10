classdef tracker < handle
    % The tracker class implements a cross correlation algorithm for cell
    % tracking    
    
    properties
        %tracking properties
        parameters
        method='correlation';
        useGPU=true;
        %Editing %logical to indicate if track is currently being edited by the user
        
       
        %tracking control
       
        trackrange % range of frames to track
        FindCellState
        Interrupt=false;
        CurrentEllipse
        
        % handles to memory objects that only exist at runtime
        Stack
        Track 
        GUIHandle
        
        
        %listens to the following objects
        CntrlObj
        StopListenerHandle
        PauseListenerHandle
        LostCellListener
        EndTrackListener
        TrackEventListener
    end
    
    events
        LostCellEvent
        EndOfTrackEvent
        TrackEvent
        ChangeImage
    end
    
    
    methods (Static)      
        %constructor
        function obj=tracker(range,hellipse,GUIHandle)
            % stack is a ImageStack object,
            % start is the first image to be tracked
            % range is the range of images to be tracked
            % hellipse is the start ellipse
            obj.Stack=GUIHandle.ImageStack;
            obj.CntrlObj=GUIHandle;
            obj.StopListenerHandle=event.listener(obj.CntrlObj,'StopEvent',@obj.listenStopEvent);
            obj.PauseListenerHandle=event.listener(obj.CntrlObj,'PauseEvent',@obj.listenPauseEvent);
            if sum(range>obj.Stack.NumberOfImages) 
                error('Range outside of ImageStack');
            end
            obj.trackrange=range;
            obj.GUIHandle=GUIHandle;
%             obj.Editing=false; %Editing property discontinued
            % intialize startrectangle
            p.isParallel=GUIHandle.isParallel;
            p.startrectangle=round(getPosition(hellipse));             
            obj.CurrentEllipse=hellipse;
            %intialise stack pointer to first image
            obj.Stack.CurrentNdx=obj.trackrange(1);
            p.celldiameter=GUIHandle.CurrentTrackingParameters.NucleusRadius; % Cell Radius = diameter
            p.memory=ones(1,18); %change the memory vector to check influence of memory on tracking performance
            p.NumberOfPriorImages=1;
            p.searchradius=GUIHandle.CurrentTrackingParameters.SearchRadius;
            p.confidencethreshold=GUIHandle.CurrentTrackingParameters.CorrelationThreshold;
            
            p.refimg=[];
            p.lastmask=[];
            p.im=[];
            p.RefImageProtocol='Use memory'; % alternatively use 'Use memory'
            obj.parameters=p;

            % initialise FindCellState
            obj.FindCellState='go';
            % intialise track array
            obj.Track=cell(obj.Stack.NumberOfImages,1);
            % get first cell
            obj.Track{obj.trackrange(1)}=CellImage(obj);
            obj.Track{obj.trackrange(1)}.SetCell;
            obj.Track{obj.trackrange(1)}.CntrlObj=obj.CntrlObj;
            obj.parameters.refimg=obj.Track{obj.trackrange(1)}.CellIm; 
            obj.parameters.lastmask=obj.Track{obj.trackrange(1)}.Mask; %mask is a binary image of ellipse in the whole FOV 
            obj.parameters.im=squeeze(obj.Stack.Stack(:,:,:,obj.trackrange(1)));
            
        end
        function listenPauseEvent(obj,src,evnt)
            % obj - instance of this class
             % src - object generating event,i.e. TrackPad object
            %  evnt - the event data
            obj.Track.Interrupt=true;
            obj.Track.FindCellState='pause';
%             src.Track.Interrupt=true;
%             src.Track.FindCellState='pause';
            %             obj.Interrupt=true;
            %             obj.FindCellState='pause';
        end
        function listenStopEvent(obj,src,evnt)
            % obj - instance of this class
             % src - object generating event
            %  evnt - the event data
            obj.Interrupt=true;
            obj.FindCellState='stop';
        end
        
    end
    %end of static methods
      methods        
        function forward(obj)
            
            while (~obj.Interrupt) 
                % advance image pointer
                
                
                switch(obj.FindCellState)
                    case 'go'
                        if obj.Stack.CurrentNdx<obj.trackrange(2)
                            obj.Stack.CurrentNdx=obj.Stack.CurrentNdx+1; 
                            obj.parameters.im=squeeze(obj.Stack.Stack(:,:,:,obj.Stack.CurrentNdx)); %get current image
                        else                    
                            disp('End of track range');
                            obj.FindCellState='stop';
                            notify(obj,'EndOfTrackEvent');
                            break;
                        end
                        getrefimg(obj);  %
                        tic;
                        Result=obj.findCell;
                        toc;
%                         tic;
%                         Result=JamesTemplateMatching(obj);
%                         toc;
                        Result.ElapsedTime=toc;
                        Result.Time=now;
                        if ~isempty(Result)
                            try
                            if Result.rho<obj.parameters.confidencethreshold % takes 3 consecutive bad correlations to abort (not sure why I wrote this?)
                                obj.Interrupt=true; % terminate tracking 
                                obj.FindCellState='Lost Cell';
                            end
                            catch 
                                disp('hereweeeeeeeeeeeeeeeeeee'); %must have been for debugging when i tried to change the template matching process
                            end
                        end
                        % %                         delete(obj.CurrentEllipse); 
                        set(obj.CurrentEllipse,'Visible','off'); 

                        
                        obj.CurrentEllipse=imellipse(obj.GUIHandle.ImageHandle.Parent,Result.pos);
                        setResizable(obj.CurrentEllipse,false);
                        setColor(obj.CurrentEllipse,'b');
                        set(obj.CurrentEllipse,'PickableParts','none');% doesn't allow the user to interact with the ellipse
                        obj.Track{obj.Stack.CurrentNdx}=CellImage(obj); %CellImage object
                        obj.Track{obj.Stack.CurrentNdx}.CntrlObj=obj.CntrlObj; % allow cell image to listen to TrackPad events such as hide or show ellipses.
                        
                        obj.Track{obj.Stack.CurrentNdx}.Position=Result.pos;
%                         obj.Track{obj.Stack.CurrentNdx}.SetCell; % using
%                         ellipse tool to SetCell results in a drift error
                        SetCell(obj.Track{obj.Stack.CurrentNdx},Result.mask); % using the mask from findcell is more accurate and reliable
                        if sum(size(obj.Track{obj.Stack.CurrentNdx}.CellIm)==size(obj.Track{obj.Stack.CurrentNdx-1}.CellIm))<2
                            [r,c]=size(obj.Track{obj.Stack.CurrentNdx-1}.CellIm);
                            obj.Track{obj.Stack.CurrentNdx}.CellIm=imresize(obj.Track{obj.Stack.CurrentNdx-1}.CellIm,[r c]);
                        end
                        drawnow; % refresh screen
                        Result.FindCellState=obj.FindCellState; % update with find cell status (if cell found, remains in 'go' state)
%                         Result.mask=[];
                        obj.Track{obj.Stack.CurrentNdx}.Result=Result;
                        setmemory(obj);
                        if obj.Interrupt
%                             obj.FindCellState='Lost Cell';
                            switch(obj.FindCellState)
                                case 'Lost Cell'
                                    disp('Lost Cell');
                                    notify(obj,'LostCellEvent');
                                case 'pause'
                            end   
                        else 
                            notify(obj,'TrackEvent');
                        end 
                    case 'stop'
                        break
                    case 'pause'
                        break
                    case 'Lost Cell'
                        notify(obj,'LostCellEvent');
                        break
                    otherwise                        
                        error('FindCellState not recognised');
                end
            end
        end
        
       
        
        function SaveTrack(obj,FileName)
            for i=1:length(obj.Track)
                if ~isempty(obj.Track{i})
                    tr{i}.SelectionTime=obj.Track{i}.SelectionTime;
                    tr{i}.Mask=obj.Track{i}.Mask;
                    tr{i}=obj.Track{i}.CellIm;
                    tr{i}.ImageNumber=obj.Track{i}.ImageNumber;
                    tr{i}.Position=obj.Track{i}.Position;
                    tr{i}.Result=obj.Track{i}.Result;
                end
            end               
            save(FileName,'tr');
        end
        
%         function set.CntrlObj(obj,value)
%             obj.CntrlObj=value;
% %             addlistener(value,'StopEvent',@obj.listenStopEvent);
% %             addlistener(value,'PauseEvent',@obj.listenPauseEvent);
%             obj.StopListenerHandle=event.listener(value,'StopEvent',@obj.listenStopEvent);
%             obj.PauseListenerHandle=event.listener(value,'PauseEvent',@obj.listenPauseEvent);
%         end
        
        
        
            
    end
    
end

function setmemory(obj) %updates the NumberOfCellImages and NumberOfPriorImages
    if obj.Track{obj.Stack.CurrentNdx}.Result.rho>obj.parameters.confidencethreshold
        % number of cell images that have been acquired
        if obj.trackrange(1)<obj.trackrange(2) % forward
            NumberOfCellImages=obj.Stack.CurrentNdx-obj.trackrange(1)+1;
        else
            NumberOfCellImages=obj.trackrange(1)-obj.Stack.CurrentNdx+1;
        end
        % in
        if ((obj.parameters.NumberOfPriorImages)<NumberOfCellImages)&&...
            (length(obj.parameters.memory)>obj.parameters.NumberOfPriorImages)
            obj.parameters.NumberOfPriorImages=obj.parameters.NumberOfPriorImages+1;
        end
    else % decrement obj.parameters.NumberOfPriorImages
        if obj.parameters.NumberOfPriorImages>1
            obj.parameters.NumberOfPriorImages=obj.parameters.NumberOfPriorImages-1;
        end
    end
end
function getrefimg(obj)
    % get stack range for averaging CellIm
    %clear last refimg
    
    b=~isnan(obj.Track{obj.trackrange(1)}.CellIm); %CellIm has pixels from the ellipse
    oldrefimg=obj.parameters.refimg; %get last refimg
    try
        obj.parameters.refimg(b)=0; %turn off all pixels within the ellipse (blank slate)
    catch ME
        v=ME.message;
        stack=ME.stack;
        errordlg([v newline 'Function: ' stack(1).name ', Line: ' num2str(stack(1).line),...
            newline 'closing now'] ,'Error','modal');
        delete(findobj);% close everything down
    end
        
    if obj.parameters.NumberOfPriorImages<1   % Check if NumberOfPriorImages is zero!!
        obj.parameters.NumberOfPriorImages=1;
    end
    if obj.trackrange(1)<obj.trackrange(2) % forward
        range=(obj.Stack.CurrentNdx-obj.parameters.NumberOfPriorImages):...
            (obj.Stack.CurrentNdx-1);
        if length(range)>1 
            lastrho=obj.Track{range(end)}.Result.rho;
        end
    else
        range=(obj.Stack.CurrentNdx+1):(obj.parameters.NumberOfPriorImages+obj.Stack.CurrentNdx);
        if length(range)>1
            lastrho=obj.Track{range(1)}.Result.rho;
        end
    end
    if length(range)>1 && (obj.trackrange(1)~=obj.Stack.CurrentNdx)
        % select method to average prior cell images
        switch(obj.parameters.RefImageProtocol)
            case 'Use memory'
%                 for i=1:length(range)
%                     try
%                     obj.parameters.refimg=obj.parameters.refimg+obj.parameters.memory(i)*obj.Track{range(i)}.CellIm;
%                     catch
%                         disp('here');
%                     end
%                 end
%                 obj.parameters.refimg=obj.parameters.refimg/length(range);
obj.parameters.refimg=obj.Track{range(end)}.CellIm;
            case 'Use past rho'
                %get image weights
                Rhos=[];
                for i=1:length(range)
                    if isempty(obj.Track{range(i)}.Result)
                        Rhos(i)=0;
                    else 
                        Rhos(i)=obj.Track{range(i)}.Result.rho;
                    end
                end
                %normalise Rhos
                Rhos=Rhos-unique(min(Rhos));
                Rhos=Rhos./sum(Rhos);
                for i=1:length(range)
                    obj.parameters.refimg=obj.parameters.refimg+Rhos(i)*obj.Track{range(i)}.CellIm;
                end
%                 obj.parameters.refimg=obj.parameters.refimg*(1-obj.parameters.FractOfFirstImage) + ...
%                     obj.parameters.FractOfFirstImage*obj.Track{obj.trackrange(1)}.CellIm;
            otherwise
                Error('Unrecognised method to average prior cell images');
        end
    elseif length(range)<=1 && (obj.trackrange(1)==obj.Stack.CurrentNdx)
        try
        obj.parameters.refimg=obj.Track{range(1)}.CellIm; % first image of track - cannot use any memory so refimg is the first CellIm
        catch
            disp('here1');
        end
        
    elseif length(range)<=1 && (obj.trackrange(1)~=obj.Stack.CurrentNdx)
        lastimage=find(cellfun(@(x) ~isempty(x),obj.Track),1,'last');
        try
        obj.parameters.refimg=obj.Track{lastimage}.CellIm; % first image of track - cannot use any memory so refimg is the first CellIm
        catch
            disp('here2');
        end
        
    end   
end



