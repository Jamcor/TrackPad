classdef testcounter < handle
    % test counter for testing controller module and interuptibility
    %   Detailed explanation goes here
    
    properties
        count=1000;
        currentcount=0;
        stop=false
        hlistener
        hwaitbar
    end
    
    events
        CounterState
    end
    
    methods
        function obj=testcounter(count,masterobj)
            if nargin==2
                obj.hlistener=event.listener(masterobj,'RunEvent',@obj.runcounterEvent);
                obj.count=count;
            elseif nargin==1
                obj.count=count;
            end
            obj.hwaitbar=waitbar(0,'Please wait ... ');
        end
        %listerner event handlers
        function runcounterEvent(obj,src,event)
            if obj.currentcount<=obj.count
                pause(1);
                if ~ishandle(obj.hwaitbar)
                    obj.hwaitbar=waitbar(0,'Please wait ... ');
                end
                obj.currentcount=obj.currentcount+1;
                waitbar(obj.currentcount/obj.count,obj.hwaitbar); 
            else
                close(obj.hwaitbar);
                s.class=class(obj);
                s.state='StopCount';
                src.SlaveState=s;
                obj.currentcount=0; %reset
            end
                
        end
        
        function stopcounter(obj)
            obj.stop=true;
        end
        
        
    end
    
end

