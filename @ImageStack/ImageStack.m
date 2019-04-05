classdef (ConstructOnLoad=true) ImageStack < handle
    % Image stack object

    properties
        FigureHandle %Interface to importing files and mixing channels
        PathName
        FileName
        AcquisitionTimes
        Stack
        Parent %usually a GUI
        CData
        CMap
        Channels
        fhandle
        LastNdx=1;
        ImageInfo
        NumberOfImages
        Scale=1
        Thresholds=[0,100;0,100;0,100];
        Intensity=[1,1,1];
        RollingBallRadius=[10,10,10];
        
    end
    
    properties (SetObservable, AbortSet)
        CurrentNdx=1;
    end
    
    methods (Static=true) % inside getImageStackFiles.m
        obj=getImageStackFiles(ImageStackObj);
        JSliderCallback(hObject,EventData)
        AddTime2Tiff(PathName,FileName);
        im=getRGB(channel,stack);
    end

    methods
        
        function obj=ImageStack(sobj)
            if nargin==1
                obj.FigureHandle=[]; %Initialise object using saved structure instead of saved ImageStack object
                obj.PathName=sobj.PathName;
                obj.FileName=sobj.FileName;
                obj.AcquisitionTimes=sobj.AcquisitionTimes;
                obj.Stack=sobj.Stack;
                obj.Parent=[]; %usually a GUI
                obj.CData=sobj.CData;
                obj.CMap=sobj.CMap;
                obj.Channels=sobj.Channels;
                obj.fhandle=[];
                obj.ImageInfo=sobj.ImageInfo;
                obj.NumberOfImages=sobj.NumberOfImages;
                obj.Scale=sobj.Scale;
                obj.CurrentNdx=1;
            end
            
        end
       
        function getImageStack(obj)
            ImageStack.getImageStackFiles(obj); 
        end     
        
        function rescale(obj,scale)
            % rescales movie to reduce noise and increase tracking rate and
            % accuracy?
            if scale>1
                error('Scale should be less than 1');
            elseif obj.Scale~=1
                % refresh image stack
                h=waitbar(0,'Loading images...');
                for i=1:obj.NumberOfImages
                    waitbar(i/obj.NumberOfImages);
                    im=im2single(imread([obj.PathName obj.FileName{i}]));
                    s=imfinfo([obj.PathName obj.FileName{i}]);
                    obj.AcquisitionTimes{i}=s.ImageDescription;
                    obj.Stack(:,:,1,i)=im(:,:,1);
                %     disp(['Image ' num2str(i) ' of ' num2str(p)]);
              
                end
                close(h);
            end  
            scalefactor=round(1/scale);
            obj.Scale=1/scalefactor;
            h=waitbar(0,['Rescaling x ' num2str(obj.Scale)]);
            [rows,cols,p,n]=size(obj.Stack);
            R=1:scalefactor:rows;
            C=1:scalefactor:cols;
            newrows=length(R);
            newcols=length(C);
            newstack=zeros(newrows,newcols,p,n);
            [R,C]=meshgrid(R,C);
            [r,c]=meshgrid(1:1:newrows,1:1:newcols);
            R=R(:);
            C=C(:);
            r=r(:);
            c=c(:);
            for i=1:obj.NumberOfImages
                waitbar(i/obj.NumberOfImages);
                for j=1:p
                    for k=1:length(R)
                        s=obj.Stack(R(k):(R(k)+scalefactor-1),C(k):(C(k)+scalefactor-1),j,i);
                        newstack(r(k),c(k),j,i)=sum(s(:));
                    end
                end
            end
            close(h);
            newstack(newstack(:)>1)=1; % increases dynamic range and contrast intentionally
            obj.Stack=newstack; 
        end
        
        function CorrectIllumination(obj)
            mkdir([obj.PathName 'Corrected Illumination']);
            h=waitbar(0,'Saving images...');
            for i=1:obj.NumberOfImages
                h=waitbar(i/obj.NumberOfImages);
                z=obj.Stack(:,:,1,i);
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
                obj.Stack(:,:,1,i)=z; 
                FileName=[obj.PathName 'Corrected Illumination\' obj.FileName{i}];
                s=imfinfo([obj.PathName obj.FileName{i}]);
                imwrite(im2uint16(z),FileName,'Description',s.ImageDescription);
            end
            close(h);
        end
           
        function save(obj)

            subdirectory=inputdlg('Enter save subdirectory name');
            mkdir([obj.PathName subdirectory{1}]);
            h=waitbar(0,'Saving images...');
            for i=1:obj.NumberOfImages
                h=waitbar(i/obj.NumberOfImages);
                FileName=[obj.PathName subdirectory{1} '\' obj.FileName{i}];
                s=imfinfo([obj.PathName obj.FileName{i}]);
                imwrite(obj.CData(:,:,i),obj.CMap{i},FileName,'Description',s.ImageDescription);
            end
            close(h);
            close(obj.FigureHandle);
            h=waitbar(0,'Saving ImageStack object');
            save([obj.PathName subdirectory{1} '\' 'ImageStack'],'obj','-v7.3');
            close(h);
            
        end
                       
    end
    
    methods(Static=true)
        function LoadCh1(hObject,EventData,obj)            
            obj=guidata(obj.fhandle);
            obj.ch1.loadPB.Enable='off';
            [FileName,PathName,~]=uigetfile('*.tif','MultiSelect','on');
            s=imfinfo([PathName,FileName{1}]);
            if s.BitDepth==8
                IntType='uint8';
            elseif s.BitDepth==16
                IntType='uint16';
            else
                error(['BitDepth is ' num2str(s.BitDepth) '?']);
            end
            n=length(FileName);
            obj.ImageStackObj.Stack=zeros(s.Height,s.Width,1,n,IntType);
            obj.ImageStackObj.NumberOfImages=n;
            obj.CData=zeros(s.Height,s.Width,n,'uint8');
            obj.CMap=cell(n,1);
            obj.ChannelLookupTable=zeros(n,3); % look up table for linking channel images (see LoadCh2 and LoadCh3);
            try
                s=imfinfo([PathName  FileName{1}]);
                datenum(s.ImageDescription);
            catch
                ImageStack.AddTime2Tiff(PathName,FileName);
            end                
            h=waitbar(0,'Reading Ch1 images');
            for i=1:n
                s=imfinfo([PathName  FileName{i}]);
                if isfield(s,'ImageDescription')
                    obj.ch1.imfinfo(i)=s;
                else
                    delete(findobj);
                    error([PathName  FileName{i},...
                        ' does not have a timestamp field in image description. Use AddTime2Tiff to add timestamp.']);
                end                        
%                 obj.ch1.stack(:,:,1,i)=imread([PathName  FileName{i}]);
                obj.ImageStackObj.Stack(:,:,1,i)=imread([PathName  FileName{i}]);
                waitbar(i/n,h);
            end
            close(h);
            obj.ch1.pathedit.String=PathName;
            obj.ch1.filesList.String=FileName;
            guidata(obj.fhandle,obj);
            obj.ImageStackObj.LastNdx=0; % force JSliderCallback
            ImageStack.JSliderCallback(obj.fhandle,[]);
            % update obj
            obj.ch2.loadPB.Enable='on';
           
            obj.ApplyToAllImagesPB.Enable='on';
            % load ImageStack with data
            obj.ImageStackObj.PathName=PathName;
            obj.ImageStackObj.FileName=FileName;
%             obj.ImageStackObj.Stack(:,:,1,:)=obj.ch1.stack; %could we change this to include all channels in the stack using rgb instead?
            
            obj.ImageStackObj.AcquisitionTimes=cellfun(@(x) datenum(x),{obj.ch1.imfinfo(:).ImageDescription});
            obj.ch1.UniformIlluminationButton.Enable='on';
            guidata(obj.fhandle,obj);
                
        end
        
        function LoadCh2(hObject,EventData,obj)            
            obj=guidata(obj.fhandle);
            obj.ch2.loadPB.Enable='off';
            [FileName,PathName,~]=uigetfile('*.tif','MultiSelect','on');
            try
                s=imfinfo([PathName  FileName{1}]);
                datenum(s.ImageDescription);
            catch
                ImageStack.AddTime2Tiff(PathName,FileName);
            end      
            s=imfinfo([PathName,FileName{1}]);
            if s.BitDepth==8
                IntType='uint8';
            elseif s.BitDepth==16
                IntType='uint16';
            else
                error(['BitDepth is ' num2str(s.BitDepth) '?']);
            end
            n=length(FileName);
            
           % obj.ch2.stack=zeros(size(obj.ch1.stack));
%             obj.ch2.stack=zeros(s.Height,s.Width,1,n,IntType);
            
            h=waitbar(0,'Reading ch2 images');
            ch1_acquisition_times=cellfun(@(x) datenum(x),{obj.ch1.imfinfo(:).ImageDescription});
            for i=1:n
                s=imfinfo([PathName  FileName{i}]);
                if isfield(s,'ImageDescription')
                    obj.ch2.imfinfo(i)=s;
                else
                    delete(findobj);
                    error([PathName  FileName{i},...
                        ' does not have a timestamp field in image description. Use AddTime2Tiff to add timestamp.']);
                end  
                % deal to stack depending on nearest acquisition time
                t=datenum(obj.ch2.imfinfo(i).ImageDescription);
                j=find(ch1_acquisition_times<t,1,'last');
                if isempty(j)
                    j=1;
                elseif (j+1)<length(obj.ImageStackObj.FileName)&&(t-ch1_acquisition_times(j))>(ch1_acquisition_times(j+1)-t)
                    j=j+1;
                else
                    j=length(obj.ImageStackObj.FileName);
                end
%                 obj.ch2.stack(:,:,1,i)=imread([PathName  FileName{i}]); %%%%%%%%%%
                obj.ChannelLookupTable(j,2)=i;
                waitbar(i/n,h);
            end
            close(h);
            obj.ch2.pathedit.String=PathName;
            %FileName{end+1}='No file';
            obj.ch2.filesList.String=FileName;
            guidata(obj.fhandle,obj);
            ImageStack.JSliderCallback(obj.fhandle,[]);
            % update obj
            
            obj.ch3.loadPB.Enable='on';
            obj.ch2.UniformIlluminationButton.Enable='on';
%             obj.ImageStackObj.Stack(:,:,2,:)=obj.ch2.stack;
            guidata(obj.fhandle,obj);
                
        end
        
        function LoadCh3(hObject,EventData,obj)           
            obj=guidata(obj.fhandle);
            obj.ch3.loadPB.Enable='off';
            [FileName,PathName,~]=uigetfile('*.tif','MultiSelect','on');
            try
                s=imfinfo([PathName  FileName{1}]);
                datenum(s.ImageDescription);
            catch
                ImageStack.AddTime2Tiff(PathName,FileName);
            end      
            s=imfinfo([PathName,FileName{1}]);
            if s.BitDepth==8
                IntType='uint8';
            elseif s.BitDepth==16
                IntType='uint16';
            else
                error(['BitDepth is ' num2str(s.BitDepth) '?']);
            end
            n=length(FileName);
%             obj.ch3.stack=zeros(size(obj.ch1.stack));
%             obj.ch3.stack=zeros(s.Height,s.Width,1,n,IntType);
            h=waitbar(0,'Reading ch3 images');
            ch1_acquisition_times=cellfun(@(x) datenum(x),{obj.ch1.imfinfo(:).ImageDescription});
            for i=1:n
                s=imfinfo([PathName  FileName{i}]);
                if isfield(s,'ImageDescription')
                    obj.ch3.imfinfo(i)=s;
                else
                    delete(findobj);
                    error([PathName  FileName{i},...
                        ' does not have a timestamp field in image description. Use AddTime2Tiff to add timestamp.']);
                    
                end  
                % deal to stack depending on nearest acquisition time
                t=datenum(obj.ch3.imfinfo(i).ImageDescription);
                j=find(ch1_acquisition_times<t,1,'last');
                if isempty(j)
                    j=1;
                elseif (j+1)<length(obj.ImageStackObj.FileName)&&(t-ch1_acquisition_times(j))>(ch1_acquisition_times(j+1)-t)
                    j=j+1;
                else
                    j=length(obj.ImageStackObj.FileName);
                end
%                 obj.ch3.stack(:,:,1,i)=imread([PathName  FileName{i}]);
                obj.ChannelLookupTable(j,3)=i;
                waitbar(i/n,h);
            end
            close(h);
            obj.ch3.pathedit.String=PathName;
            %FileName{end+1}='No file';
            obj.ch3.filesList.String=FileName;
            guidata(obj.fhandle,obj);
            ImageStack.JSliderCallback(obj.fhandle,[]);
            % update obj
            obj.ch3.UniformIlluminationButton.Enable='on';
%             obj.ImageStackObj.Stack(:,:,3,:)=obj.ch3.stack;
            guidata(obj.fhandle,obj);
                
        end
        
        function CorrectCh1Illum(hObject,EventData)
            obj=guidata(findobj('Name','Channel mixer'));
            mkdir([obj.ch1.pathedit.String 'Corrected Illumination']);
            n=size(obj.ImageStackObj.Stack,4);
            obj.ch1.UniformIlluminationButton.Enable='off';
            Filename=[obj.ch1.pathedit.String  ...
                obj.ch1.filesList.String{obj.ch1.filesList.Value}];
            
            cont=true;
            skip=false;
            while cont
                z=imread(Filename);
                radius=obj.ImageStackObj.RollingBallRadius(1);
                disk=strel('disk',radius,0);
                bkgnd=imerode(z,disk);
                bkgnd=imgaussfilt(bkgnd,2*radius);
                v=double(z-bkgnd+mean(bkgnd(:)));
                            %adjust for lower and upper threshold and intensity
                min_v=0;
                  % adjust for intensity
                v=v*double(obj.ch1.IntensitySlider.Value);
                try
                max_v=2^obj.ch1.imfinfo(1).BitDepth-1;
                diff=max_v-min_v;    
                lo=min_v+diff*double(obj.ch1.DualThresholdSlider.LowValue)/100;
                hi=min_v+diff*double(obj.ch1.DualThresholdSlider.HighValue)/100;
                v=mat2gray(v,[lo hi]);
                catch
                    disp('here');
                end
              
                [r,c]=size(v);
                im=zeros(r,c,3);
                Colour=obj.ch1.colourlist.String{obj.ch1.colourlist.Value};
                switch(Colour)
                    case 'phase/DIC'
                        im(:,:,1)=v;
                        im(:,:,2)=v;
                        im(:,:,3)=v;
                    case 'green'
                        im(:,:,2)=v;
                    case 'red'
                        im(:,:,1)=v;
                    case 'blue'
                        im(:,:,3)=v;
                    case 'yellow' % red and green channel
                        im(:,:,1)=v;
                        im(:,:,2)=v;
                end
                % write to image 
                im(im(:)>1)=1; % remove anything brighter than 1
                [image,CMap]=rgb2ind(im,256);
                obj.image.CData=image;
                colormap(CMap); 
                drawnow;
                answer=questdlg(['Change rolling ball filter radius (' num2str(obj.ImageStackObj.RollingBallRadius(1)) ')?']);
                switch(answer)
                    case 'Yes'
                        radius=inputdlg('Rolling ball radius (just larger than smallest foreground feature)',...
                            'Background equalisation',1,{num2str(obj.ImageStackObj.RollingBallRadius(1))});
                        obj.ImageStackObj.RollingBallRadius(1)=str2double(radius{1});
                    case 'No'
                        cont=false;
                        skip=false;
                    case 'Cancel'
                        skip=true;
                        cont=false;
                end
            end
            %
            if ~skip
                h=waitbar(0,'Correcting Ch1 Illumination');
                for i=1:n
                    z=squeeze(obj.ImageStackObj.Stack(:,:,1,i));
                    bkgnd=imerode(z,disk);
                    bkgnd=imgaussfilt(bkgnd,2*radius);
                    z=z-bkgnd+mean(bkgnd(:));
                    typestr=class(z);
%                     [r, c]=size(z);
%                     [X, Y]=meshgrid(1:c,1:r);
%                     sf=fit([Y(:),X(:)],double(z(:)),'poly33');
%                     bkgnd=sf(Y,X);
%                     Zhat=double(z)-bkgnd+unique(mean(bkgnd(:)));
%                     Zhat(Zhat<0)=0;
%     %                 %normalise intensity;
%                     if mx~=0
%                         z=Zhat./mx;
%                     end
                    switch(typestr)
                        case 'uint8'
                            obj.ImageStackObj.Stack(:,:,1,i)=im2uint8(z);
                        case 'uint16'
                            obj.ImageStackObj.Stack(:,:,1,i)=im2uint16(z);
                        otherwise
                            obj.ImageStackObj.Stack(:,:,1,i)=z;
                    end
    %                 obj.ch1.filesList.Value=i;
                    guidata(obj.fhandle,obj);                
%                     ImageStack.JSliderCallback(obj.fhandle,[]);
%                     drawnow;
                    % update obj
                    guidata(obj.fhandle,obj);
                    FileName=[obj.ch1.pathedit.String 'Corrected Illumination\' obj.ch1.filesList.String{i}];
                    s=imfinfo([obj.ch1.pathedit.String obj.ch1.filesList.String{i}]);
                    imwrite(squeeze(obj.ImageStackObj.Stack(:,:,1,i)),FileName,'Description',...
                        s.ImageDescription);
                    waitbar(i/n,h);
                end
                close(h);
            end
        end
        
        function CorrectCh2Illum(hObject,EventData)
            obj=guidata(findobj('Name','Channel mixer'));
            mkdir([obj.ch2.pathedit.String 'Corrected Illumination']);
            n=length(obj.ch2.imfinfo);
            obj.ch2.UniformIlluminationButton.Enable='off';
            Filename=[obj.ch2.pathedit.String  ...
                obj.ch2.filesList.String{obj.ch2.filesList.Value}];
            cont=true;
            skip=false;
            while cont  
                z=imread(Filename);
                radius=obj.ImageStackObj.RollingBallRadius(2);
                disk=strel('disk',radius,0);
                bkgnd=imerode(z,disk);
                bkgnd=imgaussfilt(bkgnd,2*radius);
                v=double(z-bkgnd+mean(bkgnd(:)));
                            %adjust for lower and upper threshold and intensity
                min_v=0;
                v=v*double(obj.ch2.IntensitySlider.Value);
                try
                max_v=2^obj.ch2.imfinfo(1).BitDepth-1;
                diff=max_v-min_v;    
                lo=min_v+diff*double(obj.ch2.DualThresholdSlider.LowValue)/100;
                hi=min_v+diff*double(obj.ch2.DualThresholdSlider.HighValue)/100;
                v=mat2gray(v,[lo hi]);
                catch
                    disp('here');
                end
                % adjust for intensity
               
                [r,c]=size(v);
                im=zeros(r,c,3);
                Colour=obj.ch1.colourlist.String{obj.ch2.colourlist.Value};
                switch(Colour)
                    case 'phase/DIC'
                        im(:,:,1)=v;
                        im(:,:,2)=v;
                        im(:,:,3)=v;
                    case 'green'
                        im(:,:,2)=v;
                    case 'red'
                        im(:,:,1)=v;
                    case 'blue'
                        im(:,:,3)=v;
                    case 'yellow' % red and green channel
                        im(:,:,1)=v;
                        im(:,:,2)=v;
                end
                im=im+ImageStack.getRGB(obj.ch1,obj.ImageStackObj.Stack); 
                im(im(:)>1)=1; % remove anything brighter than 1
                [image,CMap]=rgb2ind(im,256);
                obj.image.CData=image;
                colormap(CMap);
                drawnow;
                answer=questdlg(['Change rolling ball filter radius (' num2str(obj.ImageStackObj.RollingBallRadius(2)) ')?']);
                switch(answer)
                    case 'Yes'
                        radius=inputdlg('Rolling ball radius (just larger than smallest foreground feature)',...
                            'Background equalisation',1,{num2str(obj.ImageStackObj.RollingBallRadius(2))});
                        obj.ImageStackObj.RollingBallRadius(3)=str2double(radius{1});
                    case 'No'
                        cont=false;
                        skip=false;
                    case 'Cancel'
                        skip=true;
                        cont=false;
                end
            end
            if ~skip
                h=waitbar(0,'Correcting Ch2 Illumination');
                for i=1:n
                    z=imread(obj.ch2.imfinfo(i).Filename);
                    bkgnd=imerode(z,disk);
                    bkgnd=imgaussfilt(bkgnd,2*radius);
                    z=z-bkgnd+mean(bkgnd(:));
                    typestr=class(z);                    
                    FileName=[obj.ch2.pathedit.String 'Corrected Illumination\' obj.ch2.filesList.String{i}];
                    s=imfinfo([obj.ch2.pathedit.String obj.ch2.filesList.String{i}]);
                    obj.ch2.imfinfo(i).Filename=FileName; % rename using Correct illumination directory
                    switch(typestr)
                        case 'uint8'
                        imwrite(im2uint8(z),FileName,'Description',...
                            s.ImageDescription);
                        case 'uint16'
                        imwrite(im2uint16(z),FileName,'Description',...
                            s.ImageDescription);
                        otherwise
                        imwrite(z,FileName,'Description',...
                            s.ImageDescription);
                    end
                    guidata(obj.fhandle,obj);                
                    waitbar(i/n,h);
                end
                close(h);
            end
        end
        
        function CorrectCh3Illum(hObject,EventData)
            obj=guidata(findobj('Name','Channel mixer'));
            mkdir([obj.ch3.pathedit.String 'Corrected Illumination']);
            n=length(obj.ch3.imfinfo);
            obj.ch3.UniformIlluminationButton.Enable='off';
            Filename=[obj.ch3.pathedit.String  ...
                obj.ch3.filesList.String{obj.ch3.filesList.Value}];
            cont=true;
            skip=false;
            while cont
                z=imread(Filename);
                radius=obj.ImageStackObj.RollingBallRadius(3);
                disk=strel('disk',radius,0);
                bkgnd=imerode(z,disk);
                bkgnd=imgaussfilt(bkgnd,2*radius);
                v=double(z-bkgnd+mean(bkgnd(:)));
                            %adjust for lower and upper threshold and intensity
                min_v=0;
                v=v*double(obj.ch3.IntensitySlider.Value);
                try
                max_v=2^obj.ch3.imfinfo(1).BitDepth-1;
                diff=max_v-min_v;    
                lo=min_v+diff*double(obj.ch3.DualThresholdSlider.LowValue)/100;
                hi=min_v+diff*double(obj.ch3.DualThresholdSlider.HighValue)/100;
                v=mat2gray(v,[lo hi]);
                catch
                    disp('here');
                end
                % adjust for intensity
               
                [r,c]=size(v);
                im=zeros(r,c,3);
                Colour=obj.ch3.colourlist.String{obj.ch3.colourlist.Value};
                switch(Colour)
                    case 'phase/DIC'
                        im(:,:,1)=v;
                        im(:,:,2)=v;
                        im(:,:,3)=v;
                    case 'green'
                        im(:,:,2)=v;
                    case 'red'
                        im(:,:,1)=v;
                    case 'blue'
                        im(:,:,3)=v;
                    case 'yellow' % red and green channel
                        im(:,:,1)=v;
                        im(:,:,2)=v;
                end
                % write to image 
                im=im+ImageStack.getRGB(obj.ch1,obj.ImageStackObj.Stack);
                im=im+ImageStack.getRGB(obj.ch2,obj.ImageStackObj.Stack);
                im(im(:)>1)=1; % remove anything brighter than 1
                [image,CMap]=rgb2ind(im,256);
                obj.image.CData=image;
                colormap(CMap);
                drawnow;
                answer=questdlg(['Change rolling ball filter radius (' num2str(obj.ImageStackObj.RollingBallRadius(3)) ')?']);
                switch(answer)
                    case 'Yes'
                        radius=inputdlg('Rolling ball radius (just larger than smallest foreground feature)',...
                            'Background equalisation',1,{num2str(obj.ImageStackObj.RollingBallRadius(3))});
                        obj.ImageStackObj.RollingBallRadius(3)=str2double(radius{1});
                    case 'No'
                        cont=false;
                        skip=false;
                    case 'Cancel'
                        skip=true;
                        cont=false;
                end
            end
            if ~skip
                h=waitbar(0,'Correcting Ch3 Illumination');
                for i=1:n
                    z=imread(obj.ch3.imfinfo(i).Filename);
                    bkgnd=imerode(z,disk);
                    bkgnd=imgaussfilt(bkgnd,2*radius);
                    z=z-bkgnd+mean(bkgnd(:));
                    typestr=class(z);                
                    FileName=[obj.ch3.pathedit.String 'Corrected Illumination\' obj.ch2.filesList.String{i}];
                    s=imfinfo([obj.ch3.pathedit.String obj.ch3.filesList.String{i}]);
                    obj.ch3.imfinfo(i).Filename=FileName; % rename using Correct illumination directory
                    switch(typestr)
                        case 'uint8'
                        imwrite(im2uint8(z),FileName,'Description',...
                            s.ImageDescription);
                        case 'uint16'
                        imwrite(im2uint16(z),FileName,'Description',...
                            s.ImageDescription);
                        otherwise
                        imwrite(z,FileName,'Description',...
                            s.ImageDescription);
                    end
    %                 obj.ch3.filesList.Value=i;
    %                 obj.ch1.fileList.Value=find(obj.ChannelLookupTable(:,3)==i);
                    guidata(obj.fhandle,obj);                
                    ImageStack.JSliderCallback(obj.fhandle,[]);
                    drawnow;
                    % update obj
                    guidata(obj.fhandle,obj);
                     waitbar(i/n,h);
                end
                close(h);
            end
            
        end
        
        
        function ColourListCallback(hObject,EventData,obj)
            obj=guidata(obj.fhandle);
            ImageStack.JSliderCallback(obj.fhandle,[]);
            guidata(obj.fhandle,obj);
        end
        
        function FileslistCallback(hObject,EventData)
            obj=guidata(findobj('Name','Channel mixer'));
            if ~isempty(obj.ch2.filesList.String)
                n=obj.ChannelLookupTable(obj.ch1.filesList.Value,2);
                obj.ch2.filesList.Value=n;
%                 if n>0
%                     obj.ch2.filesList.Value=n;
%                 else
%                     obj.ch2.filesList.Value=length(obj.ch2.filesList.String);
%                 end
            end

            if ~isempty(obj.ch3.filesList.String)
                n=obj.ChannelLookupTable(obj.ch1.filesList.Value,3);
                obj.ch3.filesList.Value=n;
%                 if n>0
%                     obj.ch3.filesList.Value=n;
%                 else
%                     obj.ch3.filesList.Value=length(obj.ch3.filesList.String);
%                 end
            end
            obj.ImageStackObj.LastNdx=0; % force JSliderCallback
            ImageStack.JSliderCallback(obj.fhandle,[])
        end
        
        function ApplyMixerToAllImages(hObject,EventData)
            obj=guidata(findobj('Name','Channel mixer'));
            n=length(obj.ImageStackObj.FileName);
            for i=1:n
                obj=guidata(obj.fhandle);
                obj.ch1.filesList.Value=i;
                ImageStack.FileslistCallback(obj.fhandle,[]);
                obj=guidata(obj.fhandle);
                drawnow;
            end
            obj.OKPB.Enable='on';
            guidata(obj.fhandle,obj);
        end
        
        function Finish(hObject,EventData,~)
            obj=guidata(findobj('Name','Channel mixer'));
            obj.ImageStackObj.CData=obj.CData;
            obj.ImageStackObj.CMap=obj.CMap;
            obj.ImageStackObj.Stack=single(mat2gray(obj.ImageStackObj.Stack));
            obj.ImageStackObj.FigureHandle=obj.fhandle;
            obj.fhandle.Visible='off';
            obj.ImageStackObj.save;
            
        end
            
    end
       
end
    
   



