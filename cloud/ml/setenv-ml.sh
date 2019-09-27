#!/bin/bash

#############################################################################
# Shared environment variables for Machine Learning Module
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
#

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

### Name of the GCE VM that runs local ML training job and inference
ML_VM=ml-training-inference-$VERSION

### Where to store all training data in flight for ML
export GCS_ML_BUCKET=gs://${PROJECT}-ml-$VERSION

### Where to export the final inference graph for predictions
export ML_EXPORT_BUCKET=gs://${PROJECT}-ml-export-$VERSION
export FROZEN_INFERENCE_GRAPH_GCS=$ML_EXPORT_BUCKET/frozen_inference_graph.pb

### Where to export automatically generated label map - from training into predictions
export LABEL_MAP=cloud_derby_label_map.pbtxt
export LABEL_MAP_GCS=$ML_EXPORT_BUCKET/$LABEL_MAP

### Version of TensorFlow to use
### Also used as parameter for Cloud Machine Learning, see https://cloud.google.com/ml-engine/docs/tensorflow/runtime-version-list
export TF_VERSION=1.10

### Model configuration
# How many objects of the same class to be found in the image - Default is 100
max_detections_per_class=90
# How many total detections per image for all classes - Default is 300
max_total_detections=250
# Filter all objects with the confidence score lower than this
score_threshold=0.0000001
# How many proposals to have after the first stage - Default is 300
first_stage_max_proposals=300

### TF settings
export TF_PATH=~/tensorflow
export TF_MODEL_DIR=$PROJECT_DIR/tensorflow-models
export MODEL_BASE=$TF_MODEL_DIR/models/research
export TMP=$(pwd)/tmp

##################################################
# Setup Python path and check TF version
##################################################
set_python_path() {
  echo_my "set_python_path()..."
  local CWD=$(pwd)
  cd $TF_MODEL_DIR/models/research
  export PYTHONPATH=$(pwd):$(pwd)/slim:$(pwd)/object_detection
  echo_my "PYTHONPATH=$PYTHONPATH"
  cd $CWD
}
