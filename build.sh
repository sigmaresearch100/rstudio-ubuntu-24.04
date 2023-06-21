#!/bin/bash

set - e

# remove R
apt-get remove r-base-core

# install wget
apt-get update
apt-get install -y wget

# install R from source
wget https://raw.githubusercontent.com/rocker-org/rocker-versioned2/master/scripts/install_R_source.sh
bash install_R_source.sh

# session
R -e "sessionInfo()"
