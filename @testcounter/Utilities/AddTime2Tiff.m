function AddTime2Tiff(PathName,FileName)
    if nargin<2
        [FileName,PathName,~] = uigetfile('*.tif','Select files to add acquisition time',...
            'MultiSelect','on');
    end
% get start time
    DateVector=datevec(now);
    DateVector=arrayfun(@(x) num2str(x), DateVector,'UniformOutput',false);
    answer=inputdlg({'Year' 'Month' 'Day' 'hours' 'minutes' 'seconds'},...
        'Start of experiment',1,DateVector);
    answer=arrayfun(@(x) str2double(x), answer);
    starttime=datenum(answer');
    % get sampling interval
    sampling=inputdlg('Sampling interval in minutes:');
    sampling=str2num(sampling{1})/24/60;

    s=imfinfo([PathName FileName{1}]);

    p=length(FileName);
    date=0:sampling:(p-1)*sampling;
    date=date+starttime;
    h=waitbar(0,'Writing acquisition time to ImageDescription tag');

    for i=1:p
        
        waitbar(i/p,h);

        %extract suffix
        Suffix=FileName{i};
        Suffix=Suffix(1:end-4);
        %get date vector
        str=datestr(date(i));
        im=imread([PathName FileName{i}]);
        im=im(:,:,1);
        [~,values] = fileattrib([PathName FileName{i}]);
        if ~values.UserWrite
            fileattrib([PathName FileName{i}],'+w'); % even modified if file read only
        end
        imwrite(im,[PathName Suffix '.tif'],'tif','Description',str);
    end
    
    close(h);
end