function PlotTree( obj,clone,CloneID,HighlightTrackNum)
%% plots a division tree from a Clone file
% Highlights TrackID (if present)

    n_tracks=length(clone{CloneID}.track);
    % calculate number of generations
    Parameters.maxprogeny=1;
    % determine intensity range for channels as well as max number of
    % generations and max time
    maxtime=0;
    for i=1:length(clone{CloneID}.track)
        if Parameters.maxprogeny<clone{CloneID}.track{i}.TrackNum
            Parameters.maxprogeny=clone{CloneID}.track{i}.TrackNum;
        end
        if maxtime<max(clone{CloneID}.track{i}.T(end))
            maxtime=max(clone{CloneID}.track{i}.T(end));
        end
    end
    maxtime=maxtime-clone{1}.track{1}.T(1);
    Parameters.n_gens=floor(log2(Parameters.maxprogeny))+1;
     
    % calculate x spacing
    if Parameters.n_gens<4
        Parameters.xrange=1; %3 generations deep max
       Parameters.n_gens=3;
        
    else
        disp('Warning: more than 3 generations deep');
        Parameters.xrange=2^(Parameters.n_gens-3);
    end
    Parameters.last_gen_row=linspace(0,Parameters.xrange,2^Parameters.n_gens)+1/(2^(Parameters.n_gens+1));
    
    axesrange=[Parameters.xrange+1/(2^Parameters.n_gens),maxtime+1/24];
    if isempty(obj.PedigreeFigureHandle) % only have one pedigree figure at a time!
        if nargin==3
            obj.PedigreeFigureHandle=figure('Name',['Clone ' num2str(CloneID) ]);
        else
            obj.PedigreeFigureHandle=figure('Name',['Clone ' num2str(CloneID) '; Progeny ',num2str(HighlightTrackNum) ]);
        end
    elseif isvalid(obj.PedigreeFigureHandle)
        close(obj.PedigreeFigureHandle);
        if nargin==3
            obj.PedigreeFigureHandle=figure('Name',['Clone ' num2str(CloneID) ]);
        else
            obj.PedigreeFigureHandle=figure('Name',['Clone ' num2str(CloneID) '; Progeny ',num2str(HighlightTrackNum) ]);
        end
    else
        if nargin==3
            obj.PedigreeFigureHandle=figure('Name',['Clone ' num2str(CloneID) ]);
        else
            obj.PedigreeFigureHandle=figure('Name',['Clone ' num2str(CloneID) '; Progeny ',num2str(HighlightTrackNum) ]);
        end
    end
    h=axes('XLim',[0,axesrange(1)],'YLim',...
        [0,axesrange(2)],'YDir','reverse');
    position=get(h,'position');
    Parameters.Scale=axesrange./[position(3),position(4)];
    for i=1:n_tracks
        Highlight=false;
        if nargin==4
            if HighlightTrackNum==clone{CloneID}.track{i}.TrackNum
                Highlight=true;
            end
        end
        PlotLifeLine(clone,CloneID,i,Parameters,Highlight);
    end
    xlim([0,Parameters.xrange+1/(2^Parameters.n_gens)]);
    ylim([0,maxtime+1/24]);
%     set(gca,'YDir','reverse');
%     set(gca,'Color',[0.8 0.8 0.8])
    set(gca,'XTick',[]);
    ylabel('Days');
end

function PlotLifeLine (clone,CloneID,TrackID,Parameters,Highlight)
    progeny_id=clone{CloneID}.track{TrackID}.TrackNum;
    gen_id=floor(log2(progeny_id));
    T=clone{CloneID}.track{TrackID}.T-clone{CloneID}.track{1}.T(1);   
    %% Calculate x position
    dn=2^(Parameters.n_gens-gen_id);
    ndx(1)=(progeny_id-2^gen_id)*dn+1;
    ndx(2)=(progeny_id-2^gen_id+1)*dn;
    xpos=(Parameters.last_gen_row(ndx(1))+Parameters.last_gen_row(ndx(2)))/2;
    x=xpos;
    for j=1:(length(T)-1)
        y=T(j);
        h=T(j+1)-T(j);
        if Highlight
            line([x;x],[y;y+h],'Color','r');
        else
            line([x;x],[y;y+h],'Color','k');
        end
    end

    % plot fate
    hold on;
    % StopReason 0 - 'NC', 1 - 'DI', 2 - 'DE', 3- 'LO'
    switch(clone{CloneID}.track{TrackID}.StopReason)
        case 1
            dn=2^(Parameters.n_gens-(gen_id+1)); %find x position of left daughter
            ndx(1)=(progeny_id*2-2^(gen_id+1))*dn+1;
            ndx(2)=(progeny_id*2-2^(gen_id+1)+1)*dn;
            try
            leftdaughterxpos=(Parameters.last_gen_row(ndx(1))+Parameters.last_gen_row(ndx(2)))/2;  
            catch
                disp('here')
            end
            x=leftdaughterxpos;
            w=2*(xpos-leftdaughterxpos);
            y=T(end);
            line([x;x+w],[y;y],'color','k');
        case 2
%             plot(xpos,T(end),'+k');
            text(xpos,T(end),'DE');
        case 3
%             plot(xpos,T(end),'>k');
            text(xpos,T(end),'LO');
        case 0
%             plot(xpos,T(end),'>k');
            text(xpos,T(end),'LO');
        otherwise
            disp('Cell fate not recognised');
    end
    hold off;
        % get annotation symbols
    if isfield(clone{CloneID}.track{TrackID},'Annotation_Symbol')
        if ~isempty(clone{CloneID}.track{TrackID}.Annotation_Symbol)
            Symbols=clone{CloneID}.track{TrackID}.Annotation_Symbol;
            oldstr='';            
            for j=2:(length(Symbols)-1) 
                FieldNames=fieldnames(Symbols{j});
                ndx=contains(FieldNames,'PedigreeID');
                FieldNames={FieldNames{~ndx}};
                y=T(j);
                str='';
                for k=1:length(FieldNames)
                    if ~contains(Symbols{j}.(FieldNames{k}),'NA')
                       str=[str,' ', Symbols{j}.(FieldNames{k})];
                    end
                end
                if ~contains(oldstr,str)
%                     Axes_Pos=get(gca,'Position');
%                     dx=xlim(gca);dx=dx(2)-dx(1);
%                     X=Axes_Pos(1)+[xpos-0.05, xpos]/dx*Axes_Pos(3);
%                     dy=ylim(gca);dy=dy(2)-dy(1);
%                     Y=Axes_Pos(2)+Axes_Pos(4)-[y y]/dy*Axes_Pos(4);
%                     annotation('textarrow',X,Y,'String',str);
                    line(xpos,y,'Marker','o','Color','k');
                    text(xpos,y,str);
                end
                oldstr=str;                   
            end
        end
    end
            
end
