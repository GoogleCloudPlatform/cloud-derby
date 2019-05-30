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
# Export Windows VM annotation image into the GCS bucket so others can use it
###############################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../setenv-global.sh

### GCS Bucket destination for the export
EXPORT_BUCKET=windows-vm-image-${ADMIN_PROJECT_ID}

### Name of the Windows Image to be exported
WINDOWS_IMAGE_NAME="windows-image-labeling-image"

###############################################################################
# MAIN
###############################################################################
print_header "Windows Image export started."

if gsutil ls -p ${ADMIN_PROJECT_ID} | grep ${EXPORT_BUCKET}; then
    echo_my "Bucket ${EXPORT_BUCKET} found OK"
else
    echo_my "Create GCS bucket for backup: '${EXPORT_BUCKET}'..."
    gsutil mb -p ${ADMIN_PROJECT_ID} gs://${EXPORT_BUCKET}
fi

gcloud compute images export --destination-uri gs://${EXPORT_BUCKET}/${WINDOWS_IMAGE_NAME} --image ${WINDOWS_IMAGE_NAME} --project ${ADMIN_PROJECT_ID}

print_footer "SUCCESS: Export is complete and can be found in the GCS bucket '$EXPORT_BUCKET'."