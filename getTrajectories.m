function condition=getTrajectories(allclones)
disp('here');
% PathName = 'C:\Users\James\Desktop\Matlab2\Pedigrees\16th November'; %location where the output is saved

for i=1:length(allclones) %loop through conditions
    disp(['Condition  ' num2str(i)]);
    
    %initiate variables
    m=1;
    n=1;
    total_cell_num=0;
    temptotaldistancecondition(i)=0;
    tempmeandistancecondition(i)=0;
    tempxstartcondition(i)=0;
    tempystartcondition(i)=0;
    tempxendcondition(i)=0;
    tempyendcondition(i)=0;
    tempeuclidcondition(i)=0;
    tempFMIparcondition(i)=0;
    tempFMIpercondition(i)=0;
    tempanglepercondition(i)=0;

    
    disp(['Condition  ' num2str(i)]);
    %cond_clone = allclones(i).clone; %change depending on format of clone
    %file
    
    cond_clone = allclones{i}; %get clones from first condition
    condition(i).TimeStamps=cond_clone{1}.TimeStamps;
    for j =1:length(cond_clone) %loop through all clones
        disp(['Clone  ' num2str(j)]);
        
        %initian variables
        tempmeandistanceclone(j)=0;
        temptotaldistanceclone(j)=0;
        tempxstartclone(j)=0;
        tempystartclone(j)=0;
        tempxendclone(j)=0;
        tempyendclone(j)=0;
        
        clone=cond_clone{j}; %get cells from each clones
        
        for k=1:length(clone.track) %loop through all cells
            disp(['Cell  ' num2str(k)]);
            
            %get cell X and Y positions and time T
            cell = clone.track{k};
            X=cell.X;
            Y =cell.Y;
            T = cell.T;
            condition(i).clone(j).cell(k).total = 0; %accumulated distance per cell
            condition(i).clone(j).cell(k).time=cell.T;
          %  condition(i).clone(j).TotalDistanceTravelled = 0;
         
          if length(X)>1
              
              
              for l=1:length(X)-1
                  
                  %adjustment for stage movements
                  %                     if abs(X(l+1) -X(l)) > 10  || abs(Y(l+1) - Y(l)) > 10
                  %                         diff = X(l+1) - X(l);
                  %                         Xnew = X(l+1:end)-diff;
                  %                         X = cat(2,X(1:l),Xnew);
                  %                         diff = Y(l+1) - Y(l);
                  %                         Ynew = Y(l+1:end)-diff;
                  %                         Y = cat(2,Y(1:l),Ynew);
                  %                     end
                  
                  deltaX=abs(X(l+1)-X(l)); %change in X position
                  deltaY=abs(Y(l+1)-Y(l)); %change in Y position
                  condition(i).clone(j).cell(k).distance(l) = sqrt(deltaX^2+deltaY^2); %euclidean distance travelled
                  
              end
              
              % Mean Distance Covered by Cell
              % Standard Deviation of Distance Covered by Cell
              % Total Distance Covered by Cell
              %X and Y start position (normalised to 0,0) and X and Y end
              %position (in pixels)
              condition(i).clone(j).cell(k).mean=mean(condition(i).clone(j).cell(k).distance(:));
              condition(i).clone(j).cell(k).xstart=X(1);
              condition(i).clone(j).cell(k).ystart=Y(1);
              condition(i).clone(j).cell(k).xend=X(end)-X(1);
              condition(i).clone(j).cell(k).yend=Y(end)-Y(1);
              
              %determine change in angle in radians
              if X(end)-X(1) > 0 && Y(end)-Y(1) >0
                  condition(i).clone(j).cell(k).angle=atan(abs(Y(end)-Y(1))/abs(X(end)-X(1)));
                  angle(n)=condition(i).clone(j).cell(k).angle;
              elseif X(end)-X(1) > 0 && Y(end)-Y(1) < 0
                  condition(i).clone(j).cell(k).angle=atan(abs(Y(end)-Y(1))/abs(X(end)-X(1)));
                  angle(n)=condition(i).clone(j).cell(k).angle + pi/2;
              elseif X(end)-X(1) < 0 && Y(end)-Y(1) < 0
                  condition(i).clone(j).cell(k).angle=atan(abs(Y(end)-Y(1))/abs(X(end)-X(1)));
                  angle(n)=condition(i).clone(j).cell(k).angle + pi;
              elseif X(end)-X(1) < 0 && Y(end)-Y(1) > 0
                  condition(i).clone(j).cell(k).angle=atan(abs(Y(end)-Y(1))/abs(X(end)-X(1)));
                  angle(n)=condition(i).clone(j).cell(k).angle + 1.5*pi;
              end
              
              
              condition(i).clone(j).cell(k).euclid=sqrt((X(end)-X(1))^2+(Y(end)-Y(1))^2); %euclidean distance
              %condition(i).clone(j).cell(k).std=std(condition(i).clone(j).cell(k).distance(:));
              condition(i).clone(j).cell(k).total= sum(condition(i).clone(j).cell(k).distance(:)); %total distance
              condition(i).clone(j).cell(k).FMIpar=(X(end)-X(1))/condition(i).clone(j).cell(k).total; %FMI parallel
              condition(i).clone(j).cell(k).FMIper=(Y(end)-Y(1))/condition(i).clone(j).cell(k).total; % FMI perpendicular
              distancepercell(m)=condition(i).clone(j).cell(k).mean; 
              
              
              %%%update temporary variables
              %  distancepercell(m) = condition(i).clone(j).cell(k).total;
              %  tempdistanceclone(j)=condition(i).clone(j).cell(k).total+tempdistanceclone(j);
              tempmeandistanceclone(j)=condition(i).clone(j).cell(k).mean+tempmeandistanceclone(j);
              temptotaldistanceclone(j)=condition(i).clone(j).cell(k).total+temptotaldistanceclone(j);
              tempxstartclone(j)=condition(i).clone(j).cell(k).xstart+tempxstartclone(j);
              tempystartclone(j)=condition(i).clone(j).cell(k).ystart+tempystartclone(j);
              tempxendclone(j)=condition(i).clone(j).cell(k).xend+tempxendclone(j);
              tempyendclone(j)=condition(i).clone(j).cell(k).yend+tempyendclone(j);
              %tempdistancecondition(i)=condition(i).clone(j).cell(k).total +tempdistancecondition(i);
              temptotaldistancecondition(i)=condition(i).clone(j).cell(k).total +temptotaldistancecondition(i);
              tempmeandistancecondition(i)=condition(i).clone(j).cell(k).mean +tempmeandistancecondition(i);
              
              tempxstartcondition(i)=condition(i).clone(j).cell(k).xstart +tempxstartcondition(i);
              tempystartcondition(i)=condition(i).clone(j).cell(k).ystart +tempystartcondition(i);
              tempxendcondition(i)=condition(i).clone(j).cell(k).xend +tempxendcondition(i);
              tempyendcondition(i)=condition(i).clone(j).cell(k).yend +tempyendcondition(i);
              tempeuclidcondition(i)=condition(i).clone(j).cell(k).euclid+tempeuclidcondition(i);
              tempFMIparcondition(i)=condition(i).clone(j).cell(k).FMIpar+tempFMIparcondition(i);
              tempFMIpercondition(i)=condition(i).clone(j).cell(k).FMIper+tempFMIpercondition(i);
              
              m=m+1;
              n=n+1;
          else
              condition(i).clone(j).cell(k).distance=0;
              condition(i).clone(j).cell(k).mean=0;
              condition(i).clone(j).cell(k).std=0;
              condition(i).clone(j).cell(k).total(1)=0;
              
          end
          %condition(i).clone(j).TotalDistanceTravelled = condition(i).clone(j).cell(k).total+condition(i).clone(j).TotalDistanceTravelled;
        end
        total_cell_num = k+total_cell_num;
        condition(i).clone(j).totaldistance=temptotaldistanceclone(j)/k;
        condition(i).clone(j).meandistance=(tempmeandistanceclone(j))/k;
        condition(i).clone(j).xstart=tempxstartclone(j)/k;
        condition(i).clone(j).ystart=tempystartclone(j)/k;
        condition(i).clone(j).xend=tempxendclone(j)/k;
        condition(i).clone(j).yend=tempyendclone(j)/k;
        %condition(i).clone(j).TotalDistanceTravelled = condition(i).clone(j).TotalDistanceTravelled +
    end
    condition(i).stdev=std(distancepercell(:));
    condition(i).totaldistance=temptotaldistancecondition(i)/total_cell_num;
    condition(i).meandistance=(tempmeandistancecondition(i))/total_cell_num;
    condition(i).xstart=tempxstartcondition(i)/total_cell_num;
    condition(i).ystart=tempystartcondition(i)/total_cell_num;
    condition(i).xend=tempxendcondition(i)/total_cell_num;
    condition(i).yend=tempyendcondition(i)/total_cell_num;
    condition(i).Euclid=tempeuclidcondition(i)/total_cell_num;
    condition(i).FMIpar=tempFMIparcondition(i)/total_cell_num;
    condition(i).FMIper=tempFMIpercondition(i)/total_cell_num;
    condition(i).angle=angle(:);
    %calculate COM
    X=condition(i).xend-condition(i).xstart;
    Y=condition(i).yend-condition(i).ystart;
    condition(i).COM=[X,Y];
    
%     %calculate Rayleigh test
%     [pvalue,z]=rayleightest(condition(i).angle(:));
%     condition(i).pvalue=pvalue;
%     condition(i).zscore=z;
    
end
% 
% if length(varargin)==1
% PathName=varargin{1};
% save([PathName '\distancetest'],'condition');
% end

return
end

% function [pval,z]=rayleightest(alpha)
% if size(alpha,2) > size(alpha,1)
%     alpha = alpha';
% end
% 
% if nargin < 2
%     r =  circ_r(alpha);
%     n = length(alpha);
% else
%     if length(alpha)~=length(w)
%         error('Input dimensions do not match.')
%     end
%     if nargin < 3
%         d = 0;
%     end
%     r =  circ_r(alpha,w(:),d);
%     n = sum(w);
% end
% 
% % compute Rayleigh's R (equ. 27.1)
% R = n*r;
% 
% % compute Rayleigh's z (equ. 27.2)
% z = R^2 / n;
% 
% % compute p value using approxation in Zar, p. 617
% pval = exp(sqrt(1+4*n+4*(n^2-R^2))-(1+2*n));
% end
