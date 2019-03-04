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
# Prepare and configure GCE VM for predictions
###############################################
set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

sudo apt-get install bc
source ./setenv.sh

##################################################
# Install required libraries for the web app
##################################################
setup_webapp() {
    echo_my "Setting up web app..."
    sudo pip install Flask==0.12.2 WTForms==2.1 Flask_WTF==0.14.2 Werkzeug==0.12.2 numpy google-cloud-storage 
}

##################################################
# This changes TF inference model to be used for web app
##################################################
set_inference_model() {
    echo_my "Changing inference model..."
    
    # Point to the trained model
    FROM=$CWD/tmp/import
    mkdir -p $FROM

    echo_my "Download label map..."
    gsutil cp $LABEL_MAP_GCS $FROM/$LABEL_MAP
    PATH_TO_LABELS=${MODEL_BASE}/object_detection/data/$LABEL_MAP
    sudo ln -sf $FROM/$LABEL_MAP $PATH_TO_LABELS
    echo_my "Label map is setup at '$PATH_TO_LABELS'"
    
    echo_my "Download frozen inference graph from GCS '$FROZEN_INFERENCE_GRAPH_GCS'..."
    gsutil cp $FROZEN_INFERENCE_GRAPH_GCS $FROM/frozen_inference_graph.pb
    
    local DESTINATION_GRAPH=$PATH_TO_CKPT/frozen_inference_graph.pb
    if ! [ -d $PATH_TO_CKPT ] ; then
        mkdir $PATH_TO_CKPT
    fi
    sudo ln -sf $FROM/frozen_inference_graph.pb $DESTINATION_GRAPH
    echo_my "Frozen inference graph is setup at '$DESTINATION_GRAPH'"
}

###############################################
# MAIN
###############################################
print_header "Setting up Inference VM"
mkdir -p tmp
CWD=$(pwd)
INSTALL_FLAG=$CWD/tmp/install.marker

if [ -f "$INSTALL_FLAG" ]; then
    echo_my "File '$INSTALL_FLAG' was found = > no need to do the install since it already has been done."
else    
    setup_webapp
    touch $INSTALL_FLAG
fi

cd $CWD
set_inference_model

print_footer "Inference VM setup has completed"
