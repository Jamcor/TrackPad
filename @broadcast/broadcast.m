classdef broadcast < handle
    % broadcast object can send interrupts to all objects that have
    % 'listeners'
    %   Detailed explanation goes here
    
    properties
        SlaveState
    end
    
    events
        StopEvent
        PauseEvent
        ContinueEvent
    end
    
    methods
        function obj=broadcast
            s.state='';
            s.class='';
            obj.SlaveState=s;
        end
        
        function interrupt(obj)
            notify(obj,'StopEvent');
        end
        
        function pausetracking(obj)
            notify(obj,'PauseEvent');
        end
        
        function continuetracking(obj)
            notify(obj,'ContinueEvent');
        end
    end
    
end

