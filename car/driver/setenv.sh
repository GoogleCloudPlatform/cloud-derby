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

###########################################################
# Shared environment variables for Driver module
###########################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../../setenv-global.sh

export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_SECRET
export COMMAND_SUBSCRIPTION=driving-command-subscription-$CAR_ID

### Obstacle avoidance - the number of millimeters to stop the car before hitting an object
export BARRIER_DAMPENING=180

### Car Camera position; UPSIDE DOWN=0; NORMAL=1 - this takes effect on the car as the image will be flipped before being sent to the cloud
export CAR_CAMERA_NORMAL=0

### What color ball this car will be playing
export CAR_COLOR=red
