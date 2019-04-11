function [min_rho, sr]=AnalyseROCfunction(TruthSet,ROCtbl)
TotalOutcomes=ROCtbl.TotalOutcomes;
TP=ROCtbl.TruePositives./ROCtbl.TotalOutcomes*100;
FP=ROCtbl.FalsePositives./ROCtbl.TotalOutcomes*100;
TN=ROCtbl.TrueNegatives./ROCtbl.TotalOutcomes*100;
FN=ROCtbl.FalseNegatives./ROCtbl.TotalOutcomes*100;
rho=ROCtbl.Rho;

Y=[TP FN FP TN];

% figure();
% area(rho,Y,'LineStyle',':');
% xlabel('Correlation threshold (rho)');
% ylabel('Frequency (%)');
% % h(1).FaceColor = [0 0.25 0.25];
% % h(2).FaceColor = [0 0.5 0.5];
% % h(3).FaceColor = [0 0.75 0.75];
% legend('TP', 'FN', 'FP', 'TN');

%estimate cost based on time correcting FN (lost) and FP (pause) from
%truthtable

lost_time=TruthSet.stats.median.lost;
pause_time=TruthSet.stats.median.pause;
go_time=TruthSet.stats.median.go;

total_time=go_time+pause_time+lost_time;
lost_cost=lost_time/total_time;
pause_cost=pause_time/total_time;

cost=[0 lost_cost pause_cost 0]; %TP FN FP TN
costmatrix=zeros(length(Y),1);
for i=1:length(Y)
costmatrix(i)=sum(Y(i,:).*cost);
end

%find miniumum rho
[mincost,ndx]=min(costmatrix);
min_rho=rho(ndx);



% figure();
% plot(rho,costmatrix);
% xlabel('Correlation threshold (rho)');
% ylabel('Cost');
% legend('Cost function');
% hold on;
% plot(min_rho,mincost,'*g');
% text(min_rho,(mincost-mincost*0.10),['Rho= ' num2str(min_rho)]);
% hold off;
% disp(['Min rho: ' num2str(min_rho)]);
sr=0;
return
end


