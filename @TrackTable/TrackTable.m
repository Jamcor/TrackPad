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
            uimenu(ExportMenuHandle,'Label','Cell image patches',...
                'Callback',{@obj.getCellImages,obj});
            
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
            %assemble all pedigree data
            pedigreedata=[[hTrackTable.TableData.Track_ID{:}]',[hTrackTable.TableData.Parent_ID{:}]',...
                [hTrackTable.TableData.Ancestor_ID{:}]',[hTrackTable.TableData.Progeny_ID{:}]',...
                [hTrackTable.TableData.Generation_ID{:}]',hTrackTable.TableData.FateNumber,...
                birthtimes,deathtimes,lifetimes];
            heading={'TrackID' 'ParentID' 'AncestorID' 'ProgenyID' 'Generation' 'Fate' ...
                'BirthTime' 'StopTime' 'Lifetime',fnames{:}};
            
            [filename,~]=uiputfile('*.txt','Save pedigree data as');
            fid = fopen(filename, 'wt');
            fprintf(fid,'%s,',heading{1:end-1});
            fprintf(fid,'%s\n',heading{end});
            
            for i=1:length(pedigreedata)
                numericalrowdata=pedigreedata(i,:);
                stringrowdata=annotationtable(i,:);
                fprintf(fid,'%f,',numericalrowdata(1:end));
                fprintf(fid,'%s,',stringrowdata{1:end-1});
                fprintf(fid,'%s\n',stringrowdata{end}); 
%               fprintf(fid,'%f\n',rowdata(end));
            end
            fclose(fid);
        end
        
        
        function getTrajectories(hObject,EventData,hTrackTable)
            allclones={hTrackTable.PedigreeData};
            distancedata=getTrajectories(allclones);
            
            timestamps=distancedata.TimeStamps;
            
            distancetable=zeros(length(timestamps),1);
            condition='condition';
            for i=1:length(hTrackTable.TableData.Track_ID)
                disp([num2str(i)]);
                
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
        
        
        function getCellImages(hObject,EventData,hTrackTable)
            allclones=hTrackTable.PedigreeData;
            %             distancedata=GetCell(allclones);
            maxclones=length(allclones);
            %             tracknumb=hTrackTable.PedigreeData;
            timestamps=hTrackTable.CntrlObj.ImageStack.AcquisitionTimes;
            maxtracks=max([hTrackTable.TableData.Progeny_ID{:}]);
            
            pathname=uigetdir('Select directory to save images');
            
            buffer=250;
            channels={'Phase'};
            
            imagestack=hTrackTable.CntrlObj.ImageStack;
            GetCellImages(allclones,1:maxclones,1:maxtracks,buffer,pathname,channels,imagestack)
            
        end
                
    end
    
end

