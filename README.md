# TrackPad
This repository contains all MATLAB source code for TrackPad single-cell tracking software. 

# Contributors 
The TrackPad platform was developed by Dr Robert Nordon @ the University of New South Wales. 
Dr James Cornwell @ the University of Sydney has contributed to GUI development, user-experience, and computational speed.  

# Hardware and software requirements
*MATLAB 2015a or later (including Statistics and Machine Learning Toolbox, Image Processing Toolbox)
*Min. 16GB ram
*GPU optional, though increased tracking speed
*Image stack saved as .tif files (recommended max. 20 min acquisition frequency)

# General description
TrackPad is a software tool implemented in MATLAB that is used to track single cells (or any moving object) from time-lapse image stacks. 

# How to track cells
1. User loads an image stack of .tif files and adjust image properties using a Channel Mixing tool. Up to 3 different colours can     be loaded.
2. User saves image stack object from Step 1. 
3. User tracks cells using a combination of left and right mouse-clicks as well as drop-down menus
4. User annotates cell fate outcome and other relevant information
5. User saves tracks which can be edited or reviewed any time

A training video is provided in this repository. 

Any questions should be directed to Dr Robert Nordon (r.nordon@unsw.edu.au) or Dr James Cornwell (james.cornwell@sydney.edu.au)

February 2018
