classdef TrackNavigator < handle
    
    properties
        TableFigureHandle
        ToolBarHandle
        TableContextMenu
        TableHandle
        TableData
        PedigreeData
        DisplayTableData
        Tracks=[]
        CntrlObj
        CellImagePatchBuffer
        PedigreeFigureHandle
        
    end
    
    events
        
        
    end
    
    
    methods
        
        
        function obj=TrackNavigator(TrackCollection)
            obj.TableFigureHandle=figure('Name','TrackTable','Toolbar','figure','MenuBar','none'); %start figure
            obj.TableFigureHandle.DeleteFcn=@obj.DeleteFigure;
            %get and set toolbar children handles to visible (default is not visible) so new buttons
            %can be added to existing 'figure' toolbar instead of creating
            
            %new dropdown menus
%             FileMenuHandle = uimenu(obj.TableFigureHandle,'Label','File');
%             uimenu(FileMenuHandle,'Label','Open Tracks',...
%                 'Callback',{@obj.OpenTracks,obj});
%             uimenu(FileMenuHandle,'Label','Save Tracks',...
%                 'Callback',{@obj.SaveTracks,obj});
%             uimenu(FileMenuHandle,'Label','Quit',...
%                 'Callback',{@obj.CloseTrackTable,obj});
            ExportMenuHandle=uimenu(obj.TableFigureHandle,'Label','Export');
            uimenu(ExportMenuHandle,'Label','Trajectory data',...
                'Callback',{@obj.getTrajectories,obj});
            uimenu(ExportMenuHandle,'Label','Pedigree data',...
                'Callback',{@obj.getPedigreeData,obj});
            uimenu(ExportMenuHandle,'Label','Annotations',...
                'Callback',{@obj.getAnnotations,obj});
            uimenu(ExportMenuHandle,'Label','Cell image patches',...
                'Callback',{@obj.getCellImages,obj});
            uimenu(ExportMenuHandle,'Label','Clone file',...
                'Callback',{@obj.getCloneFile,obj});
            
            %a new toolbar
            obj.ToolBarHandle=findall(gcf,'tag','FigureToolBar');
            toolbarhandle=allchild(obj.ToolBarHandle);
            set(toolbarhandle,'HandleVisibility','on');
            delete(toolbarhandle(:));
            
            %add user defined toolbar features
            %add go to start and end buttons
            go2startpushtool=uipushtool(obj.ToolBarHandle,'TooltipString',...
                'Go to start of track','ClickedCallBack',{@obj.ReturnToStart},'Separator','on');
            go2startpushtool.CData=imresize(imread('LeftArrow.jpg'),[16 16]);
            go2endpushtool=uipushtool(obj.ToolBarHandle,'TooltipString',...
                'Go to end of track','ClickedCallBack',{@obj.GoToEnd},'Separator','on');
            go2endpushtool.CData=imresize(imread('RightArrow.jpg'),[16 16]);
            
            %Create display table
            %             fate=obj.TableData.('Fate');
            %             obj.TableData=structfun(@(x) num2cell(x), rmfield(obj.TableData,{'Daughter_IDs'}),'UniformOutput',0);
            obj.CntrlObj=TrackCollection.CntrlObj;
            CreateTable(TrackCollection); % update tbl
            obj.PedigreeData=CreateCloneFiles(TrackCollection);
            obj.TableData=TrackCollection.SubTable();
            obj.TableData=rmfield(obj.TableData,{'Daughter_IDs'});
            
            numbtracks=length(obj.TableData.Track_ID);
            obj.DisplayTableData=cell(numbtracks,length(fieldnames(obj.TableData)));
            for i=1:numbtracks
                %                 obj.DisplayTableData(i,:)=structfun(@(x) x{i},obj.TableData,'UniformOutput',0)';
                obj.DisplayTableData(i,:)=structfun(@(x) getfield(x,{i}),obj.TableData)';
            end
            
            fnames=fieldnames(obj.TableData);
            %             fnames=fnames{7:end}; %including the 7 default headings below
            heading={'Track_ID','Parent_ID','Ancestor_ID','Progeny_ID','Generation','Fate'};
            %uitable
            obj.TableHandle=uitable(obj.TableFigureHandle,'Data',[obj.DisplayTableData],'ColumnWidth',{100 100 100},...
                'ColumnName',fnames,'units','Normalized','Position',[0 0 1 1]);
            set(obj.TableHandle,'CellSelectionCallback',@obj.TrackTableSelection);
            
        end
        
        function TrackTableSelection(obj,hObject,EventData)
            row=EventData.Indices(1);
            hTrackPad=obj.CntrlObj;
            hTrackPad.Tracks.CurrentTrackID=cell2mat(obj.DisplayTableData(row,1));
            hTrackPad.Track=hTrackPad.Tracks.Tracks(hTrackPad.Tracks.CurrentTrackID).Track;
%             PedigreeID=cell2mat(obj.DisplayTableData(row,2)); % whoops RN
%             ProgenyID=cell2mat(obj.DisplayTableData(row,3));
            PedigreeID=cell2mat(obj.DisplayTableData(row,3)); % ancestor?
            ProgenyID=cell2mat(obj.DisplayTableData(row,4));
            displaystring={['Pedigree ' num2str(PedigreeID)] ['Track ' num2str(ProgenyID)]};
            displaystring=textwrap(hTrackPad.TrackPanel.CurrentTrackDisplay,displaystring);
            hTrackPad.TrackPanel.CurrentTrackDisplay.String=displaystring;
            hTrackPad.TrackPanel.CurrentTrackDisplay.ForegroundColor='green';
            % display pedigree diagram
            clone=obj.PedigreeData;
            obj.PlotTree(clone,PedigreeID,ProgenyID)
        end
        
        function ReturnToStart(varargin)
            obj=varargin{1};
            hTrackPad=obj.CntrlObj;
            return2starthandle=findall(hTrackPad.FigureHandle,'TooltipString','Go to start of track');
            return2startcallback=get(return2starthandle,'ClickedCallback');
            return2startcallback{1}(return2starthandle,[],hTrackPad);
        end
        
        function GoToEnd(varargin)
            obj=varargin{1};
            hTrackPad=obj.CntrlObj;
            go2endhandle=findall(hTrackPad.FigureHandle,'TooltipString','Go to end of track');
            go2endcallback=get(go2endhandle,'ClickedCallback');
            go2endcallback{1}(go2endhandle,[],hTrackPad);
        end
        
        function DeleteFigure(obj,scr,eventdata)
            if ~isempty(obj.PedigreeFigureHandle)
                if isvalid(obj.PedigreeFigureHandle)
                    close(obj.PedigreeFigureHandle);
                end
            end
        end
        

        
    end
    
    methods(Static=true)
        
        
        
        
        function getPedigreeData(hObject,EventData,hTrackTable)
            
            %get annotations and their transitions
            annotationmatrix=hTrackTable.getAnnotations(hTrackTable); %get annotation matrix
            [pathname]=uigetdir(cd,'Select director for saving pedigree data');
            [annotations,transitions]=hTrackTable.getTransitions(hTrackTable,annotationmatrix); %get unique annotations and their transitions
            
            writetable(struct2table(transitions),[pathname '\transitions.txt']); %write to txt file
            transitions=readtable([pathname '\transitions.txt']);
            header=cellfun(@(x) strrep(x,'transition_index','unique_annotations'),transitions.Properties.VariableNames(1:end/2),'UniformOutput',0);
            
            writetable(struct2table(annotations),[pathname '\annotations.txt'],'WriteVariableNames',0);
            fid=fopen([pathname '\annotations.txt'],'r');
            annotations=textscan(fid,repmat('%s',[1 length(header)]),'CollectOutput',true,'Delimiter',',');
            annotations=cell2table(annotations{:});
            annotations.Properties.VariableNames=header(:);
           
            
            %get fate outcomes as numeric code
            for i=1:length(hTrackTable.TableData.Fate)
                switch hTrackTable.TableData.Fate{i}
                    case 'DI'
                        hTrackTable.TableData.FateNumber(i)=1;
                    case 'DE'
                        hTrackTable.TableData.FateNumber(i)=2;
                    case 'NC'
                        hTrackTable.TableData.FateNumber(i)=0;
                    case 'LO'
                        hTrackTable.TableData.FateNumber(i)=3;
                end
            end
            hTrackTable.TableData.FateNumber=hTrackTable.TableData.FateNumber';
            hTrackTable.TableData.Parent_ID=hTrackTable.TableData.Parent_ID';
            
            %get birth, death, and life times
            timestamps=hTrackTable.CntrlObj.ImageStack.AcquisitionTimes;
            birthndx=cellfun(@(x) x(1),hTrackTable.CntrlObj.Tracks.tbl.Image_Number,'UniformOutput',0);
            birthtimes=timestamps([birthndx{:}])'-timestamps(1);
            deathndx=cellfun(@(x) x(end),hTrackTable.CntrlObj.Tracks.tbl.Image_Number,'UniformOutput',0);
            deathtimes=timestamps([deathndx{:}])'-timestamps(1);
            lifetimes=(deathtimes-birthtimes);
            
            %get annotations
            fnames=fieldnames(hTrackTable.TableData);
            fnames=fnames(7:end-1);
            annotationtable=hTrackTable.DisplayTableData(:,7:end);
            
            %get average distance measurements
            allclones={hTrackTable.PedigreeData};
            distancedata=hTrackTable.getDistanceData(allclones);
            meandistances=[];
            for i=1:size(distancedata.clone,2)
                meandistances=[meandistances;[distancedata.clone(i).cell.mean]'];
            end
            
            %prompt user to input condition name
            condition=inputdlg('Enter condition name: ', 'Input pedigree name or treatment condition',1,{'Experiment XX'});
            
            %assemble all pedigree data
            pedigreedata=[[hTrackTable.TableData.Track_ID{:}]',[hTrackTable.TableData.Parent_ID{:}]',...
                [hTrackTable.TableData.Ancestor_ID{:}]',[hTrackTable.TableData.Progeny_ID{:}]',...
                [hTrackTable.TableData.Generation_ID{:}]',hTrackTable.TableData.FateNumber,...
                birthtimes,deathtimes,lifetimes,meandistances];
            heading={'Condition','TrackID' 'ParentID' 'AncestorID' 'ProgenyID' 'Generation' 'Fate' ...
                'BirthTime' 'StopTime' 'Lifetime','MeanDistance',fnames{:}};
            oldpath=cd(pathname);
            [filename,pathname]=uiputfile('*.txt','Save pedigree data as');
            cd(oldpath);
            fid = fopen([pathname filename], 'wt');
            fprintf(fid,'%s,',heading{1:end-1});
            fprintf(fid,'%s\n',heading{end});
            
            for i=1:size(pedigreedata,1)
                numericalrowdata=pedigreedata(i,:);
                stringrowdata=annotationtable(i,:);
                fprintf(fid,'%s,',condition{:});
                fprintf(fid,'%f,',numericalrowdata(1:end));
                fprintf(fid,'%s,',stringrowdata{1:end-1});
                fprintf(fid,'%s\n',stringrowdata{end});
                %               fprintf(fid,'%f\n',rowdata(end));
            end
            fclose(fid);
            
            %write annotation table
            writetable([annotations transitions],[pathname filename(1:end-4),' annotations' '.txt'],'WriteVariableNames',1);
            
        end
        
        function [annotations,transitions]=getTransitions(hTrackTable,annotationmatrix)
            
            
            for i=1:length(annotationmatrix)
%                 disp(['Processing track ' num2str(i)]);
                feature=annotationmatrix(i);
                timestamps=feature.timestamps;
                feature=rmfield(feature,'timestamps');
                
                if length(timestamps)>=1
                [transitionndx,unique_annotations]=structfun(@getTransitionTimes ,feature,'UniformOutput',0);
                
                transitiontimes=structfun(@(x) timestamps(x),transitionndx,'UniformOutput',0);
                
                elseif isempty(timestamps) %for cells with only 2 frames (they don't have annotation subsets)
                    
                transitionndx=structfun(@(x) 1 ,feature,'UniformOutput',0);
                unique_annotations=structfun(@(x) 'NA' ,feature,'UniformOutput',0);
                
                transitiontimes=structfun(@(x) 0,transitionndx,'UniformOutput',0);
                    
                end
                
                unique_annotations=struct2table(unique_annotations);
                transitiontimes=struct2table(transitiontimes);
                transitionndx=struct2table(transitionndx);
                
                transitiontimes.Properties.VariableNames=cellfun(@(x) strcat(x,'_transition_time'),...
                    transitiontimes.Properties.VariableNames,'UniformOutput',0);
                
                transitionndx.Properties.VariableNames=cellfun(@(x) strcat(x,'_transition_index'),...
                    transitionndx.Properties.VariableNames,'UniformOutput',0);
                
                unique_annotations.Properties.VariableNames=cellfun(@(x) strcat(x,'_unique_annotations'),...
                    unique_annotations.Properties.VariableNames,'UniformOutput',0);
                
                transitiontable=[transitionndx transitiontimes];
                
                if i==1
                    transitions=table2struct(transitiontable);
                    annotations=table2struct(unique_annotations);
                elseif i>1
                    transitions(i)=table2struct(transitiontable);
                    annotations(i)=table2struct(unique_annotations);
                end
                
            end
            
            function [transitionndx,unique_annotations]=getTransitionTimes(AnnotationSubset)
                unique_annotations=unique(AnnotationSubset);
                
                if length(unique_annotations)>1
                    forwardtransition=strcmp(AnnotationSubset,AnnotationSubset{1});
                    transitionndx=[1 find(diff(forwardtransition))+1];
                    unique_annotations=AnnotationSubset(transitionndx);
                elseif length(unique_annotations)==1
                    transitionndx=1;
                end
                return
            end
            
            return
        end
        
        
        function getTrajectories(hObject,EventData,hTrackTable)
            allclones={hTrackTable.PedigreeData};
            distancedata=hTrackTable.getDistanceData(allclones);

            timestamps=distancedata.TimeStamps;



            distancetable=zeros(length(timestamps),1);
            condition='condition';
            for i=1:length(hTrackTable.TableData.Track_ID)
                %                 disp([num2str(i)]);

                T=timestamps(hTrackTable.CntrlObj.Tracks.tbl.Image_Number{i});
                T=(T-T(1))';
                X=hTrackTable.CntrlObj.Tracks.tbl.Position{i}(:,1);
                Y=hTrackTable.CntrlObj.Tracks.tbl.Position{i}(:,2);

                if i==1
                    distancetable(1:length(T),1)=X;
                    distancetable(1:length(T),end+1)=Y;
                    distancetable(1:length(T),end+1)=T;
                else
                    distancetable(1:length(T),end+1)=X;
                    distancetable(1:length(T),end+1)=Y;
                    distancetable(1:length(T),end+1)=T;
                end
            end
            [filename,pathname]=uiputfile('*.txt','Save cell trajectories as');
            fid = fopen([pathname filename], 'wt');
            heading=repmat(1:i,3,1);
            heading=reshape(heading,[1 i*3]);
            heading=arrayfun(@(x) {num2str(x)},heading);
            heading=strcat({'Track'},heading);
            heading=strcat(heading,repmat({'_X' '_Y' '_T'},1,i));
            fprintf(fid,'%s,',heading{1:end-1});
            fprintf(fid,'%s\n',heading{end});

            for i=1:size(distancetable,1)
                rowdata=distancetable(i,:);
                fprintf(fid,'%f,',rowdata(1:end-1));
                fprintf(fid,'%f\n',rowdata(end));
            end
            fclose(fid);
        end

        function track=getAnnotations(varargin)
            if length(varargin)==3
                hTrackTable=varargin{3};
                [filename,pathname]=uiputfile('*.txt','Save annotation data as');
            elseif length(varargin)==1
                hTrackTable=varargin{:};
            end
            annotations=fieldnames(hTrackTable.CntrlObj.CellProperties(3).String);
            ndx=cellfun(@(x) ~strcmp(x,'PedigreeID'),annotations);
            annotations=annotations(ndx); %remove PedigreeID
            numb_tracks=length(hTrackTable.CntrlObj.Tracks.Tracks);
            track=struct();
            for i=1:numb_tracks
                
                firstframe=hTrackTable.CntrlObj.Tracks.Tracks(i).Track.trackrange(1);
                lastframe=hTrackTable.CntrlObj.Tracks.Tracks(i).Track.trackrange(2);
                times=hTrackTable.CntrlObj.ImageStack.AcquisitionTimes(firstframe:lastframe)-hTrackTable.CntrlObj.ImageStack.AcquisitionTimes(firstframe);
                track(i).timestamps=times(2:end-1); %dont' include first and last time point (no annotations for these timepoints)
                for j=1:length(annotations)
                    
                    if i==1
                        setfield(track(i),annotations{j},[]);
                    end
                    track(i).(annotations{j})=cell(1,range(firstframe:lastframe)-1);
                    count=1;
                    
                    for k=(firstframe+1):(lastframe-1)
                        track(i).(annotations{j}){count}=hTrackTable.CntrlObj.Tracks.Tracks(i).Track.Track{k}.Annotation.Symbol.(annotations{j});
                        count=count+1;
                    end
                end
                
            end
            numb_annotations=length(hTrackTable.CntrlObj.ImageStack.AcquisitionTimes-2);
            for i=1:length(hTrackTable.TableData.Track_ID)
%                 disp(['Processing track ' num2str(i)]);
                T=track(i).timestamps;
                T(end+1:numb_annotations)=NaN;
                AnnotationTable=[table(zeros(numb_annotations,1),'VariableNames',{'Time'})...
                    cell2table(repmat(cell(numb_annotations,1),1,length(annotations)),'VariableNames',annotations')];
                AnnotationTable.Time=T';
                for j=1:length(annotations)
                    feature=track(i).(annotations{j});
                    [uniquefeatures,transitionndx,~]=unique(feature);
                    if length(uniquefeatures)>1
                        transitiontime=AnnotationTable.Time(transitionndx(2));
                    end
                    feature(end+1:numb_annotations)={NaN};
                    AnnotationTable.(annotations{j})=feature';
                end
                AnnotationTable.Properties.VariableNames=strcat(['Track_' num2str(i) '_'], ['Time' annotations']);
                if i==1
                    FinalTable=AnnotationTable;
                elseif i>1
                    FinalTable=[FinalTable AnnotationTable];
                end
            end
            if length(varargin)==3
                writetable(FinalTable,[pathname filename]);
            elseif length(varargin)==1
                return
            end
        end
        
        
        function getCellImages(hObject,EventData,hTrackTable)

            allclones=hTrackTable.PedigreeData;
            %             distancedata=GetCell(allclones);
            answer=inputdlg({['Select clones (1:', num2str(length(allclones)),')'],'Image patch width'},...
                'Select clones',[1,25],{['1:',num2str(length(allclones))],'250'});
            clone_IDs=sscanf(answer{1},'%d:%d');
            if length(clone_IDs)==2
                clone_IDs=[clone_IDs(1):clone_IDs(2)];
            end
            hTrackTable.CellImagePatchBuffer=str2double(answer{2});
            %             tracknumb=hTrackTable.PedigreeData;
            timestamps=hTrackTable.CntrlObj.ImageStack.AcquisitionTimes;
            maxtracks=max([hTrackTable.TableData.Progeny_ID{:}]);
            
            pathname=uigetdir(hTrackTable.CntrlObj.TrackPath,'Select directory to save images');
            
%             answer=inputdlg('Enter image width (in pixels)','Create Image Patches',1,{'250'});
%             hTrackTable.CellImagePatchBuffer=str2num(answer{:});
            %             buffer=250;

            
            imagestack=hTrackTable.CntrlObj.ImageStack;
            hTrackTable.PedigreeData=hTrackTable.SaveCellImages(allclones,clone_IDs,1:maxtracks,...
                hTrackTable.CellImagePatchBuffer,pathname,imagestack);
            hTrackTable.CntrlObj.SaveTracks(hObject,EventData,hTrackTable.CntrlObj);
            
        end
        
        %exports tracks in clone file format - can be used with SegmentCell
        function getCloneFile(hObject,EventData,hTrackTable)
            savepath=uigetdir([hTrackTable.CntrlObj.TrackPath],'Select location to save clone file');
            clone=hTrackTable.PedigreeData;
            CloneFileName=strrep(hTrackTable.CntrlObj.TrackFile ,'trackfile.mat','clonefile.mat');
           
            if exist([savepath '\' CloneFileName],'file')
                clonefile=clone; %trackpad clonefile
                load([savepath '\' CloneFileName]); %loading 'clone' file from directory
                is_mask_flag=hTrackTable.CheckCegmentedMasks(clone);
               
                if is_mask_flag
                    disp('Clone file already contains segmented masks');
                    answer=questdlg('Clone file already exists do you want to merge or overwrite?','TrackPad','Merge','Overwrite','Cancel');
                    
                    if strcmp(answer,'Merge')
                        %function to merge clone files if one alreay contains segmented cell masks
                        clone=hTrackTable.MergeCloneFiles(clone,clonefile);
                        save([savepath '\' CloneFileName],'clone');
                    elseif strcmp(answer,'Overwrite')
                        disp('Overwriting clone file..');
                        save([savepath '\' CloneFileName],'clone');
                    end
                    
                elseif ~is_mask_flag
                    clone=clonefile;
                    disp('Updating clone file');
                    save([savepath '\' CloneFileName],'clone');
                end
                
            elseif ~exist([savepath '\' CloneFileName],'file')
                disp('Saving clone file');
                save([savepath '\' CloneFileName],'clone');
                
            end
            
        end
        
        function condition=getDistanceData(allclones)
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

                if isfield(cond_clone{1},'TimeStamps')
                condition(i).TimeStamps=cond_clone{1}.TimeStamps;
                elseif isfield(cond_clone{1},'timestamps')
                condition(i).TimeStamps=cond_clone{1}.timestamps;
                end

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
        function clone=SaveCellImages(clone,clonenumb,tracknumbers,buff,path,imagestack)           
            imageobj=imagestack;                
            for h=1:length(clonenumb)
                disp(['Processing clone ' num2str(clonenumb(h))]);
                currentclone=clonenumb(h);
                if length(clone{1, currentclone}.track)<max(tracknumbers)
                    tracknumb=min(tracknumbers):length(clone{1, currentclone}.track);
                    disp(['Clone ' num2str(clonenumb(h))...
                        ' only has ' num2str(length(tracknumb))...
                        ' tracks -> processing ' num2str(length(tracknumb)) ' tracks']);
                else
                    tracknumb=tracknumbers;
                end
                hwait=waitbar(0,['Saving clone ',num2str(clonenumb(h))]);
                for i=1:length(tracknumb)                        
                    disp(['Processing track ' num2str(tracknumb(i))]);
                    %figure();
                    %set(gcf, 'Position', get(0, 'Screensize'));
                    subpath=['Clone ' num2str(currentclone) '\Track ' num2str(tracknumb(i))];
                    if ~isdir([path subpath])
                        mkdir(path,subpath);
                    end
                    %initialise moviewriter 
                    % comment: this code is not generic, needs to be
                    % modified in the future (RN)
                    writerObj=VideoWriter([path '\' subpath '.avi']); %create writerobj
                    writerObj.FrameRate=5;
                    imagetimes=clone{currentclone}.track{tracknumb(i)}.T;                   
                    open(writerObj);

                    %loop depending on number of image files, rather than timepoints -
                    %as it may be different for phase and GFP channels
                    for j=1:1:length(imagetimes)
                        time=imagetimes(j);
                        disp(['Processing frame ' num2str(j)]);
                        [cellimage,relframeid]=...
                            TrackNavigator.GetCellImagePatches(clone,currentclone,...
                            tracknumb(i),time,buff,imageobj);
                        if j==1
                            [r,c,~]=size(cellimage);
                            movieimage=cellimage;
                        elseif j>1  && (size(cellimage,1)~=r || size(cellimage,2)~=c)
                            movieimage=imresize(cellimage,[r c]);
                            %                 grayim(grayim(:)>1)=1; grayim(grayim(:)<0)=0;
                        else
                            movieimage=cellimage;
                        end
                        try
                        writeVideo(writerObj,movieimage);
                        catch
                            disp('here');
                        end
                        %save image as .tiff
                        frameid=find(relframeid==1);
%                         clone{currentclone}.track{tracknumb(i)}.CropCoordinates{frameid}=crop_coordinates;
                        timestamp=datestr(clone{currentclone}.track{tracknumb(i)}.T(frameid));
                        imwrite(cellimage,[path '\' subpath '\Frame ' num2str(frameid) '.tif'],'Description',timestamp);
                    end
                    close(writerObj);
                    waitbar(i/length(tracknumb),hwait);
                end
                delete(hwait);
            end
        end
        
        function [cellimage,relframeid]=GetCellImagePatches(clone,cloneid,trackid,time,buff,imageobj)

            frameid=find(clone{cloneid}.TimeStamps==time); %absolute frame id
            relframeid=clone{cloneid}.track{trackid}.T(:)==time; %frame id rel to cell birth

            x=clone{cloneid}.track{trackid}.X(relframeid);
            y=clone{cloneid}.track{trackid}.Y(relframeid);
            crop_coordinates=floor([x-buff/2,y-buff/2,buff-1,buff-1]);                     
            cdata=imageobj.CData(:,:,frameid); cmap=imageobj.CMap{frameid};
            [r,c]=size(cdata);
            
            cellimage=imcrop(cdata,crop_coordinates);
            cellimage=ind2rgb(cellimage,cmap);
            % augment cellimage if it is smaller than buffxbuff
            if size(cellimage,1)<buff % outside of top or bottom
                if crop_coordinates(2)<1 %top
                    black_rows=zeros(-crop_coordinates(2)+1,size(cellimage,2),3);
                    cellimage=cat(1,black_rows,cellimage);
                else % bottom
                    black_rows=zeros(crop_coordinates(2)+crop_coordinates(4)-r,size(cellimage,2),3);
                    cellimage=cat(1,cellimage,black_rows);
                end
            elseif size(cellimage,2)<buff % outside right or left of image
                if crop_coordinates(1)<1 %left
                    black_cols=zeros(size(cellimage,1),-crop_coordinates(1)+1,3);
                    cellimage=cat(2,black_cols,cellimage);
                else %right
                    black_cols=zeros(size(cellimage,1),crop_coordinates(1)+crop_coordinates(3)-c,3);
                    cellimage=cat(2,cellimage,black_cols);
                end
            end
                
        end
        
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
    end
    
    

    
end

