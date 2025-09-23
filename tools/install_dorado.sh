#!/bin/bash
INSTALL_DIR="./dorado"
INSTALL_URL="https://cdn.oxfordnanoportal.com/software/analysis/dorado-1.1.1-linux-x64.tar.gz"
BIN_NAME="dorado-1.1.1-linux-x64.tar.gz"

curl -L "$INSTALL_URL" -o "$BIN_NAME"
mkdir -p "$INSTALL_DIR"
tar -xzf "$BIN_NAME" -C "$INSTALL_DIR" --strip-components=1
rm "$BIN_NAME"


