classdef TrackTable < handle
    
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
        
    end
    
    events
        
        
    end
    
    
    methods
        
        
        function CreateTrackTable(obj)
            obj.TableFigureHandle=figure('Name','TrackTable','Toolbar','figure','MenuBar','none'); %start figure
            %get and set toolbar children handles to visible (default is not visible) so new buttons
            %can be added to existing 'figure' toolbar instead of creating
            
            %new dropdown menus
            FileMenuHandle = uimenu(obj.TableFigureHandle,'Label','File');
            uimenu(FileMenuHandle,'Label','Open Tracks',...
                'Callback',{@obj.OpenTracks,obj});
            uimenu(FileMenuHandle,'Label','Save Tracks',...
                'Callback',{@obj.SaveTracks,obj});
            uimenu(FileMenuHandle,'Label','Quit',...
                'Callback',{@obj.CloseTrackTable,obj});
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
            delete(toolbarhandle([1:9,12:end]));
            
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
            PedigreeID=cell2mat(obj.DisplayTableData(row,2));
            ProgenyID=cell2mat(obj.DisplayTableData(row,3));
            displaystring={['Pedigree ' num2str(PedigreeID)] ['Track ' num2str(ProgenyID)]};
            displaystring=textwrap(hTrackPad.TrackPanel.CurrentTrackDisplay,displaystring);
            hTrackPad.TrackPanel.CurrentTrackDisplay.String=displaystring;
            hTrackPad.TrackPanel.CurrentTrackDisplay.ForegroundColor='green';
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
        
    end
    
    methods(Static=true)
        
        function getPedigreeData(hObject,EventData,hTrackTable)
            
            %get annotations and their transitions
            annotationmatrix=hTrackTable.getAnnotations(hTrackTable); %get annotation matrix
            
            [annotations,transitions]=hTrackTable.getTransitions(hTrackTable,annotationmatrix); %get unique annotations and their transitions
            
            writetable(struct2table(transitions),'transitions.txt'); %write to txt file
            transitions=readtable('transitions.txt');
            header=cellfun(@(x) strrep(x,'transition_index','unique_annotations'),transitions.Properties.VariableNames(1:end/2),'UniformOutput',0);
            
            writetable(struct2table(annotations),'annotations.txt','WriteVariableNames',0);
            
            fid=fopen('annotations.txt','r');
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
            distancedata=getTrajectories(allclones);
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
            
            [filename,~]=uiputfile('*.txt','Save pedigree data as');
            fid = fopen(filename, 'wt');
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
            writetable([annotations transitions],strrep(filename,'.txt','_annotations.txt'),'WriteVariableNames',1);
            
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
                    distancedata=getTrajectories(allclones);
        
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
                    [filename,~]=uiputfile('*.txt','Save cell trajectories as');
                    fid = fopen(filename, 'wt');
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
            maxclones=length(allclones);
            %             tracknumb=hTrackTable.PedigreeData;
            timestamps=hTrackTable.CntrlObj.ImageStack.AcquisitionTimes;
            maxtracks=max([hTrackTable.TableData.Progeny_ID{:}]);
            
            pathname=uigetdir(hTrackTable.CntrlObj.TrackPath,'Select directory to save images');
            if ~isdir([pathname '\SegmentedCells'])
                mkdir([pathname '\SegmentedCells']);
                pathname=[pathname '\SegmentedCells\'];
            else isdir([pathname '\SegmentedCells'])
                pathname=[pathname '\SegmentedCells\'];
            end
            
            answer=inputdlg('Enter buffer size (in pixels)','Create Image Patches',1,{'250'});
            hTrackTable.CellImagePatchBuffer=str2num(answer{:});
            %             buffer=250;
            channels={'Phase'};
            
            imagestack=hTrackTable.CntrlObj.ImageStack;
            hTrackTable.PedigreeData=GetCellImagesv2(allclones,1:maxclones,1:maxtracks,...
                hTrackTable.CellImagePatchBuffer,pathname,channels,imagestack);
            
        end
        
        %exports tracks in clone file format - can be used with SegmentCell
        function getCloneFile(hObject,EventData,hTrackTable)
            savepath=uigetdir([hTrackTable.CntrlObj.TrackPath],'Select location to save clone file');
            clone=hTrackTable.PedigreeData;
            CloneFileName=strrep(hTrackTable.CntrlObj.TrackFile ,'trackfile.mat','clonefile.mat');
           
            if exist([savepath '\' CloneFileName],'file')
                clonefile=clone; %trackpad clonefile
                load([savepath '\' CloneFileName]); %loading 'clone' file from directory
                is_mask_flag=CheckCegmentedMasks(clone);
               
                if is_mask_flag
                    disp('Clone file already contains segmented masks');
                    answer=questdlg('Clone file already exists do you want to merge or overwrite?','TrackPad','Merge','Overwrite','Cancel');
                    
                    if strcmp(answer,'Merge')
                        %function to merge clone files if one alreay contains segmented cell masks
                        clone=MergeCloneFiles(clone,clonefile);
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
        
    end
    
end

