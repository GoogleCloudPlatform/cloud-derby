#!/bin/bash

###############################################################################
# This script creates new hackathon event with users and folders generated
###############################################################################

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

source ./setenv.sh

### File with the list of user names and passwords
USER_LIST="$TMP/users.csv"

###############################################################################
# Create special Read Only group 
###############################################################################
create_read_only_group() {
    echo_my "Create read only group '$ADMIN_READ_GROUP'..."
    $GAM create group "$ADMIN_READ_GROUP" name "Resource Read-Only group" description "Read only access to common resources" | true # ignore if error
    echo_my "Permissions for project '$ADMIN_PROJECT_ID'..."
    COMMAND="gcloud projects add-iam-policy-binding $ADMIN_PROJECT_ID --member=group:$ADMIN_READ_GROUP --role=roles/"

    echo_my "All users need to be able to read pre-annotated images..."
    eval ${COMMAND}storage.objectViewer

    echo_my "All users need to be able to use Windows VM image we provide for annotations with some software pre-installed on it..."
    eval ${COMMAND}compute.imageUser

    echo_my "All users need to be able to lookup IP address of the DEMO Inference VM from project '$DEMO_PROJECT'..."
    gcloud projects add-iam-policy-binding $DEMO_PROJECT --member=group:$ADMIN_READ_GROUP --role="roles/compute.networkUser"
}

###############################################################################
# Add user to the domain: https://developers.google.com/admin-sdk/directory/v1/guides/manage-users
# Input:
#   1 - user number
#   2 - team number
###############################################################################
add_user() {
    local USER_NUM=$1
    local TEAM_NUM=$2
    local PASSWORD=$(generate_password)

    $GAM create user $(user_name $USER_NUM $TEAM_NUM) firstname "User$USER_NUM" lastname "Member of Team $TEAM_NUM" \
        password $PASSWORD

    echo "$(user_name $USER_NUM $TEAM_NUM)@$DOMAIN,$PASSWORD" >> ${USER_LIST}
}

###############################################################################
# Add new team to the domain
# Input:
#   1 - team number
###############################################################################
create_team() {
    local TEAM_NUM=$1
    echo_my "create_team(): Creating team #$TEAM_NUM..."

    $GAM create group "$(team_name $TEAM_NUM)" name "Car team $TEAM_NUM" description \
        "Developers working on the car # $TEAM_NUM" | true # ignore if error
    
    for j in $(seq 1 $NUM_PEOPLE_PER_TEAM);
    do
        add_user $j $TEAM_NUM
        echo_my "Adding user to his team group..."
        $GAM update group "$(team_name $TEAM_NUM)" add member $(user_name $j $TEAM_NUM)@$DOMAIN
        echo_my "Adding user to the read-only group for shared resources..."
        $GAM update group "$ADMIN_READ_GROUP" add member $(user_name $j $TEAM_NUM)@$DOMAIN
    done
}

###############################################################################
# Create all groups
###############################################################################
create_groups_and_users() {
    echo_my "create_groups_and_users(): started..."
    echo "Email,Password" > $USER_LIST

    for i in $(seq $TEAM_START_NUM $NUM_TEAMS);
    do
        create_team $i
    done
}

###############################################################################
# Create folders and projects in GCP
###############################################################################
create_folders() {
    echo_my "create_folders(): Creating event parent folder..."
    gcloud alpha resource-manager folders create --display-name=$TOP_FOLDER --organization=$(lookup_org_id) | true # ignore if already exists

    echo_my "Creating children folders for each car team..."
    local PARENT_FOLDER_ID=$(find_top_folder_id $TOP_FOLDER)
    
    for i in $(seq $TEAM_START_NUM $NUM_TEAMS);
    do
        gcloud alpha resource-manager folders create --display-name=$(team_folder_name $i) --folder=$PARENT_FOLDER_ID

        local NEW_FOLDER_ID=$(find_folder_id $(team_folder_name $i) $PARENT_FOLDER_ID)
        echo_my "NEW_FOLDER_ID=$NEW_FOLDER_ID"

        # See docs: https://cloud.google.com/iam/docs/understanding-roles
        gcloud alpha resource-manager folders add-iam-policy-binding $NEW_FOLDER_ID \
		          --member=group:$(team_name $i)@$DOMAIN --role="organizations/$(lookup_org_id)/roles/$DERBY_DEV_ROLE"
    done
}

#############################################
# Create Special Cloud Derby Role
#############################################
create_role() {
  if gcloud iam roles list --organization $(lookup_org_id) | grep -q $DERBY_DEV_ROLE; then
    echo_my "Role '$DERBY_DEV_ROLE' already exists - updating it..."
    ACTION="update"
  else
    echo "Creating a role '$DERBY_DEV_ROLE'..."
    ACTION="create"
  fi

#resourcemanager.folderEditor
#resourcemanager.folderIamAdmin
#resourcemanager.projectIamAdmin
#resourcemanager.folderCreator
#dialogflow.admin
#iam.serviceAccountAdmin
#iam.serviceAccountKeyAdmin
#iam.serviceAccountTokenCreator
#iam.serviceAccountUser
#iam.securityReviewer
#servicemanagement.quotaAdmin
#errorreporting.admin
#logging.admin
#monitoring.admin
#cloudiot.admin
#compute.instanceAdmin.v1
#compute.imageUser
#compute.networkAdmin
#compute.securityAdmin
#clouddebugger.user
#ml.jobs.cancel
#ml.jobs.create
#ml.jobs.get
#ml.jobs.getIamPolicy
#ml.jobs.list
#ml.jobs.setIamPolicy
#ml.jobs.update
#ml.locations.get
#ml.locations.list
#ml.models.create
#ml.models.delete
#ml.models.get
#ml.models.getIamPolicy
#ml.models.list
#ml.models.predict
#ml.models.setIamPolicy
#ml.models.update
#ml.operations.cancel
#ml.operations.get
#ml.operations.list
#ml.projects.getConfig
#ml.versions.create
#ml.versions.delete
#ml.versions.get
#ml.versions.list
#ml.versions.predict
#ml.versions.update

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
resourcemanager.projects.create,\
resourcemanager.projects.getIamPolicy,\
resourcemanager.projects.setIamPolicy,\
resourcemanager.projects.undelete,\
resourcemanager.projects.update,\
resourcemanager.projects.updateLiens,\
resourcemanager.organizations.get,\
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
storage.objects.update,\
clouddebugger.breakpoints.create,\
clouddebugger.breakpoints.delete,\
clouddebugger.breakpoints.get,\
clouddebugger.breakpoints.list,\
clouddebugger.breakpoints.listActive,\
clouddebugger.breakpoints.update,\
clouddebugger.debuggees.create,\
clouddebugger.debuggees.list"

  gcloud iam roles ${ACTION} $DERBY_DEV_ROLE \
    --organization $(lookup_org_id) \
    --title "Cloud Derby Developer Role" \
    --description "Access to resources needed to develop and deploy Cloud Derby" \
    --stage "GA" \
    --permissions $PERMISSIONS

  sleep 3
}

###############################################################################
# MAIN
###############################################################################
print_header "Creating workshop users, folders, etc..."

setup

create_read_only_group

create_role

create_groups_and_users

create_folders

print_footer "SUCCESS: New workshop configuration created."