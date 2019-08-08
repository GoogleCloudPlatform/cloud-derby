#!/bin/bash

###############################################################
# Shared environment variables for Transferred Learning module
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
#

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../../../setenv-global.sh
source ../setenv-ml.sh

### Shall we run training locally on this VM or on the Google Cloud ML Engine?
LOCAL_TRAINING=true

### What version of Google CMLE to use for remote training. Local training uses whatever TF you install
CMLE_RUNTIME_VERSION=1.9

### What model to use for training. Model zoo: https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/detection_model_zoo.md
MODEL=faster_rcnn_resnet101_coco_2018_01_28

### Which pre-trained model to use
MODEL_CONFIG=${MODEL}-cloud-derby.config

### Which dataset to use
MODEL_CONFIG_PATH=$(pwd)

export TF_HTTP_PORT=8081