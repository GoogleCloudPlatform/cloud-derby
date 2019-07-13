#!/bin/bash

###############################################
# Sort images into subfolders (after run.sh is completed)
# additional images
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
export SOURCE_BUCKET="derby-images-auto-sorted"
# This is where all sorted images will be copied
export DESTINATION_BUCKET="derby-images-sorted-by-score"

###############################################
# MAIN
###############################################
print_header "Starting image sort process by score"

mkdir -p tmp

# The service account is needed to get permissions to create resources
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_SECRET

cd js

export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_SECRET
nohup node sort.js &

print_footer "Image sort by score has completed OK."