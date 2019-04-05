function AdjustContrast
% Adjusts contrast of an image stack
[FileName,PathName,FilterIndex] = uigetfile('*.tif','Get image stack','MultiSelect','on');

disp('here');
TiffObj=Tiff([PathName FileName{1}],'r');

% h=imshow(ImageCorrection(TiffObj.read),[]);
h=imshow((TiffObj.read),[]);
imcontrast(h);
close(TiffObj);
dlg_title='Enter minimum and maximum pixel value';
s=imfinfo([PathName FileName{1}]);
prompt={'Minimum' 'Maximum'};
defAns={num2str(s.MinSampleValue), num2str(s.MaxSampleValue)};
options.WindowStyle='normal';
answer=inputdlg(prompt,dlg_title,1,defAns,options);
if isempty(answer)
    error('Cancelled');
else
    minpixelvalue=str2double(answer{1});
    maxpixelvalue=str2double(answer{2});
end
mkdir(PathName,'New Contrast\');

for i=1:length(FileName)
    im=imread([PathName FileName{i}]);
%     im=ImageCorrection(im);
    im=mat2gray(im,[minpixelvalue,maxpixelvalue]);
    im=imresize(im,[1040 1392]);
    s=imfinfo([PathName FileName{i}]);
    
%     %option to write image files with different filenames by manual sequence 
% NewFileName={'Frame 1.tif' 'Frame 18.tif' 'Frame 35.tif' 'Frame 52.tif' 'Frame 69.tif'...
%     'Frame 86.tif' 'Frame 103.tif' 'Frame 120.tif' 'Frame 137.tif' 'Frame 154.tif' 'Frame 171.tif' 'Frame 188.tif'};
%     
%     imwrite(im,[PathName 'New Contrast\' NewFileName{i}],'Description',s.ImageDescription);
%        imwrite(im,[PathName 'New Contrast\' FileName{i}],'Description',s.ImageDescription);
       imwrite(im,[PathName 'New Contrast\Frame ' num2str(i) '.tif'],'Description',s.ImageDescription);

%     display(['Image ' num2str(i) ' of ' num2str(length(NewFileName))]);
end

