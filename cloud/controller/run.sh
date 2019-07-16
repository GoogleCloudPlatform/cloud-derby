#!/bin/bash

###############################################
# Car Driving Controller
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

### Defines the name of the App Engine Flex App and forms part of URL
APP_NAME=driving-controller

### Configuration of the deployment for 
YAML_FILE=app-generated.yml

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
runtime: nodejs8

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
    BLUE_BALL_LABEL: Blue$BALL_LABEL_SUFFIX
    RED_BALL_LABEL: Red$BALL_LABEL_SUFFIX
    YELLOW_BALL_LABEL: Yellow$BALL_LABEL_SUFFIX
    GREEN_BALL_LABEL: Green$BALL_LABEL_SUFFIX
    BLUE_HOME_LABEL: Blue$HOME_LABEL_SUFFIX
    RED_HOME_LABEL: Red$HOME_LABEL_SUFFIX
    YELLOW_HOME_LABEL: Yellow$HOME_LABEL_SUFFIX
    GREEN_HOME_LABEL: Green$HOME_LABEL_SUFFIX
EOF
}

###############################################
# MAIN
###############################################
print_header "Start application '$APP_NAME'"

mkdir -p tmp
CWD=$(pwd)
# Location where the install flag is set to avoid repeated installs
INSTALL_FLAG=$CWD/tmp/install.marker

if [ -f "$INSTALL_FLAG" ]; then
  echo_my "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else
  install_node
  touch $INSTALL_FLAG
fi

# The service account is needed to get permissions to create resources
# TODO - verify permissions to allow deployment into the GAE
#gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_SECRET

create_resources

# Lookup actual IP address for inference VM from the static reference
if $USE_DEMO_INFERENCE ; then
  # Driving controller will be using the inference VM that has been stood up in advance in a different project
#  TODO - check why there are no permissions to lookup IP address in demo project
# TODO - verify why demo inference VM has permission issue with access to images in other projects
  export INFERENCE_IP=$(gcloud compute addresses describe $DEMO_INFERENCE_IP_NAME --region us-central1 --format="value(address)" --project $DEMO_PROJECT)
else
  # Find the IP of the inference VM that was created in this project
  export INFERENCE_IP=$(gcloud compute addresses describe $ML_IP_NAME --region $REGION --format="value(address)")
fi
echo_my "INFERENCE_IP=$INFERENCE_IP"

cd $CWD/js
if [ -f "nohup.out" ] ; then
  rm -rf nohup.out
fi

if $DRIVING_CONTROLLER_LOCAL ;
then
  echo_my "DRIVING_CONTROLLER_LOCAL='$DRIVING_CONTROLLER_LOCAL' (set it to false to deploy on GCP) - running on local machine (use this for test and dev only)..."
  # The default credentials below are needed for the controller to run locally in unix or mac dev environment when deployed locally
  export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_SECRET
  npm start
else
  generate_yaml
  URL=https://${APP_NAME}-dot-${PROJECT}.appspot.com/
  echo_my "Deploying into GCP App Engine (used for production)..."
  yes | gcloud app deploy $YAML_FILE --project $PROJECT
  # Ping the app to see if it is available
  curl -G $URL
  echo_my "Running on GCP URL=$URL"
fi

print_footer "Driving Controller has been started."