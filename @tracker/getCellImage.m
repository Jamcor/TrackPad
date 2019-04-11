function  [pos,cellimage,imgmask,selecttime] = getCellImage(image,pos,mask,isResizable,isEditable)
% not that image is the output handle of imshow
assignin('base','isEditable',isEditable);
hparent=get(image,'Parent');
if length(pos)==2
    pos(3)=25;
    pos(4)=25;
end
h=imellipse(hparent,pos);
setResizable(h,isResizable);
if isEditable
    setColor(h,'r');
    selecttimeID=tic; % time duration of user input
    wait(h);
    selecttime=toc(selecttimeID);
    if mask==0
        BW=createMask(h,image);
    else
        %generate mask for new position
        BW=createMask(h,image); % bug here should only be applied if Stop=False,Paws=False
        % check that BW and mask have the same size
        if (sum(size(BW)==size(mask))~=2) % O Oh
            disp('here');
        end
        rows=find(sum(BW,2)>0);
        cols=find(sum(BW,1)>0);
        offset=[rows(1),cols(1)]; % find the offset for the new mask
        %but needs to have the same shape as mask
        rows=find(sum(mask,2)>0);
        cols=find(sum(mask,1)>0);
        mask=mask(rows,cols);
        BW(:)=false; %clear BW
        BW(offset(1):(offset(1)+(length(rows)-1)),...
            offset(2):(offset(2)+(length(cols)-1)))=mask;
    end
else
    % use mask instead
    BW=mask;
    selecttime=0;
    drawnow;
end
imgmask=BW;
% find new pos
rows=find(sum(BW,2)>0);
cols=find(sum(BW,1)>0);
pos=[cols(1),rows(1),cols(end)-cols(1)+1, rows(end)-rows(1)+1];
im=get(image,'CData');
p=size(im,3);
BW=repmat(BW,[1 1 p]);
im(~BW(:))=NaN;
cellimage=im(rows,cols,:);
delete(h);
evalin('base','isEditable=false;');