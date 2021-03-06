function Result=findCell(obj)
%% Find cells using the following methods
    method=obj.method;
    parameters=obj.parameters;

    switch(method)
        case 'correlation'
            Result=correlation(obj,parameters);
        case 'PCA'
            Result=PCA(obj,parameters);
        otherwise
            error('Find cell method unknown');
    end
end

function Result=correlation(trackobj,parameters)
% parameters.lastmask is a mask for the prior cell image
% parameters.lastcellimage is the last cell image
% parameters.im is the current image 
% parameters.maxradius is the maximum displacement distance (in pixels)
    try
    %get scan region
    ScanNdx=getScanRegion(trackobj,parameters);
    % restrict refimg to only those layers which are used for correlation (non
    % zero layers)
    [r,c]=ind2sub(size(parameters.im),ScanNdx);
    ScanBlock.rows=[unique(min(r)):unique(max(r))]; %sub indices to row and columns within ScanRegion
    ScanBlock.cols=[unique(min(c)):unique(max(c))];
    UsedLayers=size(parameters.im,3);
    refimg=squeeze(parameters.refimg(:,:,1:UsedLayers));
    refimgndx=find(~isnan(refimg));
    [Cellrows,Cellcols,Cellpages]=ind2sub(size(parameters.refimg),refimgndx);
    Cellrows=floor(Cellrows-(max(Cellrows)-min(Cellrows))/2);
    Cellcols=floor(Cellcols-(max(Cellcols)-min(Cellcols))/2);
    % % offset cell template so that it is in the center with positive and
    % % negative values
    if UsedLayers>1
        CellTemplate=[Cellrows Cellcols Cellpages];
    else
        CellTemplate=[Cellrows Cellcols]; %subscript indices to the non-empty pixel values within the tracking ellipse
    end
    
    %% for each displacement calculate correlation coefficient
    l=length(ScanNdx); %ScanNdx contains linear indices that reference pixels within the ScanRegion (a subset of the ellipse),%i.e. how many pixels there are in the scanregion
                        
    

    NDims=~isnan(refimg); 
    NDims=sum(NDims(:)); %total number of pixels within the reference image (e.g. NDims=711)
    [s1, s2]=size(parameters.lastmask);
    if UsedLayers>1
        offset=zeros(NDims,3);
    else
        offset=zeros(NDims,2); %same # of rows as NDims but with 2 columns
    end
    % this loop can be replaced by a GPU instruction
    data=single(zeros(NDims,l));  %an array with nrows=NDims and ncols=length of ScanNdx
    try
        GPU=gpuDevice;
        switch(GPU.Name)
            case 'Tesla C2075'
                useGPU=true;
            case 'Tesla K20c'
                useGPU=true;
            case 'GeForce GTX 960M'
                useGPU=true;
            case 'Quadro M4000'
                useGPU=true;
            otherwise
                useGPU=false;
        end
        if ~trackobj.useGPU
            useGPU=false;
        end
    catch 
        useGPU=false;
    end

    CellTemplate=repmat(CellTemplate,[1,1,l]); %make 'l' copies of the CellTemplate (equal to number of pixels within scanregion)
    if useGPU
        ScanNdx=gpuArray(ScanNdx); %copy array to GPU
        if UsedLayers>1
            [ScanNdx(:,1),ScanNdx(:,2),ScanNdx(:,3)]=GPUind2sub([s1 s2 UsedLayers],ScanNdx);
        else
            [ScanNdx(:,1),ScanNdx(:,2)]=GPUind2sub([s1 s2],ScanNdx);
        end
        ScanNdx=gather(ScanNdx); %transfer array from GPU to local workspace
    else    
        if UsedLayers>1
            [ScanNdx(:,1),ScanNdx(:,2),ScanNdx(:,3)]=ind2sub([s1 s2 UsedLayers],ScanNdx);
        else
            [ScanNdx(:,1),ScanNdx(:,2)]=ind2sub([s1 s2],ScanNdx);
        end
    end
    ScanNdx=repmat(ScanNdx,[1 1 NDims]); %creating a tiling of the ScanNdx array 
    ScanNdx=permute(ScanNdx,[3,2,1]); %rearranging the dimensions of the ScanNdx array
    region=ScanNdx+CellTemplate; 
    % remove ScanNdx pages if region outside of size of image [s1 s2]
    scanpositions=false(l,1);
    for i=1:size(region,3)
        if (sum(region(:,1,i)<1)+sum(region(:,2,i)<1)+sum(region(:,1,i)>s1)+sum(region(:,2,i)>s2))==0
            scanpositions(i)=true;
        end
    end
    % update l
    l=sum(scanpositions);
    % update region
    region=region(:,:,scanpositions);
    % update ScanNdx
    ScanNdx=ScanNdx(:,:,scanpositions);
    % updata CellTemplate
    CellTemplate=CellTemplate(:,:,scanpositions);
    rho=zeros(l,1);
    pval=zeros(l,1);
    % tricky!
    region_(:,1)=reshape(squeeze(region(:,1,:)),[l*NDims,1]);
    region_(:,2)=reshape(squeeze(region(:,2,:)),[l*NDims,1]);
    if useGPU
        region_=gpuArray(region_);
        if UsedLayers>1    
            region_=sub2ind([s1,s2],region_(:,1),region_(:,2),region(:,3));
        else
            region_=sub2ind([s1,s2],region_(:,1),region_(:,2));
        end
        region_=gather(region_);
    else
        if UsedLayers>1
            region_=sub2ind([s1,s2],region_(:,1),region_(:,2),region(:,3));
        else
            region_=sub2ind([s1,s2],region_(:,1),region_(:,2));
        end
    end
    finalregion=reshape(region_,[NDims,l]);
    data=parameters.im(finalregion);

    if UsedLayers>1
        lastcellimage=parameters.refimg(:,:,1:UsedLayers);
    else
        lastcellimage=parameters.refimg;
    end
    lastcellimage=lastcellimage(:);
    lastcellimage=lastcellimage(~isnan(lastcellimage(:)));
    if useGPU

        GPUdata=gpuArray(data);
        GPUlastcellimage=gpuArray(single(lastcellimage));
        rho=GPUgetrho(GPUdata,GPUlastcellimage);
        rho=gather(rho);
        pval=NaN(size(rho));

    else
        tic
        if parameters.isParallel
            parfor i=1:l
                [RHO,PVAL]=corrcoef(data(:,i),lastcellimage);
                % if data and lastcell image both zero rho and pval will be NaN
                if isnan(RHO(1,2))
                    rho(i)=0;
                    pval(i)=0;
                else
                    rho(i)=RHO(1,2);
                    pval(i)=PVAL(1,2);
                end
            end
        else
            for i=1:l
                [RHO,PVAL]=corrcoef(data(:,i),lastcellimage);
                % if data and lastcell image both zero rho and pval will be NaN
                if isnan(RHO(1,2))
                    rho(i)=0;
                    pval(i)=0;
                else
                    rho(i)=RHO(1,2);
                    pval(i)=PVAL(1,2);
                end
            end
        end
            
        display(['Correlation calculation time ',num2str(toc)]);
    end
   
    %% find best fit, Jane Lu or Li should look here.
    ScanNdx=squeeze(ScanNdx(1,:,:));
    ScanNdx=ScanNdx';
    if UsedLayers>1
        ScanNdx=sub2ind([s1,s2,UsedLayers],ScanNdx(:,1),ScanNdx(:,2),ScanNdx(:,3));
    else
        ScanNdx=sub2ind([s1 s2],ScanNdx(:,1),ScanNdx(:,2));
    end
    CellTemplate=CellTemplate(:,:,1);


    % find number of regional maxima
    rho_im=zeros(size(parameters.lastmask));
    rho_im(ScanNdx(:))=rho;
    rho_maxima=false(size(rho_im));
    % need to make this run faster by just looking in scan region
    sub_rho_im=rho_im(ScanBlock.rows,ScanBlock.cols);
    sub_rho_maxima=imregionalmax(sub_rho_im);
    rho_maxima(ScanBlock.rows,ScanBlock.cols)=sub_rho_maxima;
    
    CC=bwconncomp(rho_maxima);

    if CC.NumObjects>1
        disp([num2str(CC.NumObjects) ' cell candidates in search region']);
        % find maxima above confidence threshold
        j=1;
        NewPixelIdxList=[];
        for i=1:CC.NumObjects
            v=CC.PixelIdxList{i}; %get pixels for the first candidate
            if rho(ScanNdx(:)==v(1))>parameters.confidencethreshold %only selecting connected objects with length(v)=1
                NewPixelIdxList{j}=CC.PixelIdxList{i};
                j=j+1;
            end            
        end
        CC.PixelIdxList=NewPixelIdxList;
        CC.NumObjects=length(NewPixelIdxList);
        if CC.NumObjects>1 %if there are more than one candidates with rho>confidencethreshold
            % find nearest maxima to centre of scanned region (nearest neighbour)
            [r c]=ind2sub(size(parameters.lastmask),ScanNdx(:));
            centre=[(unique(max(c))+unique(min(c)))/2,(unique(max(r))+unique(min(r)))/2];
            stats=regionprops(CC,'Centroid');
            centroid=[stats(:).Centroid];
            centroid=reshape(centroid(:),2,CC.NumObjects);
            centroid=permute(centroid,[2,1]);
            d=centroid-repmat(centre,[CC.NumObjects,1]);
            d=sqrt(sum(d.^2,2));
            nneighbour=find((min(d)==d),1,'first');
            v=CC.PixelIdxList{nneighbour};
            b=ScanNdx(:)==v(1);
        else
            b=unique(max(rho))==rho;% binary index to best position
        end
    else
        b=unique(max(rho))==rho;% binary index to best position
    end
    [offset(:,1),offset(:,2)]=ind2sub(size(parameters.lastmask),ScanNdx(b));
    newrefs=CellTemplate+offset;
    ndx=sub2ind([s1 s2],newrefs(:,1),newrefs(:,2));
    Result.mask=false([s1 s2]);
    Result.mask(ndx)=true;
    Result.pos=[min(newrefs(:,2)),min(newrefs(:,1)),...
        size(trackobj.parameters.refimg,2),...
       size(trackobj.parameters.refimg,1)];
    Result.rho=rho(b);
    Result.pval=pval(b);
    disp(['Image ' num2str(trackobj.Stack.CurrentNdx) ' (' num2str(trackobj.trackrange(1))...
        '->' num2str(trackobj.trackrange(2)) '): rho = ' num2str(Result.rho)]);
    catch 
        disp('Cell outside image extents');
        trackobj.Interrupt=true;
        Result=[];
    end
end


   
    function [ScanNdx]=getScanRegion(trackobj,parameters)
    %% Create scan region
    % mask background
    % parameters.im=parameters.im.*parameters.Foreground;
%     nhoodmask=getnhood(strel('disk',parameters.searchradius,0));
    nhoodmask=strel('disk',parameters.searchradius,0).Neighborhood; %get all pixels within search radius - strel('element',R,N) if N =0 then strel will get all pixels at a maximum of R
    [R,C]=size(nhoodmask); %get size of nhoodmask
    [r,c]=ind2sub([R,C],find(nhoodmask(:))); %get subscript indices for nhoodmask>0 only
    r=r-floor(R/2); %subtract half the height
    c=c-floor(C/2); %subtract half the width
    %% Only scan foreground
    %find last image mask
    b=false(size(trackobj.Track));
    for i=1:length(trackobj.Track)
        if ~isempty(trackobj.Track{i})
            b(i)=true;
        end
    end    
    if trackobj.trackrange(1)>trackobj.trackrange(2) % if tracking backwards
        lastimagemaskndx=find(b,1,'first');
    else
        lastimagemaskndx=find(b,1,'last');
    end
    [lastmaskRows, lastmaskCols]=find(trackobj.Track{lastimagemaskndx}.Mask); %trackobj.Track.Mask (logical indices for cell mask within whole image)
    Centre(1)=round((min(lastmaskRows)+max(lastmaskRows)))/2; %get centre pixels of lastmask
    Centre(2)=round((min(lastmaskCols)+max(lastmaskCols)))/2;
    Refs=round([r+Centre(1),c+Centre(2)]); %coordinates for placing the nhoodmask centred around the lastmask
    imagesize=size(trackobj.Track{lastimagemaskndx}.Mask);
    Scanregion=false(imagesize);
    % remove Refs which are outside image
    ndx=(Refs(:,1)>0)&(Refs(:,2)>0)&(Refs(:,1)<=imagesize(1))&(Refs(:,2)<=imagesize(2));
    Refs=Refs(ndx,:);
    Scanregion(sub2ind(size(Scanregion),Refs(:,1),Refs(:,2)))=true;
    if isfield(parameters,'Foreground')
        Scanregion=Scanregion&parameters.Foreground;
    end

    try    
        ScanNdx=find(Scanregion==true);
    catch
        error('Lost cell');
    end
    end


function rho=GPUgetrho(data,lastcellimage)
%% GPU code to find rho value for a scanned region
    [r,c]=size(data);
    lastcellimage=repmat(lastcellimage,[1,c]);
    data_mean=sum(data,1)/r;
    data_mean=repmat(data_mean,[r,1]);
    data=data-data_mean;

    lastcellimage_mean=sum(lastcellimage,1)/r;
    lastcellimage_mean=repmat(lastcellimage_mean,[r,1]);
    lastcellimage=lastcellimage-lastcellimage_mean;
    rho=sum(data.*lastcellimage,1);
    rho=rho./sqrt(sum(data.^2,1))./sqrt(sum(lastcellimage.^2,1));
end

function varargout= GPUind2sub(dims,Index)
%Index is a very large vector (at least 1 million elements) that can be processed more efficiently by a
%GPU
    Index=Index(:);
    ndims=length(dims);
    n=length(Index);
    if ndims>3
        error('GPUind2sub cant handle more than 3 dimensions');
    elseif ndims==3
        if nargout~=3
            error('Not enough output arguments');
        else
            s=gpuArray(zeros(n,3));
            s(:,3)=ceil(Index./(dims(2)*dims(1)));
            residual=Index-(s(:,3)-1)*dims(2)*dims(1);
            s(:,2)=ceil(residual./dims(1));
            s(:,1)=residual-(s(:,2)-1)*dims(1);
        end
    elseif ndims==2

        if nargout~=2
            error('Not enough output arguments');
        else
            s=gpuArray(zeros(n,2));
            s(:,2)=ceil(Index./dims(1));
            s(:,1)=Index-(s(:,2)-1)*dims(1);
        end
    else
        error('size(array) = [a b ..]');
    end
    for i=1:nargout
        varargout(i)={s(:,i)};
    end
end

function index =GPUsub2ind(dims,varargin)
%varargin are very large vector (at least 1000000 elements) GPUarray that can be processed more efficiently
%by the GPU
    ndims=length(dims);
    if ndims>3
        error('GPUind2sub can''t handle more than 3 dimensions ');
    elseif ndims==3
        if nargin~=4
            error('Not enough input arguments');
        else
            index=(varargin{3}-1).*dims(2).*dims(1)+(varargin{2}-1).*dims(1)+varargin{1};
        end
    elseif ndims==2
        if nargin~=3
            error('Not enough input arguments');
        else
            index=(varargin{2}-1).*dims(1)+varargin{1};
        end
    else
        error('size(array) = [a b ..]');       

    end

end

