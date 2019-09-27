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
##################################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

echo "setenv-local.sh: start..."

### Automatically generate unique project ID for the first run and save it into a file. Later read it from file
PROJECT_NAME_FILE="$PROJECT_DIR/project-id.sh"

if [ -f "$PROJECT_NAME_FILE" ] ; then
    echo "Sourcing existing project file '$PROJECT_NAME_FILE'..."
    source $PROJECT_NAME_FILE
else
    # Infer current project ID from the environment
    export PROJECT=$(gcloud info | grep "Project:" | sed -n -e "s/Project: \[//p" | sed -n -e "s/\]//p")
fi

echo "PROJECT='$PROJECT'"
gcloud config set project "$PROJECT"

### Serial number of the car to distinguish it from all other cars possibly on the same project
export CAR_ID=2

### How many training steps to take during TensorFlow model training
TRAINING_STEPS=8000

### This controls which inference VM REST API will be used by the Driving Controller
#   true - use existing inference VM from the DEMO project
#   false - use inference VM within the same project as Driving Controller
USE_DEMO_INFERENCE="false"

### Where do we want Driving Controller to be deployed? (current VM or App Engine)
#   true - deploy in local VM
#   false - deploy in App Engine
DRIVING_CONTROLLER_LOCAL="true"

### This controls certain automated tasks and allows the script to create resources on behalf of the user
FOUR_HOURS_HACKATHON="false"

if $FOUR_HOURS_HACKATHON ; then
  AUTO_CREATE_IP="true"
  AUTO_CREATE_FIREWALL="true"
  SKIP_MANUAL_IMAGE_ANNOTATION="true"
fi

### Used for multiple ML models to be deployed and compared against each other (this is added to VM names, IP names, GCS bucket names, etc.)
export VERSION=50

### These are Region and Zone where you want to run your car controller - feel free to change as you see fit
export REGION="us-central1"
export ZONE="us-central1-f"
export REGION_LEGACY="us-central" # there are corner cases where gcloud still references the legacy nomenclature

echo "setenv-local.sh: done"