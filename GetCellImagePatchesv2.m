%returns cell image patch and crop co-ordinates

function [cellimage,relframeid,cmap,crop_coordinates]=GetCellImagePatchesv2(clone,cloneid,trackid,time,buff,channel,imageobj)

frameid=find(clone{cloneid}.TimeStamps==time); %absolute frame id
relframeid=clone{cloneid}.track{trackid}.T(:)==time; %frame id rel to cell birth

x=clone{cloneid}.track{trackid}.X(relframeid);
y=clone{cloneid}.track{trackid}.Y(relframeid);
width=clone{cloneid}.track{trackid}.Width(relframeid);
height=clone{cloneid}.track{trackid}.Height(relframeid);
buff=buff-width; %buffering centered on ellipse
x_crop=x-0.5*(buff-width);
y_crop=y-0.5*(buff-height);
width_crop=buff; height_crop=buff;

cdata=imageobj.CData(:,:,frameid); cmap=imageobj.CMap{frameid};

[r,c]=size(cdata);

if x_crop<1
    x_crop=1;
elseif x_crop+width_crop>c
    width_crop=c-x_crop;
end

if y_crop<1
    y_crop=1;
elseif y_crop+height_crop>r
    height_crop=r-y_crop;
end
crop_coordinates=[x_crop y_crop width_crop height_crop];
cellimage=ind2gray(cdata,cmap);
cellimage=imcrop(cellimage,crop_coordinates);

return
end

