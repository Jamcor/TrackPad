function im=getRGB(channel,stack)
        [r,c,~,~]=size(stack);
        im=zeros(r,c,3);
        Ndx=channel.filesList.Value;
        if Ndx>0
            Colour=channel.colourlist.String{channel.colourlist.Value};
            switch(channel.loadPB.Tag)
                case 'LoadCh1PB'
                    v=squeeze(stack(:,:,1,Ndx));
                otherwise
                    v=imread([channel.imfinfo(Ndx).Filename]);
            end
            v=double(v);
            % adjust for intensity
            v=v*double(channel.IntensitySlider.Value);
            %adjust for lower and upper threshold
            min_v=0;
            try
            max_v=2^channel.imfinfo(Ndx).BitDepth-1;
            diff=(max_v-min_v);    
            lo=min_v+diff*double(channel.DualThresholdSlider.LowValue)/100;
            hi=min_v+diff*double(channel.DualThresholdSlider.HighValue)/100;
            v=mat2gray(v,[lo hi]);
            catch
                disp('here');
            end
            % adjust for intensity
%             v=v*double(channel.IntensitySlider.Value);

            
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