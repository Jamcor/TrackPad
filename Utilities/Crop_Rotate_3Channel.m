function Crop_Rotate_3Channel
% Crop and Rotate Image
[FileNamePH,PathNamePH,FilterIndex] = uigetfile('*.tif','Get Phase image stack','MultiSelect','on');
mkdir([PathNamePH '\ Cropped']);
[FileNameGFP,PathNameGFP,FilterIndex] = uigetfile('*.tif','Get GFP Channel image stack','MultiSelect','on');
mkdir([PathNameGFP '\ Cropped']);
[FileNameMC,PathNameMC,FilterIndex] = uigetfile('*.tif','Get MC Channel image stack','MultiSelect','on');
mkdir([PathNameMC '\ Cropped']);
answer=inputdlg({'Rotation Angle (Image will be rotated as per ImageJ angular rotation'});
NegAng=str2num(answer{1});
Ang=-NegAng;
ImageStackLen=length(FileNamePH);
im = imread([PathNamePH FileNamePH{1}]);
Rotated_Image = imrotate(im,Ang,'bilinear');
% imshow(Rotated_Image);
% close all;
    [I2, rect] = imcrop(Rotated_Image);
    close all;
for i=1:ImageStackLen
    im = imread([PathNamePH FileNamePH{i}]);
%     brightness=0.1;
%     FixPCImage( im, brightness );
    R_Im = imrotate(im,Ang,'bilinear');
    Im=imcrop(R_Im,rect);
    Destination= [PathNamePH '\ Cropped']; 
    imwrite(Im,[Destination '\Image' sprintf('%05d',i) '.tif'],'tif');
    display(['Image ' num2str(i) ' of ' num2str(length(FileNamePH))]);
end
display('Second Mcherry Channel started');
ImageStackLen=length(FileNameMC);
for i=1:ImageStackLen
    im = imread([PathNameMC FileNameMC{i}]);
    R_Im = imrotate(im,Ang,'bilinear');
    Im=imcrop(R_Im,rect);
     Destination= [PathNameMC '\ Cropped']; 
    imwrite(Im,[Destination '\Image' sprintf('%05d',i) '.tif'],'tif');
    display(['Image ' num2str(i) ' of ' num2str(length(FileNameMC))]);
end
display('Third GFP Channel started');
ImageStackLen=length(FileNameGFP);
for i=1:ImageStackLen
    im = imread([PathNameGFP FileNameGFP{i}]);
    R_Im = imrotate(im,Ang,'bilinear');
    Im=imcrop(R_Im,rect);
     Destination= [PathNameGFP '\ Cropped']; 
    imwrite(Im,[Destination '\Image' sprintf('%05d',i) '.tif'],'tif');
    display(['Image ' num2str(i) ' of ' num2str(length(FileNameGFP))]);
end
display('Done');
end