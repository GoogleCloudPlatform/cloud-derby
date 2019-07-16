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

###############################################################################
# This script creates new hackathon event with users and folders generated
###############################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh

###############################################################################
# MAIN
###############################################################################
print_header "Creating workshop users, folders, etc..."

    COMMAND="gcloud projects add-iam-policy-binding $DEMO_PROJECT --member=group:$ADMIN_READ_GROUP --role=roles/"
    # All users need to be able to read the source repo
    eval ${COMMAND}compute.networkViewer

print_footer "SUCCESS: New workshop configuration created."