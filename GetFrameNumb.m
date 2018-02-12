function out=GetFrameNumb(in)

% out=(['Frame ' num2str(sscanf(in,'%*s %d'))]);
out=(sscanf(in,'%*s %d'));
return
end