classdef TrackTable < handle
    
    properties
        TableFigureHandle
        ToolBarHandle
        TableContextMenu
        TableHandle
        TableData
        DisplayTableData
        Tracks=[]
        CntrlObj
        
    end
    
    events
        
        
    end
    
    
    methods
        
        
        function CreateTrackTable(obj)
            obj.TableFigureHandle=figure('Name','TrackTable','Toolbar','figure','WindowStyle','docked'); %start figure
            %get and set toolbar children handles to visible (default is not visible) so new buttons
            %can be added to existing 'figure' toolbar instead of creating
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
            fate=obj.TableData.('Fate');
            trackscell=structfun(@(x) num2cell(x), rmfield(obj.TableData,{'Daughter_IDs','Fate'}),'UniformOutput',0);
            numbtracks=length(trackscell.Track_ID);
            obj.DisplayTableData=cell(numbtracks,length(fieldnames(trackscell)));
            for i=1:numbtracks
                obj.DisplayTableData(i,:)=structfun(@(x) x(i),trackscell)';
            end
            
            %uitable
            obj.TableHandle=uitable(obj.TableFigureHandle,'Data',[obj.DisplayTableData,fate],'ColumnWidth',{100 100 100},'ColumnName',...
                {'Track_ID','Ancestor_ID','Progeny_ID','Generation','Parent_ID','Fate'},...
                'units','Normalized','Position',[0 0 1 1]);
            set(obj.TableHandle,'CellSelectionCallback',@obj.TrackTableSelection);
            
        end
        
%         function tracks=SubTable(tracktable)
%             %subset data from track table
% %             subtable=tracktable.TableData{:,{'Track_ID','Parent_ID'}};
% %             annotations=tracktable.TableData{:,'Annotation_Symbol'};
% %             ndx=cellfun(@(x) length(x)>2,annotations);
% %             subtable=subtable(ndx,:);
% %             annotations=annotations(ndx);
% %             fate=cellfun(@(x) [x{end}],annotations,'UniformOutput',0);
%             
%             %create struct for faster processing
%             tracks=[];
%             tracks.Track_ID=subtable(:,1);
%             tracks.Parent_ID=subtable(:,2);
%             tracks.Fate=fate;
%             tracks.Generation_ID=zeros(length(tracks.Track_ID),1);
%             tracks.Daughter_IDs=cell(length(tracks.Track_ID),1);
%             tracks.Ancestor_ID=zeros(length(tracks.Track_ID),1);
%             tracks.Progeny_ID=zeros(length(tracks.Track_ID),1);
%             tracks.Track_ID=(1:length(tracks.Track_ID))';
%             
%             for i=1:length(tracks.Track_ID)
%                 k=i;
%                 while ~isnan(tracks.Parent_ID(k))
%                     k=tracks.Parent_ID(k);
%                 end
%                 tracks.Ancestor_ID(i)=k;
%             end
%             ndx=~isnan(tracks.Parent_ID);
%             Parents=unique(tracks.Parent_ID(ndx));
%             for i=1:length(Parents)
%                 Parent_ndx=tracks.Track_ID==Parents(i);
%                 Daughter_ndx=tracks.Parent_ID==Parents(i);
%                 tracks.Daughter_IDs{Parent_ndx}=(tracks.Track_ID(Daughter_ndx))';
%             end
%             
%             for i=1:max(tracks(:).Ancestor_ID) %loop through ancestors
%                 ancestorndx=find(tracks(:).Ancestor_ID==i); % get ndx for all cells within pedigree
% %                 disp(['anc ' num2str(i)]);
%                 for j=1:length(ancestorndx) %Loop through all cells in pedigree
% %                     disp(['cell ' num2str(j)]);
%                     
%                     parentid=tracks.Parent_ID(ancestorndx(j));
%                     daughterid=tracks.Daughter_IDs{ancestorndx(j)}; %get parent and daughter ids
%                     
%                     if isnan(parentid) %parent cell
%                         
%                         tracks.Progeny_ID(ancestorndx(j))=1;
%                         tracks.Generation_ID(ancestorndx(j))=0;
%                         %if there are daughters
%                         if ~isempty(daughterid)
%                             tracks.Progeny_ID(daughterid(1))=2;
%                             tracks.Progeny_ID(daughterid(2))=3;
%                             tracks.Generation_ID(daughterid(1))=1;
%                             tracks.Generation_ID(daughterid(2))=1;
%                         end
%                         
%                     elseif ~isnan (parentid) && ~isempty(daughterid) %daughters
%                         
%                         progenyid=tracks.Progeny_ID(ancestorndx(j));
%                         tracks.Progeny_ID(daughterid(1))=progenyid*2;
%                         tracks.Progeny_ID(daughterid(2))=progenyid*2+1;
%                         tracks.Generation_ID(daughterid(1))=progenyid/2;
%                     end
%                     
%                 end
%             end
%             
%             return
%         end
        
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
    
end

