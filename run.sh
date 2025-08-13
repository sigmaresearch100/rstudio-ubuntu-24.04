#!/usr/bin/env bash
# run.sh - Install R and RStudio Server
# shellcheck shell=bash

set -Eeuo pipefail
IFS=$'\n\t'

# Get directory of this script, then cd into scripts/
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/scripts"

# Run install-R script
install_r="./install-r-from-source.sh"
if [[ ! -x ${install_r} ]]; then
  chmod u+x "${install_r}"
fi
"${install_r}"

# Run install-RStudio script
install_rstudio="./install-rstudio-server.sh"
if [[ ! -x ${install_rstudio} ]]; then
  chmod u+x "${install_rstudio}"
fi
"${install_rstudio}"
