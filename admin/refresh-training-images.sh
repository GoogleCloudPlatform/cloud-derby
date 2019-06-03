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

##########################################################################################
# This script updates annotated images for training in the Admin project
##########################################################################################
set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

#############################################
# MAIN
#############################################
echo "Starting refresh of training images..."

TMP="$(pwd)/tmp/image-refresh"
if [ -d "$TMP" ]; then
    rm -rf $TMP
fi

mkdir -p $TMP
cd $TMP

echo "Download latest set of images that resulted from user merge.sh command..."
gsutil cp gs://update-this-${PROJECT}-images-for-training-v-${VERSION}/* ./

unzip annotations.zip
unzip images-for-training.zip
rm annotations.zip
rm images-for-training.zip

echo "Create fresh set of training images..."
zip -r provided-images *

echo "Upload new set of training images to shared GCS..."
gsutil cp provided-images.zip gs://$GCS_SOURCE_IMAGES

rm provided-images.zip

echo "Make a backup copy of training images..."
NOW=$(date +%Y-%m-%d-%H-%M-%S)
gsutil cp gs://$GCS_SOURCE_IMAGES/provided-images.zip gs://robot-derby-backup/${NOW}-provided-images.zip

echo "Training image refresh complete."