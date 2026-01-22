#!/bin/bash

# Local linter script for voxl-px4
# Called by the master linter: ci-tools/scripts/check-linter-script.sh

REQUIRED_FILE="scripts/voxl-configure-px4"

if [[ -f "$REQUIRED_FILE" ]]; then
    echo "[INFO] Required file '$REQUIRED_FILE' found."
    exit 0
else
    echo "[ERROR] Required file '$REQUIRED_FILE' not found."
    exit 1
fi
