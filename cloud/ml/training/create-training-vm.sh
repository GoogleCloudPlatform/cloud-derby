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
# For transferred learning object detection to work we need a GPU enabled VM on GCE.
# This script creates such a VM
###############################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh

#############################################
# Create static external IP for the ML VM
#############################################
create_static_inference_ip() 
{
  if gcloud compute addresses list | grep $ML_IP_NAME; then
    echo_my "Static IP address $ML_IP_NAME found OK"
  else
      if $AUTO_CREATE_IP ; then
          echo "Creating static external IP for ML VM... '$ML_IP_NAME'"
          gcloud compute addresses create $ML_IP_NAME --region $REGION
      else
          echo "Skipping automatic creation of static IP because AUTO_CREATE_IP variable is set to FALSE"
      fi
  fi
}

###############################################
# Copy files to remote GCE host. It will try
# several times if the host is not started yet
# or not responding.
# Input:
#   - Local Dir
#   - Remote Dir
#   - Zone
#   - Destination Host
###############################################
remote_copy()
{
  local LOCAL_DIR=$1
  local REMOTE_DIR=$2
  local ZONE=$3
  local TARGET_HOST=$4
  local SLEEP=1
  local COUNTER=0
  local MAX_WAIT_COUNT=30

  echo_my "Copying files from local path '$LOCAL_DIR' to remote path '$REMOTE_DIR' in zone '$ZONE' to the host '$TARGET_HOST'..."
  while true
  do
      if gcloud compute scp --zone $ZONE $LOCAL_DIR/* $TARGET_HOST:${REMOTE_DIR} ; then
          echo_my "File copy from '$LOCAL_DIR' succeeded."
          break
      else
          SLEEP=$(echo "$SLEEP * 2" | bc)
          echo_my "Remote VM hasn't started yet, waiting for $SLEEP more seconds..."
          sleep $SLEEP
          ((COUNTER+=1))
      fi

      if [ $COUNTER -gt $MAX_WAIT_COUNT ]; then
          echo_my "Remote VM was not started in reasonable amount of time. Aborting the script." $ECHO_ERROR
          exit 1
      fi
  done
}

###############################################
# Open proper ports on a firewall
###############################################
configure_firewall()
{
  # Only configure firewall if we are in automatic "fast path" mode - aka users are not creating these things by hand
  if $AUTO_CREATE_FIREWALL ; then
      open_http_firewall_port $HTTP_PORT
  else
      echo "Skipping automatic creation of firewall because AUTO_CREATE_FIREWALL variable is set to FALSE"
  fi

  # Deep Learning VM has pre-installed Python Lab on port 8080
  open_http_firewall_port 8080
  
  # Open Tensorboard port
  open_http_firewall_port $TF_HTTP_PORT

  open_ssh_firewall_port
}

###############################################
# Open HTTP port on a firewall
# Input:
#   1 - HTTP port to open
###############################################
open_http_firewall_port()
{
  local PORT=$1
  if gcloud compute firewall-rules list --format='table(NAME,NETWORK,DIRECTION,PRIORITY,ALLOW,DENY)' | grep "allow-http-$PORT"; then
      echo_my "Firewall rule 'allow-http-$PORT' found OK"
  else
      echo_my "Create firewall rule for port '$PORT'..."
      gcloud compute --project="$PROJECT" firewall-rules create \
          allow-http-$PORT --direction=INGRESS --priority=1000 \
          --network=default --action=ALLOW --rules=tcp:$PORT \
          --source-ranges=0.0.0.0/0 --target-tags=${HTTP_TAG} | true # Ignore if the firewall rule already exists
  fi
}

###############################################
# Open SSH port on a firewall
###############################################
open_ssh_firewall_port()
{
  if gcloud compute firewall-rules list --format='table(NAME,NETWORK,DIRECTION,PRIORITY,ALLOW,DENY)' | grep "allow-${SSH_TAG}"; then
      echo_my "Firewall rule for SSH was found"
  else
      echo_my "Create firewall rule for '$SSH_TAG'..."
      gcloud compute --project="$PROJECT" firewall-rules create \
          allow-${SSH_TAG} --direction=INGRESS --priority=1000 \
          --network=default --action=ALLOW --rules=tcp:22 \
          --source-ranges=0.0.0.0/0 --target-tags=${SSH_TAG} | true # Ignore if the firewall rule already exists
  fi
}

###############################################
# Create a VM on GCE with a certain number of GPUs
# Inputs:
#   1 - name of the VM
#   2 - number of GPUs
###############################################
create_gpu_vm()
{
  local VM_NAME=$1
  local GPU_COUNT=$2
  echo_my "Create VM instance '$VM_NAME' with '$GPU_COUNT' GPUs in a project '$PROJECT'..."
  # See docs: https://cloud.google.com/deep-learning-vm/docs/quickstart-cli
  #  https://cloud.google.com/deep-learning-vm/docs/tensorflow_start_instance
  gcloud compute --project="$PROJECT" instances create $VM_NAME \
      --zone $ZONE \
      --image-family=tf-latest-gpu \
      --image-project=deeplearning-platform-release \
      --boot-disk-size=70GB \
      --boot-disk-type=pd-ssd \
      --machine-type n1-highmem-2 \
      --accelerator="type=nvidia-tesla-v100,count=$GPU_COUNT" \
      --service-account $ALLMIGHTY_SERVICE_ACCOUNT \
      --maintenance-policy TERMINATE \
      --restart-on-failure \
      --subnet default \
      --address $ML_IP_NAME \
      --tags $HTTP_TAG,$SSH_TAG \
      --metadata="install-nvidia-driver=True" \
      --scopes=default,storage-rw,https://www.googleapis.com/auth/source.read_only

  echo_my "List of my instances..."
  gcloud compute --project="$PROJECT" instances list

  # echo_my "Copy basic project files to the VM so it is easier to clone the repo later..."
  # local LOCAL_DIR=$TMP/host-files
  # rm -rf $LOCAL_DIR | true # ignore if it does not exist
  # mkdir -p $LOCAL_DIR

  # Dynamicaly generate correct scripts so we can copy those scripts to the remote VM
  # echo "source setenv-local.sh" > $LOCAL_DIR/clone-repo.sh

  # Note that we want $PROJECT_PATH to be written as such and not substituted with a real value, hence the escape character \ before $
  # echo "git clone $GITHUB_REPO_URL \$PROJECT_PATH" >> $LOCAL_DIR/clone-repo.sh

  # cp $HOME/setenv-local.sh $LOCAL_DIR
  # chmod u+x $LOCAL_DIR/*.sh
  # REMOTE_DIR="~/"
  # remote_copy $LOCAL_DIR $REMOTE_DIR $ZONE $VM_NAME
}

#############################################
# MAIN
#############################################
print_header "Create new Object Detection Training VM"

configure_firewall

create_static_inference_ip

GPU_COUNT=1
create_gpu_vm $ML_VM $GPU_COUNT

print_footer "ML training VM Creation has completed."