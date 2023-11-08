#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# This script installs Mellanox OFED drivers on RHEL 8.4
set -e

source /etc/profile.d/modules.sh

## Downloading OpenFoam
sudo mkdir -p /openfoam
sudo chmod 777 /openfoam
cd /openfoam
wget https://dl.openfoam.com/source/v2212/OpenFOAM-v2212.tgz
wget https://dl.openfoam.com/source/v2212/ThirdParty-v2212.tgz

tar -xf OpenFOAM-v2212.tgz
tar -xf ThirdParty-v2212.tgz

module load mpi/openmpi
module load gcc-9.2.0

## OpenFoam 10 requires cmake 3. CentOS 7.9 cames with a previous version.
# sudo yum install epel-release.noarch -y
# sudo yum install cmake3 -y
# sudo yum remove cmake -y
# sudo ln -s /usr/bin/cmake3 /usr/bin/cmake

# source OpenFOAM-v2212/etc/bashrc
# foamSystemCheck
cd OpenFOAM-v2212/
./Allwmake -j -s -q -l
