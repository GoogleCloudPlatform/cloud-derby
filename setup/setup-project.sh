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
# This script sets up development VM and creates Cloud Derby Project if needed.
##########################################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

### Role of the service account, so that we can deploy resources using SA instead of human account
ROLE="CloudDerbyDeveloperRole"
TMP="tmp"
PROJECT_NAME_FILE="$HOME/project-id.sh"

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
      local NOW=$(date +%Y-%m-%d.%H:%M:%S)
      mv $SERVICE_ACCOUNT_SECRET ${SERVICE_ACCOUNT_SECRET}.$NOW
  fi
  
  echo "Creating service account keys..."
  gcloud iam service-accounts keys create $SERVICE_ACCOUNT_SECRET --iam-account $ALLMIGHTY_SERVICE_ACCOUNT
  
  local DELAY="3s"
  
  echo "Grant dev role..." && sleep $DELAY
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" --role="projects/$PROJECT/roles/$ROLE"

  echo "Grant IoT Admin role..." && sleep $DELAY
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" --role="roles/cloudiot.admin"

  echo "Grant GCE admin Admin role..." && sleep $DELAY
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" --role="roles/compute.instanceAdmin.v1"
      
  echo "Grant Image User role..." && sleep $DELAY
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" --role="roles/compute.imageUser"
      
  echo "Grant Network Admin User role..." && sleep $DELAY
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" --role="roles/compute.networkAdmin"
      
  echo "Grant Firewall admin role..." && sleep $DELAY
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ALLMIGHTY_SERVICE_ACCOUNT" --role="roles/compute.securityAdmin"
}

#############################################
# Create Special Cloud Derby Role
#############################################
create_role() {
  if gcloud beta iam roles list --project $PROJECT | grep -q $ROLE; then
      echo "Role '$ROLE' already exists."
      return
  fi

  echo "Creating a role..."
  PERMISSIONS="\
appengine.applications.create,\
appengine.applications.get,\
appengine.applications.update,\
appengine.instances.delete,\
appengine.instances.get,\
appengine.instances.list,\
appengine.services.delete,\
appengine.services.get,\
appengine.services.list,\
appengine.services.update,\
appengine.versions.create,\
appengine.versions.delete,\
appengine.versions.get,\
appengine.versions.list,\
appengine.versions.update,\
compute.projects.get,\
compute.projects.setCommonInstanceMetadata,\
ml.jobs.cancel,\
ml.jobs.create,\
ml.jobs.get,\
ml.jobs.getIamPolicy,\
ml.jobs.list,\
ml.jobs.setIamPolicy,\
ml.jobs.update,\
ml.locations.get,\
ml.locations.list,\
ml.models.create,\
ml.models.delete,\
ml.models.get,\
ml.models.getIamPolicy,\
ml.models.list,\
ml.models.predict,\
ml.models.setIamPolicy,\
ml.models.update,\
ml.operations.cancel,\
ml.operations.get,\
ml.operations.list,\
ml.projects.getConfig,\
ml.versions.create,\
ml.versions.delete,\
ml.versions.get,\
ml.versions.list,\
ml.versions.predict,\
ml.versions.update,\
pubsub.subscriptions.consume,\
pubsub.subscriptions.create,\
pubsub.subscriptions.delete,\
pubsub.subscriptions.get,\
pubsub.subscriptions.list,\
pubsub.subscriptions.update,\
pubsub.topics.attachSubscription,\
pubsub.topics.create,\
pubsub.topics.delete,\
pubsub.topics.get,\
pubsub.topics.list,\
pubsub.topics.publish,\
pubsub.topics.update,\
resourcemanager.projects.get,\
resourcemanager.projects.getIamPolicy,\
resourcemanager.projects.setIamPolicy,\
resourcemanager.projects.undelete,\
resourcemanager.projects.update,\
resourcemanager.projects.updateLiens,\
storage.buckets.create,\
storage.buckets.delete,\
storage.buckets.get,\
storage.buckets.getIamPolicy,\
storage.buckets.list,\
storage.buckets.setIamPolicy,\
storage.buckets.update,\
storage.objects.create,\
storage.objects.delete,\
storage.objects.get,\
storage.objects.getIamPolicy,\
storage.objects.list,\
storage.objects.setIamPolicy,\
storage.objects.update"

  gcloud beta iam roles create $ROLE \
      --project $PROJECT \
      --title "Cloud Derby Developer Role" \
      --description "Access to resources needed to develop and deploy Cloud Derby" \
      --stage "GA" \
      --permissions $PERMISSIONS
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
  APIS="ml.googleapis.com \
      pubsub.googleapis.com \
      storage-component.googleapis.com \
      storage-api.googleapis.com \
      compute.googleapis.com \
      appengineflex.googleapis.com \
      appengine.googleapis.com \
      cloudresourcemanager.googleapis.com \
      sourcerepo.googleapis.com \
      cloudiot.googleapis.com"

      # servicemanagement.googleapis.com \

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

mkdir -p tmp
INSTALL_FLAG=tmp/install.marker
if [ -f "$INSTALL_FLAG" ]; then
    echo "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else    
    yes | sudo apt-get update
    yes | sudo apt-get --assume-yes install bc
    yes | sudo apt-get install apt-transport-https unzip zip
    echo "Checking whether we need to install gcloud..."
    command -v gcloud >/dev/null 2>&1 || { echo >&2 "'gcloud' is not installed."; install_gcp_sdk ; }
    # if lsb_release -i | grep -q Raspbian; then echo "Installing Startup Scripts for Car"; install_startup_scripts; fi;
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
if ! [ -f $HOME/setenv-local.sh ] ; then
    cp ./template-setenv-local.sh $HOME/setenv-local.sh
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
    create_role
    enable_project_apis
    create_appengine_app
    create_service_account
fi

gcloud config set project $PROJECT

echo "#################################################"
echo "              Project setup complete"
echo "#################################################"