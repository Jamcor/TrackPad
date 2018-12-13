%this function will create screenshots and a movie of an individual cell
%given a clone file, clonenumb, tracknumb, buff, and path
%the function needs to be extended to all
%path is the file to the segmented cells e.g.
%path='C:\Users\jcor1985\Documents\Matlab folder\Swarna\Exp4\Stitched\Grid 1\SegmentedCells\'
%if the directory SegmentedCells doesn't exist, it needs to be created
%first
%channels is a cell string containing the name of the channels for which
%screenshots are captured

function GetCellImages(clone,clonenumb,tracknumbers,buff,path,channels,imagestack)


for g=1:length(channels)
    imageobj=imagestack;
    
for h=1:length(clonenumb)
    disp(['Processing clone ' num2str(clonenumb(h))]);
    currentclone=clonenumb(h);
    
    if length(clone{1, currentclone}.track)<max(tracknumbers)
        tracknumb=min(tracknumbers):length(clone{1, currentclone}.track);
        disp(['Clone ' num2str(clonenumb(h))...
            ' only has ' num2str(length(tracknumb))...
            ' tracks -> processing ' num2str(length(tracknumb)) ' tracks']);
    else
        tracknumb=tracknumbers;
    end
    
    for i=1:length(tracknumb)
        disp(['Processing track ' num2str(tracknumb(i))]);
        %figure();
        %set(gcf, 'Position', get(0, 'Screensize'));
        
        subpath=['\Clone ' num2str(currentclone) '\Track' num2str(tracknumb(i)) '\' channels{g}];
        if ~isdir([path subpath])
            mkdir(path,subpath);
        end
        
        %initialise moviewriter
        writerObj=VideoWriter([path subpath '\Clone' num2str(currentclone)...
            'Track' num2str(tracknumb(i)) '.avi']); %create writerobj
        switch channels{g}         
            case 'Phase'
                writerObj.FrameRate=10;    
                imagetimes=clone{currentclone}.track{tracknumb(i)}.T;
            case 'GFP'
                writerObj.FrameRate=2.5; 
                imagetimes=clone{currentclone}.track{tracknumb(i)}.GFPTimes;
        end
        
        open(writerObj);
        
        %loop depending on number of image files, rather than timepoints -
        %as it may be different for phase and GFP channels
        for j=1:1:length(imagetimes) 
            time=imagetimes(j);
            disp(['Processing frame ' num2str(j)]);
            [cellimage,relframeid,cmap]=GetCellImagePatchesv2(clone,currentclone,tracknumb(i),time,buff,channels{g},imageobj);
            grayim=ind2gray(cellimage,cmap);
            if j==1
                [r,c]=size(grayim);               
            elseif j>1  && (size(grayim,1)~=r || size(grayim,2)~=c)
                grayim=imresize(grayim,[r c]);
%                 grayim(grayim(:)>1)=1; grayim(grayim(:)<0)=0;               
            end
            writeVideo(writerObj,grayim);
            %save image as .tiff
            frameid=find(relframeid==1);
            timestamp=datestr(clone{currentclone}.track{tracknumb(i)}.T(frameid));
            imwrite(grayim,[path subpath '\Frame ' num2str(frameid) '.tif'],'Description',timestamp);
        end
        close(writerObj);
    end
end
end
