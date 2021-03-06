function JSliderCallback(hObject,EventData)
% updates current image colormap when and JSlider object changes
% Channel 1 data
try
    obj=guidata(findobj('Name','Channel mixer'));
catch
    disp('here');
end
    if ~isempty(obj)
        if isfield(obj.ch1,'stack') % only if stack loaded
            im=getRGB(obj.ch1);    
            if isfield(obj.ch2,'stack')
                im=im+getRGB(obj.ch2);
            end
            if isfield(obj.ch3,'stack')
                im=im+getRGB(obj.ch3);
            end
            im(im(:)>1)=1; % remove anything brighter than 1
            [r,c,~]=size(im);
            n=size(obj.ch1.stack,4);
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

    function im=getRGB(channel)
        [r,c,~,~]=size(channel.stack);
        im=zeros(r,c,3);
        Ndx=channel.filesList.Value;
        if Ndx>0
            Colour=channel.colourlist.String{channel.colourlist.Value};
            v=squeeze(channel.stack(:,:,1,Ndx));
            %adjust for lower and upper threshold
            min_v=0;
            try
            max_v=2^channel.imfinfo(Ndx).BitDepth-1;
            diff=max_v-min_v;    
            lo=min_v+diff*double(channel.DualThresholdSlider.LowValue)/100;
            hi=min_v+diff*double(channel.DualThresholdSlider.HighValue)/100;
            v=mat2gray(v,[lo hi]);
            catch
                disp('here');
            end
            % adjust for intensity
            v=v*double(channel.IntensitySlider.Value)/100;

            
            switch(Colour)
                case 'phase/DIC'
                    im(:,:,1)=v;
                    im(:,:,2)=v;
                    im(:,:,3)=v;
                case 'green'
                    im(:,:,2)=v;
                case 'red'
                    im(:,:,1)=v;
                case 'blue'
                    im(:,:,3)=v;
                case 'yellow' % red and green channel
                    im(:,:,1)=v;
                    im(:,:,2)=v;
            end
        end
    end
end