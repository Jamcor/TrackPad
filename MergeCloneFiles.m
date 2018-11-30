%function to merge two clone files

%clone contains a field called .cegmented masks and clonefile does not

%cegmented mask field is generated from SegmentImageManual function 

%this script adds new tracks from clonefile to clone - to preserve the
%masks in clone

%clonefile should contain an equal number or more tracks than clone

function clonefile=MergeCloneFiles(clone,clonefile)

for h=1:length(clone) %loop through clones

    
    for j=1:length(clone{h}.track)
    
        if isfield(clone{h}.track{j},'cegmentedmasks')
           
            clonefile{h}.track{j}.cegmentedmasks=clone{h}.track{j}.cegmentedmasks;
        end
        
                
    end
    
end


return
end