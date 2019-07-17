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
# The script will collect all photos from any cloudderby event into a defined bucket under Source and Administration project
# by scanning all folders and projects and buckets to download user images
###############################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh

# Where do we want to copy all these images
DESTINATION_BUCKET="crowd-sourced-images-archive"

# How many GCS buckets were found
BUCKETS_TOTAL=0

# How many buckets were copied
BUCKETS_COPIED=0

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
    scan_projects "$PARENT_FOLDER_ID"

    local FOLDER_LIST=$(gcloud alpha resource-manager folders list --folder=$PARENT_FOLDER_ID --format="value(name)")

    while read -r FOLDER_ID; do
        if [[ ! -z "$FOLDER_ID" ]] ; then
            echo_my "Recursively processing folders under folder id '$FOLDER_ID'..."
            scan_folders "$FOLDER_ID"
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
            scan_buckets $PROJ_ID
        fi
    done <<< "$PROJECT_LIST"
}

###############################################################################
# Scan and process all GCS buckets in a project
# Inputs
#   1 - project ID
###############################################################################
scan_buckets() {
    local BUCKET
    echo_my "Scanning buckets for project '$1'..."
    
    local BUCKET_LIST=$(gsutil ls -p $1 gs://)
    
    if [ -z ${BUCKET_LIST+x} ] ; then
        return  # No buckets found in this project
    fi
    
    while read -r BUCKET; do
        if [[ ! -z "$BUCKET" ]] ; then
            echo_my "Processing bucket '$BUCKET'"
            BUCKETS_TOTAL=$((BUCKETS_TOTAL+1))
    
            if echo "$BUCKET" | grep -q "annotated-images" ; then
                BUCKETS_COPIED=$((BUCKETS_COPIED+1))
                echo_my "Copy contents of the bucket '$BUCKET'..."
                gsutil -m cp $BUCKET*.zip gs://${DESTINATION_BUCKET}/annotated-images/$1/ | true # Ignore if error or empty
            fi
    
            if echo "$BUCKET" | grep -q "camera-" ; then
                BUCKETS_COPIED=$((BUCKETS_COPIED+1))
                echo_my "Copy contents of the bucket '$BUCKET'..."
                gsutil -m cp $BUCKET*.jpg gs://${DESTINATION_BUCKET}/camera-images/$1/ | true # ignore if error or empty
            fi
        fi
    done <<< "$BUCKET_LIST"
}

###############################################################################
# MAIN
###############################################################################

if [ -z ${1+x} ] ; then
    echo_my "NUMERIC_FOLDER_ID not found. \n Usage: collect-images.sh [NUMERIC_FOLDER_ID] \n Example: \n ./collect-images.sh 8763450985677 \n   \n" $ECHO_ERROR
    exit 1
fi

# Process all projects and folders under this starting folder
START_FOLDER=$1

print_header "Collect all raw and annotated images from folder ID '$1'"

scan_folders $START_FOLDER

print_footer "SUCCESS: Found $PROJECTS_FOUND projects, $FOLDERS_FOUND folders, $BUCKETS_TOTAL buckets, including $BUCKETS_COPIED buckets with image content."