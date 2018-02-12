function start(obj)
%% Gets a gallery of n consecutive cell images using imrect
%defines
% parameters.memory=[1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1];
%     parameters.celldiameter=35;
%     parameters.searchradius=20;
%     parameters.confidencethreshold=0.5;
% n is an array with the images to be tracked i.e., can be in forwared or
% reverese order starting at any image in the image stack

[r c l p]=size(obj.Stack);
lastpos=obj.startrectangle;
n=obj.trackrange(1):obj.trackrange(2);
for i=1:length(n)
    cellgallery(i).pos=[];
    cellgallery(i).cellimage=[];
    cellgallery(i).ImageNumber=n(i);
end

m=length(obj.memory)-1;
mj=0;

i=1;

while  i<length(n)
    ttID=tic;
%     timer on;
    % create a red green image
    if l>1
        for j=1:3
            if l>=j
                im(:,:,j)=squeeze(obj.Stack(:,:,j,n(i)));
            else
                im(:,:,j)=0;
            end
        end
    else
        im=squeeze(obj.Stack(:,:,1,n(i)));
    end

    if (i==1)
        if ~Paws
            [cellgallery(n(i)).pos,cellgallery(n(i)).cellimage,cellgallery(n(i)).cellmask,...
                cellgallery(n(i)).result.SelectTime]=getCellImage(h,lastpos,0,true,true);
            cellgallery(n(i)).result.manual=true;
        else
            lastmask=cellgallery(n(i)-1).cellmask;
            [cellgallery(n(i)).pos,cellgallery(n(i)).cellimage,cellgallery(n(i)).cellmask,...
                cellgallery(n(i)).result.SelectTime]=getCellImage(h,lastpos,lastmask,false,true);
            cellgallery(n(i)).result.manual=true;
        end
    else % cellgallery exists because in pause state
        if cellgallery(n(i)).result.rho<confidencethreshold
            manual=true;
            cellgallery(n(i)).result.manual=true;

        else
            manual=false;
            cellgallery(n(i)).result.manual=false;
        end
        [cellgallery(n(i)).pos,cellgallery(n(i)).cellimage,cellgallery(n(i)).cellmask,...
                cellgallery(n(i)).result.SelectTime]=getCellImage(h,lastpos,lastmask,false,manual);
    end
    cellgallery(n(i)).result.lastpos=lastpos;
    cellgallery(n(i)).result.memory=parameters.memory;
    cellgallery(n(i)).result.celldiameter=parameters.celldiameter;
    cellgallery(n(i)).result.searchradius=parameters.searchradius;
    cellgallery(n(i)).result.confidencethreshold=parameters.confidencethreshold;
    % write cellgallery to workspace (crapy programming!)
    assignin('base','cellgallery',cellgallery);
    % update position using best correlated positions
    parameters.lastmask=cellgallery(n(i)).cellmask;
    % use running average to keep cells central

    if cellgallery(n(i)).result.manual
        mj=0;
        %update n(i) depending on current value of FrameAdvanceSlider
        handles=guidata(hObject);
        new_n_i=round(get(handles.FrameAdvanceSlider,'Value'));
        new_i=find(n==new_n_i);
        if ~isempty(new_i);
            i=new_i;
        else % FrameAdvanceSlider out of range of n(i)
            set(handles.FrameAdvanceSlider,'Value',n(i));
            set(handles.FrameNdxText,'String',['Frame ',num2str(n(i))]);
        end                
    end % adapt memory if there are errors.
    ndx=i-mj:i;
    if mj<m
        mj=mj+1;
    end

    weight=memory((end-length(ndx)+1):end);
    for j=1:length(ndx)
        cellstack(:,:,:,j)=weight(j)*cellgallery(n(ndx(j))).cellimage;
    end
    parameters.refimg=mean(cellstack,4);
    cellstack=[];
    parameters.lastcellimage=cellgallery(n(i)).cellimage;
    parameters.maxradius=searchradius; % search radius
    parameters.im=obj.Stack(:,:,:,n(i+1));
    if UseForegroundStack
        parameters.Foreground=ForegroundStack(:,:,:,n(i+1));
    end
    result=findCell('correlation',parameters); % during this phase the user may change current image
    RemainingImages=evalin('base','RemainingImages');
    disp(['r=' num2str(result.rho) ' Image ' num2str(n(i)) ' of ' num2str(n(end))]);

    cellgallery(n(i+1)).result.mask=result.mask;
    cellgallery(n(i+1)).result.pos=result.pos;
    cellgallery(n(i+1)).result.rho=result.rho;
    cellgallery(n(i+1)).result.pval=result.pval;
    lastpos=result.pos;
    lastmask=result.mask;


    cellgallery(n(i)).result.TotalTime=toc(ttID);
    display([num2str(1/cellgallery(n(i)).result.TotalTime) ' fps']);
    i=i+1; 
%     profile off;
%     profile viewer;
%   

end

remaining=[];
evalin('base','Paws=false;'); %reaches the end because all of images have been analysed
evalin('base','Stop=true;');% reset
