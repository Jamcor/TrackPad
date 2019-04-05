function JSliderCallback(hObject,EventData)
% updates current image colormap when and JSlider object changes
% Channel 1 data
try
    obj=guidata(findobj('Name','Channel mixer'));
catch
    disp('here');
end
% only do this if thresholds change, otherwise slows program executure
    Thresholds=obj.ImageStackObj.Thresholds;
    Intensity=obj.ImageStackObj.Intensity;
    NewThresholds=[obj.ch1.DualThresholdSlider.LowValue,obj.ch1.DualThresholdSlider.HighValue;...
        obj.ch2.DualThresholdSlider.LowValue,obj.ch2.DualThresholdSlider.HighValue;...
        obj.ch3.DualThresholdSlider.LowValue,obj.ch3.DualThresholdSlider.HighValue];
    NewIntensity=[obj.ch1.IntensitySlider.Value,obj.ch2.IntensitySlider.Value,obj.ch3.IntensitySlider.Value];
    if (sum(Thresholds(:)==NewThresholds(:))~=6)||(sum(Intensity==NewIntensity)~=3)...
            ||(obj.ImageStackObj.CurrentNdx~=obj.ImageStackObj.LastNdx)
        if ~isempty(obj)
            if ~isempty(obj.ImageStackObj.Stack) % only if stack loaded
                obj.ImageStackObj.LastNdx=obj.ImageStackObj.CurrentNdx;
                obj.ImageStackObj.Thresholds=NewThresholds;
                obj.ImageStackObj.Intensity=NewIntensity;
                im=ImageStack.getRGB(obj.ch1,obj.ImageStackObj.Stack);    
                if isfield(obj.ch2,'imfinfo')
                    im=im+ImageStack.getRGB(obj.ch2,obj.ImageStackObj.Stack);
                end
                if isfield(obj.ch3,'imfinfo')
                    im=im+ImageStack.getRGB(obj.ch3,obj.ImageStackObj.Stack);
                end
                im(im(:)>1)=1; % remove anything brighter than 1
                [r,c,~]=size(im);
                CurrentNdx=obj.ch1.filesList.Value;

                [obj.CData(:,:,CurrentNdx),obj.CMap{CurrentNdx}]=rgb2ind(im,256);
                obj.image.CData=obj.CData(:,:,CurrentNdx);
                colormap(obj.CMap{CurrentNdx});
                obj.image.Parent=obj.haxes;
                obj.haxes.DataAspectRatioMode='manual';
                obj.haxes.XLim=[0,c];
                obj.haxes.YLim=[0,r];
                obj.haxes.DataAspectRatio=[1,1,1];
                guidata(obj.fhandle,obj);
            end
        end
    end
end

