function DownSampleStack
%% downsamples Image Stack by 2 fold
    [FileName,PathName,FilterIndex] = uigetfile('*.tif','Get Image Stack','MultiSelect','on');
    mkdir(PathName, 'DownSample_by_2');
    h=waitbar(0,'Writing files');
    n=length(FileName);
     for i=1:n
        im=imread([PathName FileName{i}]);
        im_by_2=imresize(im,0.5);
        s=imfinfo([PathName FileName{i}]);
        if isfield(s,'ImageDescription')
            imwrite(im_by_2,[PathName 'DownSample_by_2\' FileName{i}],'Description',s.ImageDescription);
        else
            imwrite(im_by_2,[PathName 'DownSample_by_2\' FileName{i}]);
        end
        waitbar(i/n,h);
     end
     close(h);
end