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

###############################################
# Control GoPiGo car by sending sensor messages 
# to the cloud and receiving driving commands
###############################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../../setenv-global.sh

export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_SECRET"

# This is subscription for the car to listen to incoming control messages
export COMMAND_SUBSCRIPTION="driving-command-subscription-$CAR_ID"

### Obstacle avoidance - the number of millimeters to stop the car before hitting an object
export BARRIER_DAMPENING="180"

### Car Camera position; UPSIDE DOWN=0; NORMAL=1 - this takes effect on the car as the image will be flipped before being sent to the cloud
export CAR_CAMERA_NORMAL="0"

### What color ball this car will be playing (default value)
export CAR_COLOR="red"

###############################################
# This is run once after creating new environment
###############################################
install() {
    echo_my "Installing Python, Pip and other libraries..."
    sudo apt-get install python
    sudo apt-get install python-pip
    sudo pip install --upgrade pip
    sudo pip install --upgrade google-cloud --ignore-installed six
    sudo pip install paho-mqtt
    sudo pip install --upgrade pip setuptools
    sudo pip install curtsies
    wget https://bootstrap.pypa.io/ez_setup.py -O - | sudo python
    sudo apt-get install build-essential libssl-dev libffi-dev python3-dev
    sudo pip install pyasn1 pyasn1-modules -U
    sudo pip install cryptography
    sudo pip install PyJWT 
    sudo pip install Pillow 
    wget https://pypi.python.org/packages/16/d8/bc6316cf98419719bd59c91742194c111b6f2e85abac88e496adefaf7afe/six-1.11.0.tar.gz#md5=d12789f9baf7e9fb2524c0c64f1773f8
    sudo tar -zxvf six-1.11.0.tar.gz
    sudo python ./six-1.11.0/setup.py install
}

###############################################
# One time car setup tasks
###############################################
setup() {
    echo_my "Setting up car environment for the first run..."
    if which pip; then
      echo "Python and Pip are already installed, skipping this step."
    else
      install
    fi

    wget https://pki.google.com/roots.pem
}

###############################################
# Generate keys for the IOT device
###############################################
generate_keys() {
  echo_my "Generating keys for the IOT device..."
  openssl req -x509 -newkey rsa:2048 -days 3650 -keyout rsa_private.pem -nodes -out \
  rsa_cert.pem -subj "/CN=unused"
  openssl ecparam -genkey -name prime256v1 -noout -out ec_private.pem
  openssl ec -in ec_private.pem -pubout -out ec_public.pem
}

###############################################
# MAIN
###############################################
mkdir -p tmp
echo_my "CAR_ID=$CAR_ID"
INSTALL_FLAG=tmp/install.marker  # Location where the install flag is set to avoid repeated installs

if [ -f "$INSTALL_FLAG" ]; then
    echo_my "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else    
    setup
    touch $INSTALL_FLAG
fi

gcloud config set project $PROJECT

echo "Activating service account '$SERVICE_ACCOUNT_SECRET'..."
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_SECRET

echo_my "Using subscription '$COMMAND_SUBSCRIPTION' to read data from the driving controller..."
if gcloud pubsub subscriptions list | grep $COMMAND_SUBSCRIPTION; then
	echo_my "Subscription '$COMMAND_SUBSCRIPTION' already exists - dropping it to avoid processing of old messages..."
	gcloud pubsub subscriptions delete $COMMAND_SUBSCRIPTION | true # ignore if not found
fi

echo_my "Creating a subscription '$COMMAND_SUBSCRIPTION' to topic '$COMMAND_TOPIC'..."
gcloud pubsub subscriptions create $COMMAND_SUBSCRIPTION --topic $COMMAND_TOPIC | true

if gcloud iot registries list --region=$REGION | grep $IOT_CORE_REGISTRY; then
	echo_my "IOT Core Registry $IOT_CORE_REGISTRY already exists. Updating for consistency..."
	gcloud iot registries update $IOT_CORE_REGISTRY --project=$PROJECT --region=$REGION \
	    --event-notification-config=topic=projects/$PROJECT/topics/$SENSOR_TOPIC,subfolder=$SENSOR_TOPIC \
	    --event-notification-config=topic=projects/$PROJECT/topics/$COMMAND_TOPIC,subfolder=$COMMAND_TOPIC \
	    | true
else
	echo_my "Creating an IOT Core Device for Registry: '$IOT_CORE_REGISTRY' "
	gcloud iot registries create $IOT_CORE_REGISTRY --project=$PROJECT --region=$REGION \
	    --event-notification-config=topic=projects/$PROJECT/topics/$SENSOR_TOPIC,subfolder=$SENSOR_TOPIC \
	    --event-notification-config=topic=projects/$PROJECT/topics/$COMMAND_TOPIC,subfolder=$COMMAND_TOPIC \
	    | true
fi

if ls | grep rsa_private.pem; then
    echo_my "Private Key Pairs exist for IOT Core"
else
    generate_keys
fi

if gcloud iot devices list --project=$PROJECT --region=$REGION --registry=$IOT_CORE_REGISTRY | grep $IOT_CORE_DEVICE_ID; then
	echo_my "IOT Core Device ID '$IOT_CORE_DEVICE_ID' already registered."
else
	echo_my "Registering IOT Core Device ID '$IOT_CORE_DEVICE_ID'..."
	gcloud iot devices create $IOT_CORE_DEVICE_ID --project=$PROJECT --region=$REGION --registry=$IOT_CORE_REGISTRY \
	    --public-key path=rsa_cert.pem,type=rs256 | true
fi

if gsutil ls | grep $CAR_CAMERA_BUCKET; then
    echo_my "Bucket $CAR_CAMERA_BUCKET found OK"
else
    echo_my "Create GCS bucket for images: '$CAR_CAMERA_BUCKET'..."
    gsutil mb -p $PROJECT gs://$CAR_CAMERA_BUCKET/
    # Make bucket visible to the public - this is needed for the web app to work to show images in a browser
    # TODO: do not make this bucket visible to the public and instead let Web App run with the service account that
    #  will have access to the bucket contents. Also need to run a DEMO inference VM with proper permissions to have
    #  access to any bucket in the GCP Org
#    gsutil iam ch allUsers:objectViewer gs://$CAR_CAMERA_BUCKET
#    gsutil iam ch allUsers:legacyBucketReader gs://$CAR_CAMERA_BUCKET
fi

cd py

# Start the car
if [[ $# -gt 0 && "$1" != ""  && "$1" == "--non-interactive" ]] ; then
  ./drive.py $PROJECT $COMMAND_SUBSCRIPTION --non-interactive
else
  ./drive.py $PROJECT $COMMAND_SUBSCRIPTION
fi