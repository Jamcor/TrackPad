function [tbl,GFP_Ims,CDT1_Ims] = getFUCCI
% Example of how to extract fluorescence from tracked pedigrees
    %% Open track file
    [file,path]=uigetfile('*.mat','load track file');
    load([path file]);
    %% get GFP directory (green channel)
    GFPPath=uigetdir(path,'Get GFP (green) channel director');
    GFPFileIDs=dir(GFPPath);
    x=strfind({GFPFileIDs(:).name},'tif'); % find tif files
    ndx=false(size(x));
    for i=1:length(x)
        ndx(i)=~isempty(x{i});
    end
    GFPFileIDs={GFPFileIDs(ndx).name};
    %% get CDT1 directory (red channel)
    CDT1Path=uigetdir(path,'Get CDT1 (red) channel directory');
    CDT1FileIDs=dir(CDT1Path);
    x=strfind({CDT1FileIDs(:).name},'tif'); % find tif files
    ndx=false(size(x));
    for i=1:length(x)
        ndx(i)=~isempty(x{i});
    end
    CDT1FileIDs={CDT1FileIDs(ndx).name};        
    %% get fluorescent images for each track
    for i=1:height(tbl)
        Positions=tbl.Position{i};
        ImageNumbers=tbl.Image_Number{i};
        GFPStats=zeros(size(Positions)); %[min,max,mean,area];
        CDT1Stats=zeros(size(Positions)); %[min,max,mean,area];
        for j=1:length(ImageNumbers)
            GFPFileID=[GFPPath '\' GFPFileIDs{ImageNumbers(j)}];
            CDT1FileID=[CDT1Path '\' CDT1FileIDs{ImageNumbers(j)}];
            GFP_Im=imread(GFPFileID);
            CDT1_Im=imread(CDT1FileID);
            % crop images
            GFP_Im=imcrop(GFP_Im,Positions(j,:));
            CDT1_Im=imcrop(CDT1_Im,Positions(j,:));
            % use GFP image to find foreground
            b=imbinarize(GFP_Im);
            % select largest blob as mask for quantifying fluorescence
            d=imcomplement(bwdist(~b));
            d=d+imcomplement(bwdist(b));
            SE=strel('disk',8);
            centre=round(size(b)/2);
            mask=false(size(b));
            mask(centre(1),centre(2))=true;
            mask=imdilate(mask,SE);
            mask=b&mask;
            d(mask)=-inf;
            w=watershed(d);
            try
                b=w==unique(w(mask));
            catch % more than one area was segmented, use the largest area               
                labels=unique(w(mask));
                area=zeros(size(labels));
                for k=1:length(labels)
                    area(k)=sum(w==labels(k),'all');
                end
                label=labels(max(area)==area);
                b=w==label;
            end
            % get pixel values
            GFP=GFP_Im(b);
            CDT1=CDT1_Im(b);
            try            
                GFP_Ims{i}(:,:,:,j)=labeloverlay(GFP_Im,boundarymask(b));
            catch
                [r,c,~,~]=size(GFP_Ims{i});
                GFP_Ims{i}(:,:,:,j)=imresize(labeloverlay(GFP_Im,boundarymask(b)),[r,c]);
            end
            try
                CDT1_Ims{i}(:,:,:,j)=labeloverlay(CDT1_Im,boundarymask(b));
            catch
                [r,c,~,~]=size(CDT1_Ims{i});
                CDT1_Ims{i}(:,:,:,j)=imresize(labeloverlay(CDT1_Im,boundarymask(b)),[r,c]);
            end
            % create image gallery to check segmentation
            
            % get stats for pixel values
            GFPStats(j,:)=[unique(min(GFP)),unique(max(GFP)),...
                mean(GFP),length(GFP)];%[min,max,mean,area];
            CDT1Stats(j,:)=[unique(min(CDT1)),unique(max(CDT1)),...
                mean(CDT1),length(CDT1)];%[min,max,mean,area];
        end
        tbl.GFP{i}=GFPStats;
        tbl.CDT1{i}=CDT1Stats; 
        disp(['Track ' num2str(i) ' of ' num2str(height(tbl))]);
    end
    uisave({'tbl','GFP_Ims','CDT1_Ims'});
end

