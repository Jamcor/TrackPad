# TrackPad
This repository contains all MATLAB source code for TrackPad single-cell tracking software. 

# Contributors 
The TrackPad platform was developed by Dr Robert Nordon @ the University of New South Wales. 
Dr James Cornwell @ NIH has contributed to GUI development, user-experience, and computational speed.  

# Standalone executable (Version 2.2)
Please install Microsoft SharePoint before download: 
https://unsw-my.sharepoint.com/:u:/g/personal/z9070419_ad_unsw_edu_au/EQc_JcKVS2dBhsaFIkP5iu0Br6HjEBVqVIIc45bN871Vxw?e=g2UTIn

# Download source code (Version 2.2)
Please install Microsoft SharePoint before download: 
https://unsw-my.sharepoint.com/:u:/g/personal/z9070419_ad_unsw_edu_au/ES_Q7_1JJENHi_-cNF5fPw8BEZIOZ1HwM_C7-EA_XViuCw?e=grWh7L

Usage: Unzip, and set MATLAB current directory to TrackPad Version 2.2 (contains @class subdirectories).

Command line: GUI=TrackPad; % creates a TrackPad GUI object.

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

# Training videos
Introduction http://thebox.unsw.edu.au/video/introduction8
1. http://thebox.unsw.edu.au/video/training-video-1-creating-imagestacks
2. http://thebox.unsw.edu.au/video/training-video-2-tracking-cells
3. http://thebox.unsw.edu.au/video/training-video-3-editing-tracks
4. http://thebox.unsw.edu.au/video/training-video-4-annotating-tracks
5. http://thebox.unsw.edu.au/video/training-video-5-selection-of-cctm-parameters
6. http://thebox.unsw.edu.au/video/training-video-6-avatar-simulations-for-optimisation
7. http://thebox.unsw.edu.au/video/training-video-7-tracking-performance-analytics
8. https://thebox.unsw.edu.au/2E6B93C0-3433-11EA-B8AA1AEAFC7AA695

# Example data
An example image stack object and track file can be found here - https://cloudstor.aarnet.edu.au/plus/s/w2ujKT8bzl7TttL
COLO316 cell line. 20 min acquisition frequency over 72hrs. 20x objective. 3x3 contiguous grid.  

Example data for downstream segmentation and fluorescence quantification (Training video 8: Data provided by Draper et al.) is found at 
https://unsw-my.sharepoint.com/:u:/g/personal/z9070419_ad_unsw_edu_au/EabRJfCNN-RLkoKyuh2-AuEBXp5z6SsMVglL0bwwKA4QMw?e=aZSWmM

Any questions should be directed to Dr Robert Nordon (r.nordon@unsw.edu.au) or Dr James Cornwell (cornwellja@mail.nih.gov)

June 2019
