classdef segment < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        im
        newim
        threshold=[3/256,1]
        MinCellDiameter=10
        MaxCellDiameter=40
        StartRectangles
        himage
        diskradius=4;
    end
    
    methods
        function obj=segment(im)
            % class of im must be double or single
            switch(class(im))
                case 'single'
                case 'double'
                otherwise
                    disp('Image is not a double or single, Converting to a grey scale image');
                    im=mat2gray(im);
            end
            obj.im=im;
            obj.newim={im};
            figure('Name','Cell image viewer');
            obj.himage=imshow(im,[]);
            set(obj.himage,'ButtonDownFcn',@(src,event) image_button_down(src,event,obj));
            
        end
        
        function CorrectIllumination(obj)          
        % Flattens background intensity using polynomial surface fit
        %  Outputs a RGB image
        z=obj.newim{end};
        [r, c]=size(z);
        [X, Y]=meshgrid(1:c,1:r);
        sf=fit([Y(:),X(:)],z(:),'poly33');
        bkgnd=sf(Y,X);
        Zhat=double(z)-bkgnd;
        Zhat(Zhat<0)=0;
        %normalise intensity;
        mx=unique(max(Zhat(:)));
        if mx~=0
            Zhat=Zhat./mx;
        end
        %convert to array
        z(:,:)=reshape(Zhat,r,c);
        obj.newim{end+1}=z;  
        end
        
        function ClearRectangles(obj)
            % removes prior rectangles from image
            obj.StartRectangles=[];
            h=findobj('Type','rectangle');
            for i=1:length(h)
                delete(h(i));
            end 
        end
            
        
        function SelectThreshold(obj)
            set(obj.himage,'cdata',obj.newim{end});
%             imshow(obj.newim{end},[],'Parent',get(obj.himage,'Parent'));
            h=imcontrast(get(obj.himage,'Parent'));
            prompt={'min where min<image:','max where max>image:'};
            def={num2str(obj.threshold(1)),num2str(obj.threshold(2))};
            options.Resize='on';
            options.WindowStyle='normal';
            options.Interpreter='tex';
            answer=inputdlg(prompt,...
                'Threshold selection',1,def,options);
            delete(h);
%             close(get(get(him,'Parent'),'Parent'));
            
            obj.threshold(1)=str2double(answer{1});
            obj.threshold(2)=str2double(answer{2});
            % create binary image
            obj.newim{end+1}=(obj.newim{end}>obj.threshold(1))&(obj.newim{end}<obj.threshold(2));
            set(obj.himage,'cdata',obj.newim{end});                
        end
        
        function closeimage(obj,n)
            switch(class(obj.newim{end}))
                case 'logical'
                    if nargin==2
                        obj.newim{end+1}=bwmorph(obj.newim{end},'close',n);
                    else
                       obj.newim{end+1}=bwmorph(obj.newim{end},'close'); 
                    end
                otherwise
                    disp('Last image was not a logical class');
            end
        end
        
        function openimage(obj,n)
            switch(class(obj.newim{end}))
                case 'logical'
                    if nargin==2
                        obj.newim{end+1}=bwmorph(obj.newim{end},'open',n);
                    else
                        obj.newim{end+1}=bwmorph(obj.newim{end},'open');
                    end
                otherwise
                    disp('Last image was not a logical class');
            end
        end
        
        function selectcells(obj)
            % select cell rectangles from segmented image
            ClearRectangles(obj);
            switch(class(obj.newim{end}))
                case 'logical'
                    %select blobs which have a diameter between min and
                    %max cell diameter
                    cc=bwconncomp(obj.newim{end});
                    Stats=regionprops(cc,'BoundingBox','Centroid');
                    s=[Stats(:).BoundingBox];
                    c=[Stats(:).Centroid];
                    s=reshape(s,4,length(s)/4);
                    s=s';
                    c=reshape(c,2,length(c)/2);
                    c=c';
                    b=(s(:,3)>=obj.MinCellDiameter)&(s(:,4)>=obj.MinCellDiameter);
                    b=b&(s(:,3)<=obj.MaxCellDiameter)&(s(:,4)<=obj.MaxCellDiameter);
                    s=s(b,:);
                    c=c(b,:);
                    % set aspect ratio of each box to 1
                    sidelength=max(s(:,3:4),[],2);
                    s(:,3:4)=repmat(sidelength,[1,2]);
                    s(:,1)=c(:,1)-sidelength/2;
                    s(:,2)=c(:,2)-sidelength/2;
                    % remove rectangles beyond extents of image
                    isbeyondextents=(s(:,2)+s(:,4)-2)>size(obj.im,1); %y max
                    isbeyondextents=isbeyondextents|(s(:,2)-1<1); % y min
                    isbeyondextents=isbeyondextents|(s(:,1)+s(:,4)-2)>size(obj.im,2); % x max
                    isbeyondextents=isbeyondextents|(s(:,1)-2<1); % x min
                    s=s(~isbeyondextents,:);
                    s=round(s);
                    % for each cell create a rectangle
                    set(obj.himage,'cdata',obj.newim{2})
%                     him=imshow(obj.newim{2},[]); % adjusted for uneven illumination
                    imcontrast(get(obj.himage,'Parent'));
                    for i=1:size(s,1)
                        obj.StartRectangles(i).position=s(i,:);
                        rectangle('Position',s(i,:),...
                            'Curvature',[1,1],'Parent',get(obj.himage,'Parent'),...
                            'EdgeColor','r',...
                            'ButtonDownFcn',@(src,event) button_down(src,event,obj,i));
                    end
                    % create a save dialog
                    isediting=true;
                    while isediting 
                        h=msgbox('Do you want to finish editing?','Editing elipses','warn');
                        uiwait(h);                       
                        isediting=false;
                        prompt='Enter file name';
                        dlg_title='Save start rectangle file';
                        num_lines=[1,20];
                        options.Resize='on';
                        options.WindowStyle='normal';
                        options.Interpreter='none';
                        defAns={'StartRectangles.mat'};
                        answer=inputdlg(prompt,dlg_title,num_lines,defAns,options);                        
                        s=[obj.StartRectangles(:).position];
                        s=reshape(s,4,length(s)/4);
                        s=s';
                        b=isnan(s);
                        s=s(~b(:,1),:);
                        obj.StartRectangles=[];
                        for i=1:size(s,1)
                            obj.StartRectangles(i).position=s(i,:);
                        end
                        save([cd '\' answer{1}],'s');                     
                                
                    end

                otherwise
                    disp('Last image was not a logical class');
            end
        
        end
        

        function loadcells(obj)
            % load rectangles from file
            ClearRectangles(obj)
            [FileName,PathName,FilterIndex] = uigetfile('*.mat','Get StartRectangles');
            s=load([PathName FileName]);
            s=s.s;
            % for each cell create a rectangle
%             him=imshow(obj.newim{2},[]); % adjusted for uneven illumination
%             imcontrast(him);
            set(obj.himage,'cdata',obj.newim{1})
            imcontrast(get(obj.himage,'Parent'));
            obj.StartRectangles=[];
            for i=1:size(s,1)
                obj.StartRectangles(i).position=s(i,:);
                rectangle('Position',s(i,:),...
                    'Curvature',[1,1],'Parent',get(obj.himage,'Parent'),...
                    'EdgeColor','r',...
                    'ButtonDownFcn',@(src,event) button_down(src,event,obj,i));
            end
            % create a save dialog
            isediting=true;
            while isediting
                h=msgbox('Do you want to finish editing?','Editing elipses','warn');
                uiwait(h);
                isediting=false;
                prompt='Enter file name';
                dlg_title='Save start rectangle file';
                num_lines=[1,20];
                options.Resize='on';
                options.WindowStyle='normal';
                options.Interpreter='none';
                defAns={'StartRectangles.mat'};
                answer=inputdlg(prompt,dlg_title,num_lines,defAns,options);
                s=[obj.StartRectangles(:).position];
                s=reshape(s,4,length(s)/4);
                s=s';
                b=isnan(s);
                s=s(~b(:,1),:);
                obj.StartRectangles=[];
                for i=1:size(s,1)
                    obj.StartRectangles(i).position=s(i,:);
                end
                save([cd '\' answer{1}],'s');
            end
        end
        
        function dilateimage(obj)
            disk=strel('disk',obj.diskradius);
            obj.newim{end+1}=imdilate(obj.newim{end},disk);
        end

        function getregionalmaxima(obj)
            obj.newim{end+1}=imregionalmax(obj.newim{end});
        end
        
        
        
        
        function getnuclei(obj)
            % only works with H2 GFP nuclei
            % starts with raw image
            CorrectIllumination(obj);
            dilateimage(obj);
            DilatedImage=obj.newim{end};
            SelectThreshold(obj);
            Foreground=obj.newim{end};
            DilatedImage(~Foreground)=0;
            obj.newim{end+1}=DilatedImage;
            getregionalmaxima(obj);
            cellseeds=obj.newim{end};
            
            %invert image
            DilatedImage=1-DilatedImage; % background is 1
            DilatedImage=imimposemin(DilatedImage,cellseeds);
            DilatedImage(~Foreground)=0;
            DilatedImage(isinf(DilatedImage))=0;
            obj.newim{end+1}=watershed(DilatedImage);
            SegmentedImage=obj.newim{end};
            % remove background segmented regions
            cc=bwconncomp(cellseeds);
            FinalMask=false(size(SegmentedImage));
            for i=1:cc.NumObjects
                ndx=cc.PixelIdxList{i};                
                if SegmentedImage(ndx(1))~=1 % 1 is always the background
                    region=(SegmentedImage(ndx(1))==SegmentedImage);
                    FinalMask=FinalMask|region;
                end
            end
            obj.newim{end+1}=FinalMask;               
            selectcells(obj);
            
            
        end
       
        
           
            
    end
    
end

function button_down(src,event,obj,id)
% src - the object that is the source of the event
% event
    delete(src)
    obj.StartRectangles(id).position=NaN(1,4);
end

function image_button_down(src,event,obj)
    h=imellipse(get(src,'Parent'));
    position=wait(h);
    delete(h);
    x=unique(min(position(:,1)));
    y=unique(min(position(:,2)));
    width=round(unique(max(position(:,1)))-x);
    height=round(unique(max(position(:,2)))-y);
    if (width>0)&&(height>0)
        obj.StartRectangles(end+1).position=[x,y,width,height];
        rectangle('Position',[x,y,width,height],...
            'Curvature',[1,1],'Parent',get(src,'Parent'),...
            'EdgeColor','r',...
            'ButtonDownFcn',@(src,event) button_down(src,event,obj,length(obj.StartRectangles)));
    end
end



