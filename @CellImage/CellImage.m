classdef CellImage < handle
    % CellImage object

    properties
        EllipseHandle
        ParentTracker
        Resize=true;
        SelectionTime=0;
        Mask
        CellIm
        ImageNumber
        Position
        Annotation
        AnnotationHandle
        Result=[];
        %listens to the following objects
        CntrlObj
    end
    
    
    methods
        function obj=CellImage(tracker)
            if nargin==1
                GUIHandle=tracker.GUIHandle;
                set(GUIHandle.ImageHandle,'CData',...
                    GUIHandle.ImageStack.CData(:,:,GUIHandle.ImageStack.CurrentNdx));
                colormap(GUIHandle.FigureHandle,...
                    GUIHandle.ImageStack.CMap{GUIHandle.ImageStack.CurrentNdx});
                obj.ParentTracker=tracker;
                obj.ImageNumber=tracker.Stack.CurrentNdx;
                obj.Position=tracker.parameters.startrectangle;
                obj.EllipseHandle=tracker.CurrentEllipse;
            end
        end
        
                
        function obj=SetCell(obj,mask)
            obj.SelectionTime=0;
            ImageHandle=obj.ParentTracker.GUIHandle.ImageHandle;
            if nargin==1
                %generate mask for new position using and ellipse (first
                %image of stack usually)
                obj.EllipseHandle=obj.ParentTracker.CurrentEllipse;
                BW=createMask(obj.EllipseHandle,ImageHandle); 
                if isempty(obj.Mask) % first image of track usually
                    obj.Mask=BW;
                else
                    rows=find(sum(BW,2)>0);
                    cols=find(sum(BW,1)>0);
                    offset=[rows(1),cols(1)]; % find the offset for the new mask
                    %but needs to have the same shape as mask
                    rows=find(sum(obj.Mask,2)>0);
                    cols=find(sum(obj.Mask,1)>0);
                    SmallMask=obj.Mask(rows,cols);
                    obj.Mask(:)=false; %clear 
                    r=offset(1):(offset(1)+(length(rows)-1));
                    c=offset(2):(offset(2)+(length(cols)-1));
                    obj.Mask(r,c)=SmallMask;
                    % update ParentTracker.startrectange
                    obj.ParentTracker.parameters.startrectangle=[c(1),r(1),c(end)-c(1)+1, r(end)-r(1)+1];
                end
                Im=obj.ParentTracker.Stack.Stack(:,:,1,obj.ParentTracker.Stack.CurrentNdx);
                Im(~obj.Mask)=NaN;
                rows=find(sum(obj.Mask,2)>0);
%                 rows=min(rows):(min(rows)+obj.ParentTracker.parameters.startrectangle(4)-1);
                cols=find(sum(obj.Mask,1)>0);
%                 cols=min(cols):(min(cols)+obj.ParentTracker.parameters.startrectangle(3)-1);
                obj.CellIm=Im(rows,cols,:);
                obj.Position=obj.ParentTracker.parameters.startrectangle;
            else % supply mask instead of ellipse (more accurate)
                obj.Mask=mask;
%                 obj.Mask=[]; %cell mask is also stored in obj.Result
                obj.ParentTracker.parameters.startrectangle=obj.Position;
                n=obj.ParentTracker.GUIHandle.ImageStack.CurrentNdx;
                Im=squeeze(obj.ParentTracker.GUIHandle.ImageStack.Stack(:,:,1,n));
                Im(~obj.Mask)=NaN;
                obj.CellIm=Im;
                % trim image
                rows=sum(mask,2)>0;
                cols=sum(mask,1)>0;
                obj.CellIm=obj.CellIm(rows,cols);
            end
                
            
        end
        
%         function obj=SelectCell(obj)
%            %Get input from user to set cell mask and image
%             delete(findobj('tag','imrect'));
%             h=imellipse(get(obj.ImageHandle,'Parent'),obj.ParentTracker.parameters.startrectangle);
%             setResizable(h,obj.Resize);
%             setColor(h,'r');
%             selecttimeID=tic; % time duration of user input
%             wait(h);
%             obj.SelectionTime=toc(selecttimeID);            
% 
%             %generate mask for new position
%             BW=createMask(h,obj.ImageHandle); % bug here should only be applied if Stop=False,Paws=False
%             if isempty(obj.Mask)
%                 obj.Mask=BW;
%                 r=find(sum(BW,2)>0);
%                 c=find(sum(BW,1)>0);
%                 obj.ParentTracker.parameters.startrectangle=[c(1),r(1),c(end)-c(1)+1, r(end)-r(1)+1];
%             else
%                 rows=find(sum(BW,2)>0);
%                 cols=find(sum(BW,1)>0);
%                 offset=[rows(1),cols(1)]; % find the offset for the new mask
%                 %but needs to have the same shape as mask
%                 rows=find(sum(obj.Mask,2)>0);
%                 cols=find(sum(obj.Mask,1)>0);
%                 SmallMask=obj.Mask(rows,cols);
%                 obj.Mask(:)=false; %clear 
%                 r=offset(1):(offset(1)+(length(rows)-1));
%                 c=offset(2):(offset(2)+(length(cols)-1));
%                 obj.Mask(r,c)=SmallMask;
%                 % update ParentTracker.startrectange
%                 obj.ParentTracker.parameters.startrectangle=[c(1),r(1),c(end)-c(1)+1, r(end)-r(1)+1];
%             end
%             Im=get(obj.ImageHandle,'cdata');
%             layers=size(Im,3);
%             bw=repmat(obj.Mask,[1,1,layers]);
%             Im(~bw)=NaN;
%             rows=find(sum(obj.Mask,2)>0);
%             cols=find(sum(obj.Mask,1)>0);
%             obj.CellIm=Im(rows,cols,:);
%             obj.Position=obj.ParentTracker.parameters.startrectangle;
%         end   
%         function set.CntrlObj(obj,value)
%             obj.CntrlObj=value;
%             addlistener(value,'HideEllipseEvent',@obj.listenHideEllipseEvent);
%             addlistener(value,'ShowEllipseEvent',@obj.listenShowEllipseEvent);
%             addlistener(value,'HideSymbolEvent',@obj.listenHideSymbolEvent);
%             addlistener(value,'ShowSymbolEvent',@obj.listenShowSymbolEvent);
%         end
        function listenHideEllipseEvent(obj,src,evnt)
            % obj - instance of this class
             % src - object generating event
            %  evnt - the event data
            if isvalid(obj)
                try
                set(obj.EllipseHandle,'PickableParts','none');% Doesn't allow the user to interact with ellipse
                catch
                    disp('here');
                end
                set(obj.EllipseHandle,'Visible','off');
            end
        end
        function listenShowEllipseEvent(obj,src,evnt)
            % obj - instance of this class
             % src - object generating event
            %  evnt - the event data
            if isvalid(obj)
                if (obj.ParentTracker.Stack.CurrentNdx==obj.ImageNumber)
                    set(obj.EllipseHandle,'Visible','on');
                end
            end
        end
        function listenShowSymbolEvent(obj,src,evnt)
            if isvalid(obj)
                if (obj.ParentTracker.Stack.CurrentNdx==obj.ImageNumber)
                    if ~isempty(obj.Annotation)
                        set(obj.AnnotationHandle,'Visible','on');
                    end
                end
            end
                    
        end
        function listenHideSymbolEvent(obj,src,evnt)
            if isvalid(obj)
                try
                set(obj.AnnotationHandle,'Visible','off');
                catch
                    disp('No annotation object');
                end
            end
        end
    end
    
end

