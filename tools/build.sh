#!/bin/bash

set -e

export LANG=en_US.UTF-8

# install wget
apt-get update
apt-get install -y wget

# install R from source
wget https://raw.githubusercontent.com/rocker-org/rocker-versioned2/master/scripts/install_R_source.sh
bash install_R_source.sh

# install Rstudio from source
wget https://raw.githubusercontent.com/rocker-org/rocker-versioned2/master/scripts/install_rstudio.sh
bash install_rstudio.sh

# session
R -e "sessionInfo()"
