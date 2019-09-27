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
# Make a backup copy of all critical data intofrom the Org Domain a separate
# account in case the Org get compromized and / or removed
###############################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh

### Directory for temp data
TMP="tmp"

### Service account key for backup
BACKUP_SERVICE_ACCOUNT_SECRET="${PROJECT_DIR}/.secrets/backup-service-account-secret.json"

###############################################################################
# Prepare backup destinations
###############################################################################
setup() {
    echo_my "Setup backup destinations..."

    if gsutil ls -p ${BACKUP_PROJECT_ID} | grep ${BACKUP_BUCKET}; then
        echo_my "Bucket ${BACKUP_BUCKET} found OK"
    else
        echo_my "Create GCS bucket for backup: '${BACKUP_BUCKET}'..."
        gsutil mb -l eu -c coldline -p ${BACKUP_PROJECT_ID} gs://${BACKUP_BUCKET}/
    fi
}

###############################################################################
# Make a copy of annotated images
###############################################################################
backup_images() {
    local FOLDER=${BACKUP_BUCKET}/$NOW/images
    echo_my "Making a copy of annotated images from project '${ADMIN_PROJECT_ID}' bucket '${GCS_SOURCE_IMAGES}' into project '${BACKUP_PROJECT_ID}' bucket '${FOLDER}'"

    gsutil cp gs://${GCS_SOURCE_IMAGES}/* gs://${FOLDER}/
}

###############################################################################
# Make a copy of a git repo as plain file structure
###############################################################################
backup_source() {
    local FOLDER=${BACKUP_BUCKET}/${NOW}
    echo_my "Making a copy of source files from project '${ADMIN_PROJECT_ID}' into project '${BACKUP_PROJECT_ID}' bucket '${FOLDER}'"

    local CWD=$(pwd)
    local TMP=${HOME}/tmp/repo
    rm -rf "$TMP" | true # ignore if does not exist
    mkdir -p $TMP

    # Clone the repo into a temp directory
    git clone https://github.com/GoogleCloudPlatform/cloud-derby $TMP/cloud-derby-source

    cd $TMP/cloud-derby-source

    # We only need to save source files, not the large amount of git metadata
    rm -rf .git
    zip -r source .

    gsutil cp source.zip gs://${FOLDER}/

    # Free up space
    cd $CWD
    rm -rf $TMP
}

###############################################################################
# MAIN
###############################################################################
if [ -z ${1+x} ] ; then
    echo_my "BACKUP_PROJECT_ID not found. \n Usage: backup.sh [BACKUP_PROJECT_ID] \n Example: \n ./backup.sh cloud-derby-backup \n   \n" $ECHO_ERROR
    exit 1
fi

BACKUP_PROJECT_ID=$1
# Where to store backup data
BACKUP_BUCKET="${BACKUP_PROJECT_ID}-bucket"

NOW=$(date +%Y-%m-%d-%H-%M)
print_header "Project backup started at $NOW."

echo "Activating service account '${BACKUP_SERVICE_ACCOUNT_SECRET}'..."
gcloud auth activate-service-account --key-file=${BACKUP_SERVICE_ACCOUNT_SECRET}

setup

backup_images

backup_source

print_footer "SUCCESS: Project backup complete."