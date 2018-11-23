%this function will return cellimage (an intensity image) for individual
%cells in each frame given the pixel coordinates of  clone.track.CellMask
%or a set of pixellists (from Regionprops)
%inputs are clone file, cloneid, trackid, time(timestamp of the image file)
%and buff (an integer specifiying the number of pixels to add to CellMask)

function [cellimage,relframeid,cmap]=GetCellImagePatches(clone,cloneid,trackid,time,buff,channel,imageobj)

   frameid=find(clone{cloneid}.TimeStamps==time); %absolute frame id 
   relframeid=clone{cloneid}.track{trackid}.T(:)==time; %frame id rel to cell birth


x=clone{cloneid}.track{trackid}.X(relframeid);
y=clone{cloneid}.track{trackid}.Y(relframeid);
width=clone{cloneid}.track{trackid}.Width(relframeid);
height=clone{cloneid}.track{trackid}.Height(relframeid);
I=zeros(height*width,1); J=I;
    k=1;
    r=x;
c=y:y+height-1;
for i=1:width
    J(k:height*i)=r;
    I(k:height*i)=c;
    r=r+1;
    k=k+height;
end


%calculating increased height, width, and overall size, given magnitude of 'buff'
if sum(I(:)<0)>=1
    height=max(I)-min(I); width=max(J)-min(J);
    rowbuff=ceil(abs(buff-height)/2); colbuff=ceil(abs(buff-width)/2);
    rowstart=1; colstart=min(J)-floor(0.5*colbuff);
    width=width+colbuff; height=height+rowbuff;
    impatchsize=width*height;
elseif sum(J(:)<0)>=1
    height=max(I)-min(I); width=max(J)-min(J);
    rowbuff=ceil(abs(buff-height)/2); colbuff=ceil(abs(buff-width)/2);
    rowstart=min(I)-ceil(0.5*rowbuff); colstart=1;
    width=width+colbuff; height=height+rowbuff;
    impatchsize=width*height;
else
    height=max(I)-min(I); width=max(J)-min(J);
    rowbuff=ceil(abs(buff-height)/2); colbuff=ceil(abs(buff-width)/2);
    rowstart=min(I)-ceil(0.5*rowbuff); colstart=min(J)-floor(0.5*colbuff);
    width=width+colbuff; height=height+rowbuff;
    if width~=height
        if width<height
            height=width;
        elseif height<width
            width=height;
        end
    end
    impatchsize=width*height;
end
if min(I)<rowbuff
    rowstart=1;
end
if min(J)<colbuff
    colstart=1;
end

cdata=imageobj.CData(:,:,frameid); cmap=imageobj.CMap{frameid};

[r,c]=size(cdata);

I=zeros(1,height); J=zeros(1,width);
%get linear indices for cellimage and truncate if near image border
I = (rowstart:(rowstart+height-1))'; I(I>r)=r;
J = (colstart:(colstart+width-1))'; J(J>c)=c;

%filename will come from clonefile
cellimage=cdata(I,J);
cellimage=imresize(cellimage,[height width]);

% imageinfo=imfinfo([filepath '\Frame ' num2str(frameid) '.tif']);
% FrameText=(['Frame ' num2str(frameid)]);
% cellimage=insertText(cellimage,[20 20],FrameText,'FontSize',12,'BoxOpacity',0,'TextColor','white');
% DateText=imageinfo.ImageDescription;
% cellimage=insertText(cellimage,[height-20 width-20],DateText,'FontSize',12,'BoxOpacity',0,'TextColor','white');
return
end

