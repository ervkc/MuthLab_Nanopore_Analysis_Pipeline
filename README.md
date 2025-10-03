
# Muth Lab Nanopore Analysis Pipeline
This repository is meant to facilitate the analysis of nanopore sequencing data on cloud computing resources such as the Jetstream2 exosphere by packaging existing tools in a streamlined graphical user interface. This tool will enable standardized processing by users with a wide range of computing experience while sensible defaults provide consistency and clarity. Beginning with raw Nanopore sequencing data (.POD5 files) basecalling, demultiplexing (including with custom barcodes), quality checks and filtering are completed in one streamlined pipeline. Additionally, the tool facilitates taxonomic identification of 16S amplicons using [EMU](https://github.com/treangenlab/emu) and feeds into a user-friendly R notebook where interactive visualizations of 16S data are easily generated. 

## Outline

## Pre-Requisites
This repository was created for 



## Setup & Installation
### **1. Clone this repository to your local machine**
#### a. Via Command Line
1. Copy this command into your terminal
```bash
git clone https://github.com/ervkc/MuthLab_Nanopore_Analysis_Pipeline.git
```

#### b. Via GUI

1. Click the green 'Code' button on the top right-hand corner. 
2. Click 'Download ZIP', and then select a download directory.


### **2. Set your working directory to this repository**
Now that you have a copy of the repository on your local machine, you'll need to change your working directory to this repository.
#### a. Via Command Line
```bash
cd MuthLab_Nanopore_Analysis_Pipeline-master
```

#### b. Via GUI

   1. open up your file explorer

   2. search for the location of the repository (likely Downloads)
   3. right-click, and select 'Open in Terminal' 


### **3. Execute Makefile**  
With your terminal open, and the working directory set to the repository, run:
```bash
make
```
This will install Dorado and Conda, activate a Conda environment, then launch the R app. 
Right-click the generated URL and open the app in your browser.

### **4. Subsequent Runs**
For future sessions, simply navigate to the repository directory (using either the command line or GUI,) and run:
```bash
make run
```

 


