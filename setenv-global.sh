#!/bin/bash

#############################################################################
# Shared environment variables and utility functions for entire project
#############################################################################

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

echo "setenv-global.sh: start..."

command -v bc >/dev/null 2>&1 || { echo >&2 "'bc' is not installed."; yes | sudo apt-get --assume-yes install bc; }

### This is the path to the home directory of the project
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "Project directory is set to PROJECT_DIR='$PROJECT_DIR'"

source ${PROJECT_DIR}/setenv-local.sh

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

### Domain name
DOMAIN="cloudderby.io"

### Camera resolution
export HORIZONTAL_RESOLUTION_PIXELS="1024"
export VERTICAL_RESOLUTION_PIXELS="576"

### Demo project with the inference VM running at all times for use by anyone
export DEMO_PROJECT="robot-derby-demo-1"
export DEMO_INFERENCE_IP_NAME="ml-static-ip-47"

### This is the project that hosts reference images and other admin elements
ADMIN_PROJECT_ID="administration-203923"

### Name of the source bucket with images of colored balls (this is one source for all other projects)
export GCS_SOURCE_IMAGES="cloud-derby-pictures"

### Name of the destination bucket with images of colored balls and whatever other objects - used for ML training
export GCS_IMAGES="${PROJECT}-images-for-training-v-${VERSION}"

### Store service account private key here
export SERVICE_ACCOUNT_DIR="$PROJECT_DIR/.secrets"
export SERVICE_ACCOUNT_SECRET="$SERVICE_ACCOUNT_DIR/service-account-secret.json"
export SERVICE_ACCOUNT="cloud-derby-dev"
export ALLMIGHTY_SERVICE_ACCOUNT="${SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com"
export DERBY_DEV_ROLE="CloudDerbyDeveloperRole1"

### Topic where cloud logic sends driving commands to and car reads them from here
export COMMAND_TOPIC="driving-commands-topic-$CAR_ID"

### Topic where the car sends its sensor data and cloud logic reads it from
export SENSOR_TOPIC="sensor-data-topic-$CAR_ID"

### Subscription on the above sensor topic for cloud logic to read data from the car
export SENSOR_SUBSCRIPTION="sensor-data-subscription-$CAR_ID"

### GCS bucket for car to post its images to and for cloud logic to read it from here
export CAR_CAMERA_BUCKET="camera-${CAR_ID}-${PROJECT}"

### IOT Core registry where the car sends its sensor data and cloud logic reads it from
export IOT_CORE_REGISTRY="car-iot-registry"

### IOT Core Device ID
export IOT_CORE_DEVICE_ID="iot-car-${CAR_ID}"

### Inference IP address logical name
export ML_IP_NAME="ml-static-ip-${VERSION}"

### This URL will be appended to the VM IP address to call Inference Vision API
export INFERENCE_URL="/v1/objectInference"

### Credentials to call Inference App
export INFERENCE_USER_NAME="robot"
export INFERENCE_PASSWORD="gcp4all"

### Firewal tags
# HTTP_PORT is used to run Inference VM app to serve REST requests
export HTTP_PORT="8082"
export HTTP_TAG="http-from-all"
export SSH_TAG="ssh-from-all"

### VM network name for diagnostics and debug
export VM_NAME=$(uname -n)

### Labels and IDs of objects to be recognized
export NUM_CLASSES="8"
export BALL_LABEL_SUFFIX="Ball"
export HOME_LABEL_SUFFIX="Home"

export BLUE_BALL_ID="1"
export BLUE_BALL_LABEL="Blue$BALL_LABEL_SUFFIX"
export RED_BALL_ID="2"
export RED_BALL_LABEL="Red$BALL_LABEL_SUFFIX"
export YELLOW_BALL_ID="3"
export YELLOW_BALL_LABEL="Yellow$BALL_LABEL_SUFFIX"
export GREEN_BALL_ID="4"
export GREEN_BALL_LABEL="Green$BALL_LABEL_SUFFIX"
export BLUE_HOME_ID="5"
export BLUE_HOME_LABEL="Blue$HOME_LABEL_SUFFIX"
export RED_HOME_ID="6"
export RED_HOME_LABEL="Red$HOME_LABEL_SUFFIX"
export YELLOW_HOME_ID="7"
export YELLOW_HOME_LABEL="Yellow$HOME_LABEL_SUFFIX"
export GREEN_HOME_ID="8"
export GREEN_HOME_LABEL="Green$HOME_LABEL_SUFFIX"

export ALL_OBJECT_LABELS="$BLUE_BALL_LABEL $RED_BALL_LABEL $YELLOW_BALL_LABEL $GREEN_BALL_LABEL $BLUE_HOME_LABEL $RED_HOME_LABEL $YELLOW_HOME_LABEL $GREEN_HOME_LABEL"

###############################################
# Wait for user input
###############################################
pause ()
{
	read -p "Press Enter to continue or Ctrl-C to stop..."
}

###############################################
# Fail processing
###############################################
die()
{
	echo Error: $?
	exit 1
}

###############################################
# Fail processing
# Input - any text
###############################################
log_error()
{
	echo "Error: $?. Details: $1" >> errors.log
	exit 1
}

###############################################
# Starts measurements of time
###############################################
start_timer()
{
	START_TIME=$(date +%s)
}

###############################################
# Stop timer and write data into the log file
###############################################
measure_timer()
{
  if [ -z ${START_TIME+x} ]; then
    MEASURED_TIME=0
  else
    END_TIME=$(date +%s)
    local TIMER=$(echo "$END_TIME - $START_TIME" | bc)
    MEASURED_TIME=$(printf "%.2f\n" $TIMER)
  fi
}

###############################################
# Print starting headlines of the scrit
# Params:
#	1 - text to show
###############################################
SEPARATOR="*************************************************************************"
CALLER="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
COLOR='\033[32m'
NORMAL='\033[0m'
print_header()
{
	start_timer
	printf "\n${COLOR}$SEPARATOR${NORMAL}"
	printf "\n${COLOR}STARTED: $1 ($CALLER)${NORMAL}"
	printf "\n${COLOR}$SEPARATOR${NORMAL}\n"
}

###############################################
# Print closing footer of the scrit
###############################################
print_footer()
{
	measure_timer
	printf "\n${COLOR}$SEPARATOR${NORMAL}"
	printf "\n${COLOR}$1${NORMAL}"
	printf "\n${COLOR}FINISHED: in $MEASURED_TIME seconds ($CALLER).${NORMAL}"
	printf "\n${COLOR}$SEPARATOR${NORMAL}\n"
}

##############################################################################
# Replace standard ECHO function with custom output
# PARAMS:		1 - Text to show (mandatory)
# 				2 - Logging level (optional) - see levels below
##############################################################################
# Available logging levels (least to most verbose)
ECHO_NONE=0
ECHO_NO_PREFIX=1
ECHO_ERROR=2
ECHO_WARNING=3
ECHO_INFO=4
ECHO_DEBUG=5
# Default logging level
ECHO_LEVEL=$ECHO_DEBUG

echo_my()
{
	local RED='\033[0;31m'
	local GREEN='\033[32m'
	local ORANGE='\033[33m'
	local NORMAL='\033[0m'
	local PREFIX="$CALLER->"

	if [ $# -gt 1 ]; then
		local ECHO_REQUESTED=$2
	else
		local ECHO_REQUESTED=$ECHO_INFO
	fi

	if [ $ECHO_REQUESTED -gt $ECHO_LEVEL ]; then return; fi
	if [ $ECHO_REQUESTED = $ECHO_NONE ]; then return; fi
	if [ $ECHO_REQUESTED = $ECHO_ERROR ]; then PREFIX="${RED}[ERROR] ${PREFIX}"; fi
	if [ $ECHO_REQUESTED = $ECHO_WARNING ]; then PREFIX="${RED}[WARNING] ${PREFIX}"; fi
	if [ $ECHO_REQUESTED = $ECHO_INFO ]; then PREFIX="${GREEN}[INFO] ${PREFIX}"; fi
	if [ $ECHO_REQUESTED = $ECHO_DEBUG ]; then PREFIX="${ORANGE}[DEBUG] ${PREFIX}"; fi
	if [ $ECHO_REQUESTED = $ECHO_NO_PREFIX ]; then PREFIX="${GREEN}"; fi

  measure_timer
	printf "${PREFIX}$1 ($MEASURED_TIME seconds)${NORMAL}\n"
}

###############################################
# This creates proper resources for Cloud to Car communication
###############################################
create_resources()
{
  echo_my "Create Topics and Subscriptions for car to cloud communication..."

  if gcloud pubsub topics list | grep $COMMAND_TOPIC; then
    echo_my "Topic $COMMAND_TOPIC found OK"
  else
    echo_my "Create PubSub topic '$COMMAND_TOPIC'..."
    gcloud pubsub topics create $COMMAND_TOPIC
  fi

  if gcloud pubsub topics list | grep $SENSOR_TOPIC; then
    echo_my "Topic $SENSOR_TOPIC found OK"
  else
    echo_my "Create PubSub topic '$SENSOR_TOPIC'..."
    gcloud pubsub topics create $SENSOR_TOPIC
  fi

  if gcloud pubsub subscriptions list | grep $SENSOR_SUBSCRIPTION; then
    echo_my "Drop and create subscription for sensor data to avoid processing of old messages..."
    gcloud pubsub subscriptions delete $SENSOR_SUBSCRIPTION
  fi

  echo_my "Creating a subscription '$SENSOR_SUBSCRIPTION'..."
  gcloud pubsub subscriptions create $SENSOR_SUBSCRIPTION --topic $SENSOR_TOPIC
}

###############################################
# Create GCS bucket to upload images from the car
###############################################
create_gcs_camera_bucket()
{
  echo_my "Creating GCS bucket for car images..."
  if gsutil ls | grep ${CAR_CAMERA_BUCKET}; then
      echo_my "Bucket $CAR_CAMERA_BUCKET found OK"
  else
      echo_my "Create GCS bucket for images: '$CAR_CAMERA_BUCKET'..."
      gsutil mb -p $PROJECT gs://${CAR_CAMERA_BUCKET}/
      # Make bucket visible to the public - this is needed for the web app to work to show images in a browser
      gsutil iam ch allUsers:objectViewer gs://${CAR_CAMERA_BUCKET}
  fi
}

###############################################
# Install Node and NPM
###############################################
install_node()
{
  local CWD=$(pwd)
  echo_my "Installing Node.js..."

  if which sw_vers; then
    echo_my "MAC OS found"
    if which node; then
      echo_my "node and npm are already installed"
    else
      echo_my "Please install and configure nodeJS as described here: https://nodesource
      .com/blog/installing-nodejs-tutorial-mac-os-x/"
      exit 1
    fi
  else
    lsb_release -a
    echo_my "We are running on Linux"
    echo_my "Downloading 'node'..."
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    echo_my "Installing 'node'..."
    sudo apt-get install nodejs
  fi

  node -v
  npm -v
  cd js
  echo_my "Installing npm modules..."
  npm install
  # npm install --save @google-cloud/debug-agent @google-cloud/bigquery
  cd ${CWD}
}

###############################################################################
# Lookup Org ID from the Domain name
###############################################################################
lookup_org_id() {
  if [ -z ${ORGANIZATION_ID+x} ] ; then
      ORGANIZATION_ID=$(gcloud organizations list | grep ${DOMAIN} | awk '{print $2}')
  fi

  echo "$ORGANIZATION_ID"
}

echo "setenv-global.sh: done"
