#!/bin/bash

#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##################################################
# Configure VM for being able to later build and train TensorFlow model. Based on:
# https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/running_pets.md
# Also see this tutorial: https://cloud.google.com/solutions/creating-object-detection-application-tensorflow
##################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

##################################################
# Configuring TF research models
# Based on this tutorial: https://cloud.google.com/solutions/creating-object-detection-application-tensorflow
##################################################
setup_models() {
    echo_my "Setting up Proto and TensorFlow Models..."

	if [ -d "$TF_MODEL_DIR" ]; then
	    rm -rf $TF_MODEL_DIR
	fi
	mkdir -p $TF_MODEL_DIR
	cd $TF_MODEL_DIR

    # Configure dev environment - pull down TF models
    git clone https://github.com/tensorflow/models.git
    cd models
    # object detection master branch has a bug as of 9/21/2018
    # checking out a commit we know works
    git reset --hard 256b8ae622355ab13a2815af326387ba545d8d60
    cd ..

    PROTO_V=3.3
    PROTO_SUFFIX=0-linux-x86_64.zip

	if [ -d "protoc_${PROTO_V}" ]; then
	    rm -rf protoc_${PROTO_V}
	fi
    mkdir protoc_${PROTO_V}
    cd protoc_${PROTO_V}

    echo_my "Download PROTOC..."
    wget https://github.com/google/protobuf/releases/download/v${PROTO_V}.0/protoc-${PROTO_V}.${PROTO_SUFFIX}
    chmod 775 protoc-${PROTO_V}.${PROTO_SUFFIX}
    unzip protoc-${PROTO_V}.${PROTO_SUFFIX}
    rm -rf protoc-${PROTO_V}.${PROTO_SUFFIX}

    echo_my "Compiling protos..."
    cd $TF_MODEL_DIR/models/research
    bash object_detection/dataset_tools/create_pycocotools_package.sh /tmp/pycocotools
    python setup.py sdist
    (cd slim && python setup.py sdist)

    PROTOC=$TF_MODEL_DIR/protoc_${PROTO_V}/bin/protoc
    $PROTOC object_detection/protos/*.proto --python_out=.
}

#############################################
# MAIN
#############################################
CWD=$(pwd)
mkdir -p $CWD/tmp
INSTALL_FLAG=$CWD/tmp/install.marker
  
# This is to allow NVIDIA packages to be verified
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -

yes | sudo apt-get update
yes | sudo apt-get --assume-yes install bc
yes | sudo apt-get install apt-transport-https unzip zip

source ./setenv.sh
print_header "Setting up TF VM for transferred learning"

if [ -f "$INSTALL_FLAG" ]; then
  echo_my "Marker file '$INSTALL_FLAG' was found = > no need to do the install."
else    
  echo_my "Marker file '$INSTALL_FLAG' was NOT found = > starting one time install."
  setup_models
  touch $INSTALL_FLAG
fi

print_footer "Training VM setup has completed"