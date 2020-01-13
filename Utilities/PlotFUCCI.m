function PlotFUCCI(tbl,GFP_Ims)
% Plots FUCCI graphs 
% Need to run getFUCCI to modify tbl
    close all;
    Parents=unique(tbl.Parent_ID);
    Parents=Parents(~isnan(Parents));
    for i=1:length(Parents)
        %% Parent
        figure('Name',['Parent: Track ',num2str(tbl.Track_ID(Parents(i)))]);
        
        subplot(3,2,1);% plot parent data
        t=tbl.time{Parents(i)};
        t=(t-t(1))*24; % time in hours (from cell birth);
        GFP=tbl.GFP{Parents(i)};
        h(1)=plot(t,GFP(:,1),'--g');
        hold on;
        plot(t,GFP(:,2),'--g');
        h(2)=plot(t,GFP(:,3),'-g');
        h(3)=plot(t,GFP(:,4),'-k');
        legend(h,{'Min/Max','Mean','Nuclear Area'},'Location','best');
        xlabel('Time (hours)');
        ylabel('Arbitary units');
        hold off;
        title(['Nuclear GFP of parent: Track ',num2str(tbl.Track_ID(Parents(i)))]);
        subplot(3,2,2);
        CDT1=tbl.CDT1{Parents(i)};
        h=[];
        h(1)=plot(t,CDT1(:,1),'--r');
        hold on;
        plot(t,CDT1(:,2),'--r');
        h(2)=plot(t,CDT1(:,3),'-r');
        legend(h,{'Min/Max','Mean'},'Location','best');
        xlabel('Time (hours)');
        ylabel('Arbitary units');
        hold off;
        title(['CDT1 of parent: Track ',num2str(tbl.Track_ID(Parents(i)))]);
        %% daughters
        ndx=Parents(i)==tbl.Parent_ID;
        t={tbl.time{find(ndx)}};
        GFP={tbl.GFP{ndx}};
        CDT1={tbl.CDT1{ndx}};
        Track_ID=tbl.Track_ID(ndx);
        subplot(3,2,3);% plot 1st daughter data
        t1=t{1};
        t1=(t1-t1(1))*24; % time in hours (from cell birth);
        GFP1=GFP{1};
        h(1)=plot(t1,GFP1(:,1),'--g');
        hold on;
        plot(t1,GFP1(:,2),'--g');
        h(2)=plot(t1,GFP1(:,3),'-g');
        h(3)=plot(t1,GFP1(:,4),'-k');
        legend(h,{'Min/Max','Mean','Nuclear Area'},'Location','best');
        xlabel('Time (hours)');
        ylabel('Arbitary units');
        hold off;
        title(['Nuclear GFP of daughter 1: Track ',num2str(Track_ID(1))]);
        subplot(3,2,4);
        CDT11=CDT1{1};
        h=[];
        h(1)=plot(t1,CDT11(:,1),'--r');
        hold on;
        plot(t1,CDT11(:,2),'--r');
        h(2)=plot(t1,CDT11(:,3),'-r');
        legend(h,{'Min/Max','Mean'},'Location','best');
        xlabel('Time (hours)');
        ylabel('Arbitary units');
        hold off;
        title(['CDT1 of daughter 1: Track ',num2str(Track_ID(1))]);
        subplot(3,2,5);% plot 2nd daughter data
        t2=t{2};
        t2=(t2-t2(1))*24; % time in hours (from cell birth);
        GFP2=GFP{2};
        h(1)=plot(t2,GFP2(:,1),'--g');
        hold on;
        plot(t2,GFP2(:,2),'--g');
        h(2)=plot(t2,GFP2(:,3),'-g');
        h(3)=plot(t2,GFP2(:,4),'-k');
        legend(h,{'Min/Max','Mean','Nuclear Area'},'Location','best');
        xlabel('Time (hours)');
        ylabel('Arbitary units');
        hold off;
        title(['Nuclear GFP of daughter 2: Track ',num2str(Track_ID(2))]);
        subplot(3,2,6);
        CDT12=CDT1{2};
        h=[];
        h(1)=plot(t2,CDT12(:,1),'--r');
        hold on;
        plot(t2,CDT12(:,2),'--r');
        h(2)=plot(t2,CDT12(:,3),'-r');
        legend(h,{'Min/Max','Mean'},'Location','best');
        xlabel('Time (hours)');
        ylabel('Arbitary units');
        hold off;
        title(['CDT1 of daughter 2: Track ',num2str(Track_ID(2))]);       
    end
    %% create segmentation gallery
    for i=1:length(GFP_Ims)
        figure('Name',['Track ' num2str(tbl.Track_ID(i))]);
        montage(GFP_Ims{i});
    end
end

