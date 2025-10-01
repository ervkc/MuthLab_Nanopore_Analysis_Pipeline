#!/bin/bash

INSTALL_DIR="./miniconda"
INSTALL_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
INSTALLER_NAME="Miniconda3-latest-Linux-x86_64.sh"
ENV_YML="env.yml" 

curl -L "$INSTALL_URL" -o "$INSTALLER_NAME"
bash "$INSTALLER_NAME" -b -p "$INSTALL_DIR"
rm "$INSTALLER_NAME"
source "$INSTALL_DIR/etc/profile.d/conda.sh"
conda env create -f "$ENV_YML"

