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
# Environment settings that are to be kept secret and not exposed to the GitHub repo
##################################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

echo "setenv.sh: start..."

source ../setenv-global.sh

### Billing accound ID used to pay for project resources
BILLING_ACCOUNT_ID="<set your Billing ID here>"

### How many teams will participate in the workshop
NUM_TEAMS=3

# In case we need to add extra teams - start with some number, otherwise set it to 1
TEAM_START_NUM=1

### How many people per team
NUM_PEOPLE_PER_TEAM=2

### Name of the event - to be added to user and group names
EVENT_NAME="preGA"

### Folder that holds all project sub-folders for users
TOP_FOLDER="Oct-1-$EVENT_NAME"

### Directory for temp data
TMP="tmp"

### Group that has all users and allows read only access to a whole bunch of shared resources
ADMIN_READ_GROUP="read-only-group@$DOMAIN"

### GAM is a wonderful OSS tool to manage Users and Groups
GAM="/home/${USER}/bin/gam/gam"

###############################################################################
# Generate team name
# Input:
#   1 - team number
###############################################################################
team_name() {
  echo "team${1}${EVENT_NAME}"
}

###############################################################################
# Generate user name
# Input:
#   1 - user number
#   2 - team number
###############################################################################
user_name() {
  echo "user${1}team${2}${EVENT_NAME}"
}

###############################################################################
# Generate name for team folder given team number
# Input:
#   1 - team #
###############################################################################
team_folder_name() {
  echo "Team-${1}-resources"
}

###############################################################################
# Generate random password
###############################################################################
generate_password() {
  local PASSWORD_LENGTH=10
  echo $(gpw 1 $PASSWORD_LENGTH)
}

###############################################################################
# Check prereqs and do install
###############################################################################
setup() {
  mkdir -p $TMP
  INSTALL_FLAG=$TMP/install.marker

  if [ -f "$INSTALL_FLAG" ]; then
    echo_my "Marker file '$INSTALL_FLAG' was found = > no need to do the install."
  else
    echo_my "Marker file '$INSTALL_FLAG' was NOT found = > starting one time install."
    # Password generator
    sudo apt-get install gpw
    # GAM is an awesome GSuite management OSS tool: https://github.com/jay0lee/GAM/wiki
    bash <(curl -s -S -L https://git.io/install-gam)
    touch $INSTALL_FLAG
  fi
}

###############################################################################
# Find folder ID given its display name
# Input:
#   1 - folder display name
###############################################################################
find_top_folder_id() {
  echo $(gcloud alpha resource-manager folders list --organization=$(lookup_org_id) \
        --filter=" displayName=$1" | grep $1 | sed -n -e "s/.* //p")
}

###############################################################################
# Find folder ID given its display name
# Input:
#   1 - folder display name
#   2 - parent folder ID
###############################################################################
find_folder_id() {
  echo $(gcloud alpha resource-manager folders list --folder=$2 \
        --filter=" displayName=$1" | grep $1 | sed -n -e "s/.* //p")
}

echo "setenv.sh: done"
