function ModifyFigureMenu(FileMenuHandle)
jFileMenu = get(get(FileMenuHandle,'JavaContainer'),'ComponentPeer');
            color = java.awt.Color.white;
            jToolbar.setBackground(color);
            jToolbar.getParent.getParent.setBackground(color);  
            % Remove the toolbar border, to blend into figure contents
            jToolbar.setBorderPainted(false);
            % Remove the separator line between toolbar and contents
            jFrame = get(handle(obj.FigureHandle),'JavaFrame');
            jFrame.showTopSeparator(false);   
            jtbc = jToolbar.getComponents;
            for idx=1:length(jtbc)
            jtbc(idx).setOpaque(false);
            jtbc(idx).setBackground(color);
            for childIdx = 1 : length(jtbc(idx).getComponents)
            jtbc(idx).getComponent(childIdx-1).setBackground(color);
            end
            end
            
end