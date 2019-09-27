#!/bin/bash

###############################################################
# Car Driving Controller
# Can be run locally as node process or deployed into GAE
###############################################################

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

TMP="$(pwd)/tmp"
mkdir -p ${TMP}

### Defines the name of the App Engine Flex App and forms part of URL
APP_NAME=driving-controller

### Configuration of the deployment for App Engine
YAML_FILE=$(pwd)/js/app-generated.yml

###############################################
# This generates proper YAML connfig for the app
###############################################
generate_yaml()
{
  echo_my "Generating YAML config..."
# Create 'app.yaml' file for the deployment configuration
cat << EOF > $YAML_FILE
# This file is auto-generated - DO NOT edit it manually as it will be overriden
# Docs: https://cloud.google.com/appengine/docs/standard/nodejs/config/appref

# App Engine Standard
runtime: nodejs10

# App Engine Flex
# runtime: nodejs

# This makes it run in App Engine Flex
# env: flex

manual_scaling:
    instances: 1

env_variables:
    SENSOR_SUBSCRIPTION: $SENSOR_SUBSCRIPTION
    COMMAND_TOPIC: $COMMAND_TOPIC
    INFERENCE_USER_NAME: $INFERENCE_USER_NAME
    INFERENCE_PASSWORD: $INFERENCE_PASSWORD
    INFERENCE_IP: $INFERENCE_IP
    INFERENCE_URL: $INFERENCE_URL
    HTTP_PORT: $HTTP_PORT
    CAR_ID: $CAR_ID
    BALL_LABEL_SUFFIX: $BALL_LABEL_SUFFIX
    HOME_LABEL_SUFFIX: $HOME_LABEL_SUFFIX
    BLUE_BALL_LABEL: $BLUE_BALL_LABEL
    RED_BALL_LABEL: $RED_BALL_LABEL
    YELLOW_BALL_LABEL: $YELLOW_BALL_LABEL
    GREEN_BALL_LABEL: $GREEN_BALL_LABEL
    BLUE_HOME_LABEL: $BLUE_HOME_LABEL
    RED_HOME_LABEL: $RED_HOME_LABEL
    YELLOW_HOME_LABEL: $YELLOW_HOME_LABEL
    GREEN_HOME_LABEL: $GREEN_HOME_LABEL
EOF
}

###############################################
# MAIN
###############################################
print_header "Starting application '$APP_NAME'"

CWD=$(pwd)
# Location where the install flag is set to avoid repeated installs
INSTALL_FLAG=${TMP}/install.marker

if [ -f "$INSTALL_FLAG" ]; then
  echo_my "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else
  install_node
  touch $INSTALL_FLAG
fi

create_resources

# Lookup actual IP address for inference VM from the static reference
if $USE_DEMO_INFERENCE ; then
  # Driving controller will be using the inference VM that has been stood up in advance in a different project
  export INFERENCE_IP=$(gcloud compute addresses describe $DEMO_INFERENCE_IP_NAME --region us-central1 --format="value(address)" --project $DEMO_PROJECT)
else
  # Find the IP of the inference VM that was created in this project
  export INFERENCE_IP=$(gcloud compute addresses describe $ML_IP_NAME --region $REGION --format="value(address)")
fi
echo_my "INFERENCE_IP=$INFERENCE_IP"

cd $CWD/js

if $DRIVING_CONTROLLER_LOCAL ;
then
  echo_my "DRIVING_CONTROLLER_LOCAL='$DRIVING_CONTROLLER_LOCAL' (set it to false to deploy on GCP) - running on local machine (use this for test and dev only)..."
  # The default credentials below are needed for the controller to run locally in unix or mac dev environment when deployed locally
  export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_SECRET
  npm start
else
  generate_yaml
  URL=https://${APP_NAME}-dot-${PROJECT}.appspot.com/
  echo_my "Deploying into Google App Engine using YAML file '${YAML_FILE}'. Current directory is '$(pwd)'..."
  yes | gcloud app deploy "${YAML_FILE}" --project ${PROJECT}
  # Ping the app to see if it is available
  curl -G "${URL}"
  echo_my "Running on GCP URL=$URL"
fi

print_footer "Driving Controller has been started."
