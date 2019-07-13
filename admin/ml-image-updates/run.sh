#!/bin/bash

###############################################
# Process images for re-training to expand the dataset based on additional images
###############################################
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

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution
# set -x # Print trace of commands after their arguments are expanded

source ../../setenv-global.sh

# This is the original bucket with images to be processed
#export CLOUD_BUCKET="robot-derby-backup"
export CLOUD_BUCKET="images-crowdsourcing"
# This is where all sorted images will be copied
export DESTINATION_BUCKET="derby-images-auto-sorted"

# This REST endpoint will be used for making inferences on images for classification purpose
export INFERENCE_IP="104.197.196.4"

###############################################
# MAIN
###############################################
print_header "Starting image sort process"

mkdir -p tmp
CWD=$(pwd)
# Location where the install flag is set to avoid repeated installs
INSTALL_FLAG=$CWD/tmp/install.marker

if [ -f "$INSTALL_FLAG" ]; then
  echo_my "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else
  install_node
  touch $INSTALL_FLAG
fi

# The service account is needed to get permissions to create resources
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_SECRET

cd $CWD/js

#if [ -f "nohup.out" ] ; then
#    rm -rf nohup.out
#fi

export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_SECRET
npm start

print_footer "Image sort process has completed OK."