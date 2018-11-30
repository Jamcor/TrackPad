% a script to check for presence of cegmented masks in tracks of a clone
% file
function is_mask_flag=CheckCegmentedMasks(clone)

is_mask_flag=0;

for h=1:length(clone)
    indclone=clone{h};
    
    for i=1:length(indclone.track)
        
        track=indclone.track{i};
        
        if isfield(track,'cegmentedmasks')
                               
                numbmasks=sum(~cellfun(@isempty,track.cegmentedmasks));    
                
                is_mask_flag=1;
                disp(['Clone ' num2str(h) ' track ' num2str(i) ' has ' num2str(numbmasks) ' masks ']);
  
        elseif ~isfield(track,'cegmentedmasks')
            
            disp(['Clone ' num2str(h) ' track ' num2str(i) ' has ' num2str(0) ' masks ']);
            
           
        end
              
        
    end
      
end
return

end