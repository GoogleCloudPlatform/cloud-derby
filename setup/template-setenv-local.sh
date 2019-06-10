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

##################################################################################
# Environment settings that are unique to a development machine - these
# do not get committed into repo and allow multi-user development. Example of this
# can be found in "src/setup" folder.
# 
# This file needs to be put into the user $HOME directory.
##################################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

echo "setenv-local.sh: start..."

### Project user home dir
export BASE_PATH="$HOME"

### Automatically generate unique project ID for the first run and save it into a file. Later read it from file
export PROJECT_NAME_FILE="$HOME/project-id.sh"

if [ -f "$PROJECT_NAME_FILE" ] ; then
    echo "Sourcing existing project file '$PROJECT_NAME_FILE'..."
    source $PROJECT_NAME_FILE
else
    # Infer current project ID from the environment
    export PROJECT=$(gcloud info | grep "Project:" | sed -n -e "s/Project: \[//p" | sed -n -e "s/\]//p")
fi

echo "PROJECT='$PROJECT'"
gcloud config set project "$PROJECT"

### This controls logic for the 4 hours event vs 8 hrs and makes some other assumptions
#   true - we are currently doing 4 hours event and will automatically create some resources for the user
#   false - we are doing 8 hours event and have users do many things by hand
#		set this to "true" if you want to use the demo inference VM
export FOUR_HOURS_EVENT="false"
export DEMO_PROJECT="robot-derby-demo-1"
export DEMO_INFERENCE_IP_NAME="ml-static-ip-47"

### This controls many automated tasks and allows the script to create many resources
#   automatically or let  user create it by hand. For example - creation of static IP address for inference VM, firewall rules, etc.
#   true - create resources automatically
#   false - let user create resources manually (for example - during 8 hours event)
export FAST_PATH="false"

### Where do we want Driving Controller to be deployed? (current VM or App Engine)
#   true - deploy in local VM
#   false - deploy in App Engine
DEPLOY_LOCAL="true"

### Serial number of the car to distinguish it from all other cars possibly on the same project
export CAR_ID=2

### Used for cases when we want multiple ML models to be deployed and compared against each other
export VERSION=50

### How many training steps to take
TRAINING_STEPS=8000

### These are Region and Zone where you want to run your car controller - feel free to change as you see fit
export REGION="us-central1"
export ZONE="us-central1-f"
export REGION_LEGACY="us-central" # there are corner cases where gcloud still references the legacy nomenclature

### Camera resolution
export HORIZONTAL_RESOLUTION_PIXELS=1024
export VERTICAL_RESOLUTION_PIXELS=576

### GitHub Repo with the source code
export GITHUB_REPO_URL="https://github.com/GoogleCloudPlatform/cloud-derby"

### Name of the folder with the source code (not a full path)
export SOURCE_FOLDER="cloud-derby"

### Git Repo will be cloned into this directory
export PROJECT_PATH="$BASE_PATH/$SOURCE_FOLDER"

### Store service account private key here
export SERVICE_ACCOUNT_DIR="$BASE_PATH/.secrets"
export SERVICE_ACCOUNT_SECRET="$SERVICE_ACCOUNT_DIR/service-account-secret.json"
export SERVICE_ACCOUNT="cloud-derby-dev"
export ALLMIGHTY_SERVICE_ACCOUNT="${SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com"

### Name of the source bucket with images of colored balls (this is one source for all other projects)
export GCS_SOURCE_IMAGES="cloud-derby-pictures"

### Name of the destination bucket with images of colored balls and whatever other objects
export GCS_IMAGES="${PROJECT}-images-for-training-v-${VERSION}"

echo "setenv-local.sh: done"
