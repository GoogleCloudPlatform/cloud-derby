#!/bin/bash

##########################################################################################
# This script sets up development VM and creates Cloud Derby Project if needed.
##########################################################################################

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

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

TMP="tmp"
CWD=$(pwd)
cd ..
PROJECT_DIR=$(pwd)
PROJECT_NAME_FILE="${PROJECT_DIR}/project-id.sh"
cd ${CWD}

##################################################################################
# Save project ID into a file
# Input:
#   1 - Project ID
##################################################################################
save_project_id() {
  local PROJECT_ID=$1

  if [ -f $PROJECT_NAME_FILE ] ; then
    local NOW=$(date +%Y-%m-%d.%H:%M:%S)
    mv $PROJECT_NAME_FILE ${PROJECT_NAME_FILE}.$NOW
  fi

  echo "export PROJECT=$PROJECT_ID" > $PROJECT_NAME_FILE
}

##################################################################################
# Generate random project ID
##################################################################################
generate_project_id() {
  echo "cloud-derby-$(date +%s | sha256sum | base64 | head -c 8)" | tr '[:upper:]' '[:lower:]'
}

#############################################
# Ask user if he wants a new project or not
# Returns:
#   TRUE - if user wants to create new project
#   FALSE - if user does not want to create new project
#############################################
ask_create_project() {
  if gcloud projects list | grep -q $PROJECT; then
    # If project already exists, no need to create it
    echo "false"
  else
    read -p "********************** Do you want to create new project named '$PROJECT'? (y/n)" choice
    case "$choice" in
      y|Y ) echo "true";;
      n|N ) echo "false";;
      * ) echo "false";;
    esac
  fi
}

#############################################
# Ask user if he wants to setup roles and accounts
# Returns:
#   TRUE - if user wants to create new project
#   FALSE - if user does not want to create new project
#############################################
ask_create_roles() {
  read -p "********************** Do you want to setup new roles, enable APIs and generate new service account now? (y/n)" choice
  case "$choice" in
  y|Y ) echo "true";;
  n|N ) echo "false";;
  * ) echo "false";;
  esac
}

#############################################
# Create new project in GCP
#############################################
create_project() {
  echo "Creating new project '$PROJECT'..."
  PROJECT_JSON_REQUEST=project.json
  echo "Creating JSON request file $TMP/$PROJECT_JSON_REQUEST..."
  ### This folder will host the project - you can lookup ID in the GCP Console
  #   This is only used for programmatic creation of the project, not when it is created manually from the console or command line
  local PARENT_FOLDER=1081904530671

  if [ ! -d "$TMP" ]; then
  mkdir $TMP
  fi

  if [ -f "$TMP/$PROJECT_JSON_REQUEST" ]; then
    rm -f $TMP/$PROJECT_JSON_REQUEST
  fi

  cat << EOF > $TMP/$PROJECT_JSON_REQUEST
{
    "projectId": "$PROJECT",
    "name": "$PROJECT project",
    "parent": {
        id: "$PARENT_FOLDER",
        type: "folder"
    },
    "labels": {
      "environment": "development"
    }
}
EOF
   
  echo "Obtaining ACCESS_TOKEN for service []account..."
  ACCESS_TOKEN=$(gcloud auth print-access-token)

  echo "Creating new project '$PROJECT'..."
  GOOGLE_API_URL="https://cloudresourcemanager.googleapis.com/v1/projects/"
  curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ACCESS_TOKEN" -d @${TMP}/${PROJECT_JSON_REQUEST} ${GOOGLE_API_URL}
}

##########################################################################################
# This installs Docker on Debian Linux
##########################################################################################
install_docker() {
  if which docker; then
    echo "Docker is already installed - nothing to do."
    return
  fi
  sudo apt-get update
  sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  sudo apt-key fingerprint 0EBFCD88
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install docker-ce
  # Test if this works
  sudo docker run hello-world
}

#############################################
# Create Service Account
#############################################
create_service_account() {
  if gcloud iam service-accounts list --project $PROJECT | grep -q $SERVICE_ACCOUNT; then
    echo "Service account $SERVICE_ACCOUNT has been found - please go to GCP Console and download the key."
    return
  fi

  echo "Creating service account... $ALLMIGHTY_SERVICE_ACCOUNT"
  gcloud iam service-accounts create $SERVICE_ACCOUNT --display-name "Cloud Derby developer service account"

  mkdir -p $SERVICE_ACCOUNT_DIR
  if [ -f $SERVICE_ACCOUNT_SECRET ] ; then
    # Make a backup copy of the existing key
    local NOW=$(date +%Y-%m-%d.%H:%M:%S)
    mv $SERVICE_ACCOUNT_SECRET ${SERVICE_ACCOUNT_SECRET}.$NOW
  fi

  echo "Creating service account keys..."
  gcloud iam service-accounts keys create $SERVICE_ACCOUNT_SECRET --iam-account $ALLMIGHTY_SERVICE_ACCOUNT

  echo "Grant $DERBY_DEV_ROLE role to the service account $ALLMIGHTY_SERVICE_ACCOUNT ..."
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" \
      --role="organizations/$(lookup_org_id)/roles/$DERBY_DEV_ROLE"

#  echo "Grant IoT Admin role..." && sleep $DELAY
#  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" \
#      --role="roles/cloudiot.admin"

#  echo "Grant GCE Admin role..." && sleep $DELAY
#  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" \
#      --role="roles/compute.instanceAdmin.v1"

#  echo "Grant Image User role..." && sleep $DELAY
#  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" \
#      --role="roles/compute.imageUser"

#  echo "Grant Network Admin User role..." && sleep $DELAY
#  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" \
#      --role="roles/compute.networkAdmin"

#  echo "Grant Firewall admin role..." && sleep $DELAY
#  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" \
#      --role="roles/compute.securityAdmin"
}

#############################################
# Install GCP SDK
#############################################
install_gcp_sdk() {
	echo "Prepare to install GCP SDK..."
	export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
	echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | \
	        sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

	echo "Install GCP SDK..."
	sudo apt-get update && sudo apt-get install google-cloud-sdk

  if  [[ $(uname -a) = *" dex "* ]]; then
      echo "Detected GoPiGo environment..."
  else
      echo "Install additional components into development environment..."
    sudo apt-get update && sudo apt-get --only-upgrade install \
        google-cloud-sdk google-cloud-sdk-app-engine-grpc \
        google-cloud-sdk-pubsub-emulator \
        google-cloud-sdk-datastore-emulator \
        google-cloud-sdk-app-engine-python google-cloud-sdk-cbt \
        google-cloud-sdk-app-engine-python-extras
  fi
}

#############################################
# Enable APIs for the project
#############################################
enable_project_apis() {
#  ml.googleapis.com
  APIS="pubsub.googleapis.com \
    storage-component.googleapis.com \
    storage-api.googleapis.com \
    compute.googleapis.com \
    appengine.googleapis.com \
    cloudresourcemanager.googleapis.com \
    cloudiot.googleapis.com"

  echo "Enabling APIs on the project..."
  gcloud services enable $APIS --async
}

#############################################
# Create AppEngine App for the project
#############################################
create_appengine_app() {
  if gcloud app describe 2>&1 >/dev/null | grep 'does not contain an App Engine application' > /dev/null; then
      echo "GAE Default App not found - initializing AppEngines on the project..."
      gcloud app create --region=$REGION_LEGACY
  else
      echo "GAE Default App already exists, skipping this step."
  fi
}

#############################################
# Install Startup Scripts for car
#############################################
install_startup_scripts() {
  sudo mkdir /etc/sysconfig
  sudo cp ./systemd/driver.service /etc/systemd/system/
  sudo cp ./systemd/driver.env /etc/sysconfig/
  sudo systemctl daemon-reload
}

#############################################
# MAIN
#############################################
echo "#################################################"
echo "     Starting the project setup process..."
echo "#################################################"

mkdir -p ${TMP}
INSTALL_FLAG=${TMP}/install.marker
if [ -f "$INSTALL_FLAG" ]; then
    echo "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else
    if which sw_vers; then
        echo "MAC OS found"
        if which gcloud; then
            echo "gcloud is already installed"
        else
            echo "Please install and configure gcloud SDK as described here: https://cloud.google.com/sdk/docs/quickstart-macos"
            exit 1
        fi
    else
        lsb_release -a
        echo "We are running on Linux"
        yes | sudo apt-get update
        yes | sudo apt-get --assume-yes install bc
        yes | sudo apt-get install apt-transport-https unzip zip
        echo "Checking whether we need to install gcloud..."
        command -v gcloud >/dev/null 2>&1 || { echo >&2 "'gcloud' is not installed."; install_gcp_sdk ; }
        # if lsb_release -i | grep -q Raspbian; then echo "Installing Startup Scripts for Car"; install_startup_scripts; fi;
    fi

    touch $INSTALL_FLAG
fi

# Have we been provided with the project ID as command line parameter?
if [[ $# -eq 1 ]]; then
    PROJECT=$1
    save_project_id $PROJECT
else
    if [ -f $PROJECT_NAME_FILE ] ; then
        source $PROJECT_NAME_FILE
    else
        save_project_id $(generate_project_id)
    fi
fi

# If there is not an environment file yet in the home directory of the user - make a copy
if ! [ -f ${PROJECT_DIR}/setenv-local.sh ] ; then
    cp ./template-setenv-local.sh ${PROJECT_DIR}/setenv-local.sh
fi

source ../setenv-global.sh

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

if $(ask_create_project) ; then 
    create_project
    # Check if project is created before moving on
    i="0"
    while [ $i -lt 5 ]
    do
        if gcloud projects list | grep -q $PROJECT; then
             echo "Project '$PROJECT' has been found."
             break
        else
             echo "Waiting on Project '$PROJECT' creation to finish..."
             ((i+=1))
             sleep 5s
             # If after 30 seconds project is not found then exit script
             if [ $i -eq 5 ]; then
                  echo "ERROR: Project '$PROJECT' not created in time, script will exit now, please check for errors in project creation!"
                  exit 1
             fi
        fi
    done
    gcloud alpha billing projects link $PROJECT --billing-account $BILLING_ACCOUNT_ID
fi

if $(ask_create_roles) ; then 
    enable_project_apis
    create_appengine_app
    create_service_account
fi

gcloud config set project $PROJECT

echo "#################################################"
echo "              Project setup complete"
echo "#################################################"
