# Brian's Image Processing Toolbox

This is home to a suite of scripts for image processing using python & imageJ(Fiji). The repo hosts tutorials for:

  - image registration
  - basic ImageJ utilities
  - videography analysis with DeepLabCut

## Quickstart

Follow the instructions below to configure a Python environment for the desired project. 

1. Install an [Anaconda](https://www.anaconda.com/download) distribution for your operating system.
2. Git clone the repo
3. In the Anaconda terminal, cd to the example project
4. `conda env create -f environment.yml`
5. `conda activate <env>`
6. `ipython kernel install --user --name <kernel>`
7. Open Jupyter Notebook, navigate to envs, upload the .ipynb file from the project and run it on the new kernel. 

Follow the instructions below to set up Fiji image-processing software. 

1. Install the [Fiji](https://imagej.net/software/fiji/) application for your operating system.
2. To follow the tutorials, install any auxiliary plugins by navigating to `Help > Update... > Manage Update Sites`. Alternatively, navigate to the Fiji.app directory and copy/paste the .jar file into the plugins folder. 
