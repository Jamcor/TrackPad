classdef controllerbak < handle
    %Controller of Cell Tracking interface

    
    properties
        SlaveState
       
    end
    
    events
        RunEvent
    end
    
    
    
    methods
        function obj=controllerbak
            %varargin lists the objects that the controller controls, only
            %need to include the superclass objects (and not their
            %subclasses)
            s.state='';
            s.class='';
            obj.SlaveState=s;
            % set up 'property listeners' 
            
            
           
            
        end
            
        function display(obj,src,event)
            switch class(obj)
                case 'testcounter'
                    switch event
                        case 'CounterState'
                            disp(['Counter state is ' scr.State]);
                    end
            end
        end

        function start(obj)
            for i=1:20
                state=obj.SlaveState.state;
                switch(state)
                    case 'StopCount'
                        obj.SlaveState.state='';
                        obj.SlaveState.class='';
                        break;
                end
                notify(obj,'RunEvent');
            end
        end      
    end
    
end

