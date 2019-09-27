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
# This script traverses the org and stops all runnng VMs
###############################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh

# How many total Vms were found
VMS_TOTAL=0

# How many running Vms were stopped
VMS_RUNNING=0

# How many projects were found
PROJECTS_FOUND=0

# How many folders found
FOLDERS_FOUND=0

###############################################################################
# Scan all folders and projects under a designated folder ID
# Input
#   1 - folder ID under which all VMs to be stopped
###############################################################################
scan_folders() {
  local PARENT_FOLDER_ID=$1
  local FOLDER_ID
  FOLDERS_FOUND=$((FOLDERS_FOUND+1))

  echo_my "Scanning projects under folder id '$PARENT_FOLDER_ID'..."
  scan_projects $PARENT_FOLDER_ID

  local FOLDER_LIST=$(gcloud alpha resource-manager folders list --folder=$PARENT_FOLDER_ID --format="value(name)")

  while read -r FOLDER_ID; do
      if [[ ! -z "$FOLDER_ID" ]] ; then
          echo_my "Recursively processing folders under folder id '$FOLDER_ID'..."
          scan_folders $FOLDER_ID
      fi
  done <<< "$FOLDER_LIST"
}

###############################################################################
# Scan all projects under a given folder
# Inputs
#   1 - Folder ID
###############################################################################
scan_projects() {
  echo_my "Scanning projects under folder '$1'..."
  local PROJECT_LIST=$(gcloud projects list --filter="parent.id=$1" --format="value(projectId)")
  local PROJ_ID

  while read -r PROJ_ID; do
      if [[ ! -z "$PROJ_ID" ]] ; then
          PROJECTS_FOUND=$((PROJECTS_FOUND+1))
          echo_my "Processing project id '$PROJ_ID'..."
          stop_vms $PROJ_ID
      fi
  done <<< "$PROJECT_LIST"
}

###############################################################################
# Stop all VMs in a project
# Inputs
#   1 - project ID
###############################################################################
stop_vms() {
  local VM_ID
  local PROJECT_ID=$1
  echo_my "Scanning VMs for project '$PROJECT_ID'..."

  local VM_LIST=$(gcloud compute instances list --project $PROJECT_ID --format="value(name)")

  echo $VM_LIST

  while read -r VM_ID; do
      if [[ ! -z "$VM_ID" ]] ; then
          VMS_TOTAL=$((VMS_TOTAL+1))
          # Get the zone of the instance
          local ZONE=$(gcloud compute instances list --filter="name:($VM_ID)" --project $PROJECT_ID --format="value(zone)")
          local STATUS=$(gcloud compute instances list --filter="name:($VM_ID)" --project $PROJECT_ID --format="value(status)")
          echo_my "Found VM id '$VM_ID' with status '$STATUS' in project '$PROJECT_ID'"
          if [ $STATUS = "RUNNING" ] ; then
              VMS_RUNNING=$((VMS_RUNNING+1))
              if [ $COUNT_RUNNING_VM_ONLY = false ] ; then
                  echo_my "Stopping VM id '$VM_ID' in project '$PROJECT_ID'..."
                  yes | gcloud compute instances stop $VM_ID --project $PROJECT_ID --zone=$ZONE | true # Ignore if error and proceed
              fi
          fi
      else
          echo_my "No more VMs found in this project"
      fi
  done <<< "$VM_LIST"
}

###############################################################################
# MAIN
###############################################################################
if [ -z ${1+x} ] ; then
    echo_my "NUMERIC_FOLDER_ID not found. \n Usage: stop-vms.sh [NUMERIC_FOLDER_ID] \n Example: \n ./stop-vms.sh 8763450985677 \n   \n" $ECHO_ERROR
    exit 1
fi

# Process all projects and folders under this starting folder
START_FOLDER=$1

print_header "Stop all running VMs"

# If this is true, then running VMs will be counted, but not stopped
COUNT_RUNNING_VM_ONLY=false

echo_my "\nATTENTION!!!!!!!!!!!\nATTENTION!!!!!!!!!!!\nATTENTION!!!!!!!!!!!\n"
echo_my "This will stop all running VMs under the folder --- '$START_FOLDER' ---. Are you sure you want to proceed?" $ECHO_WARNING
pause
echo_my "\nAre you sure you want to stop all running VMs ???????" $ECHO_WARNING
pause

if [ $COUNT_RUNNING_VM_ONLY = false ] ; then
    echo_my "COUNT_RUNNING_VM_ONLY=$COUNT_RUNNING_VM_ONLY - this script will STOP all running VMs."
else
    echo_my "COUNT_RUNNING_VM_ONLY=$COUNT_RUNNING_VM_ONLY - this script will COUNT all running VMs."
fi

scan_folders $START_FOLDER

print_footer "SUCCESS: Found $PROJECTS_FOUND projects, $FOLDERS_FOUND folders, $VMS_TOTAL VMs, including $VMS_RUNNING running VMs."