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

###############################################
# Car sensor simulator
#
# Simulates laser and other sensors by publishing data into the well known topic
# from which driving controller reads the data
###############################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../../setenv-global.sh
print_header "Sensor simulator"

TEMP_DATA=$(pwd)/tmp
INSTALL_FLAG=$TEMP_DATA/install.marker  # Location where the install flag is set to avoid repeated installs
mkdir -p $TEMP_DATA

if [[ ! -f "$INSTALL_FLAG" ]]; then
    install_node
    touch ${INSTALL_FLAG}
fi

create_gcs_camera_bucket

if [ $# -eq 1 ]; then
    export TEST_IMAGE_FILE=$1
else
    export TEST_IMAGE_FILE=""
fi

export GOOGLE_APPLICATION_CREDENTIALS=${SERVICE_ACCOUNT_SECRET}

# Local directory with test images
export TEST_IMAGE_FOLDER=simulation-images
# Delay in seconds to send test messages
export DELAY=1
# How many test messages to send - do not forget to have proper number of test images, otherwise it will circle around and repeat many times
export NUM_ITERATIONS=1

echo "TEST_IMAGE_FILE='$TEST_IMAGE_FILE'"
cd js
npm start

print_footer "Sensor simulator has completed sending test messages."