function ConvertRGBImages_To_Gray
%% Changes RGB to gray images whilst keeping timestampe in ImageDescription
    [FileName,PathName,FilterIndex] = uigetfile('*.tif','Get Image Stack','MultiSelect','on');
    mkdir(PathName, 'GrayScale');
    h=waitbar(0,'Writing files');
    n=length(FileName);
     for i=1:n
         s=imfinfo([PathName FileName{i}]);
        im=imread([PathName FileName{i}]);
        
        if s.BitDepth==24
          im=uint16(im);  
        end
        
        grayim=rgb2gray(im);
        
        if isfield(s,'ImageDescription')
            imwrite(grayim,[PathName 'GrayScale\' FileName{i}],'Description',s.ImageDescription);
        else
            imwrite(grayim,[PathName 'GrayScale\' FileName{i}]);
        end
        waitbar(i/n,h);
     end
     close(h);
end