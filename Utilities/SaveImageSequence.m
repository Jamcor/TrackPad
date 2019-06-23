function SaveImageSequence(ImageStack)
% Downloads and image sequence from an ImageStack object
    FolderName=uigetdir(cd,'Get directory to download image sequence');
    [r,c,~,t]=size(ImageStack.Stack);
    mkdir(FolderName, 'Tracking');
    mkdir(FolderName, 'Display');
    h=waitbar(0,'Writing files');
    for i=1:t
        str=datestr(ImageStack.AcquisitionTimes(i));
        FileName=[FolderName '\Tracking\Image ' num2str(i,'%04i') '.tif'];
        imwrite(gray2ind(squeeze(ImageStack.Stack(:,:,1,i))),FileName,'Description',str);
        FileName=[FolderName '\Display\Image ' num2str(i,'%04i') '.tif'];
        imwrite(ImageStack.CData(:,:,i),ImageStack.CMap{i},FileName,'Description',str);
        waitbar(i/t,h);
    end
    close(h);
end

