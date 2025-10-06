# Muth Lab Nanopore Analysis Pipeline

This repository facilitates the analysis of nanopore sequencing data on cloud computing resources such as Jetstream2 Exosphere by packaging existing tools in a streamlined graphical user interface. This tool enables standardized processing by users with a wide range of computing experience, while sensible defaults provide consistency and clarity. Beginning with raw Nanopore sequencing data (.pod5 files), basecalling, demultiplexing (including with custom barcodes), quality checks, and filtering are completed in one streamlined pipeline. Additionally, the tool facilitates taxonomic identification of 16S amplicons using [EMU](https://github.com/treangenlab/emu) and feeds into a user-friendly R notebook where interactive visualizations of 16S data are easily generated.

## Prerequisites

This repository was designed for use of Jetstream2 cloud instances in mind. These instances:
- Run a Linux-based operating system (tested on Ubuntu 24.04.3) 
- Have a web browser pre-installed (to view the R app)
- Have Git installed (if installing via command line)
- Have Make installed (for automating setup and execution)

All other core dependencies and tools are handled by Conda and the Makefile.

## Setup & Installation

### Install via GUI

#### **1. Clone this repository to your local machine**
1. Click the green 'Code' button on the top right-hand corner
2. Click 'Download ZIP', then select a download directory
   
   ![](https://i.imgur.com/NpyVd5Q.png)

#### **2. Set your working directory to this repository**
Now that you have a copy of the repository on your local machine, you'll need to change your working directory to this repository.

1. Open your file explorer
   
   ![](https://i.imgur.com/hUhOM72.png)
   
2. Search for the location of the repository (likely Downloads)
3. Right-click and select 'Open in Terminal'

   ![](https://i.imgur.com/UjRNka6.png)

#### **3. Execute Makefile**  
With your terminal open and the working directory set to this repository, type:

```bash
make
```

This will install Dorado and Conda, activate a Conda environment, then launch the R app.

### Install via Command Line

Run these commands in your terminal:

```bash
git clone https://github.com/ervkc/MuthLab_Nanopore_Analysis_Pipeline.git
```

```bash
cd MuthLab_Nanopore_Analysis_Pipeline
```

```bash
make
```

### **Subsequent Runs**

For future sessions, simply navigate to the repository directory (using either the command line or GUI) and run:

```bash 
make run
```

## Notes

This repository currently downloads specific versions of Dorado and Conda. If newer versions are released and you'd like to update them, you can open their respective install scripts located under `tools/` and replace the `INSTALL_URL="..."` with your desired version.

- You can track the install URL of the current version of Dorado on [their GitHub](https://github.com/nanoporetech/dorado) under the Installation header
- You can track the install URL of the current version of Conda on [their website](https://www.anaconda.com/docs/getting-started/miniconda/main) under the Miniconda Installers header
