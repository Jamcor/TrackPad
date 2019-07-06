# TrackPad
This repository contains all MATLAB source code for TrackPad single-cell tracking software. 

# Contributors 
The TrackPad platform was developed by Dr Robert Nordon @ the University of New South Wales. 
Dr James Cornwell @ NIH has contributed to GUI development, user-experience, and computational speed.  

# Standalone executable 
Please install Microsoft SharePoint before download: https://unsw-my.sharepoint.com/:u:/g/personal/z9070419_ad_unsw_edu_au/EZB9Ym6eq4NIiXgirC23TkkByfdVDq--LF95YJ2-3DD3zw?e=kdVF3a. 

# Download source code (Versions 2.0)
Please install Microsoft SharePoint before download: https://unsw-my.sharepoint.com/:u:/g/personal/z9070419_ad_unsw_edu_au/EWL38cOvi6tNqhV7O5jd8ikBHUmTvlflLsooGUWtGS6ROw?e=NoHNJj
Type GUI=TrackPad; as the Matlab command line to enter TrackPad.

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

# Example data
An example image stack object and track file can be found here - https://cloudstor.aarnet.edu.au/plus/s/w2ujKT8bzl7TttL
COLO316 cell line. 20 min acquisition frequency over 72hrs. 20x objective. 3x3 contiguous grid.  

Any questions should be directed to Dr Robert Nordon (r.nordon@unsw.edu.au) or Dr James Cornwell (cornwellja@mail.nih.gov)

June 2019
