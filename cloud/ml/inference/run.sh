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

##################################################
# Run Object Detection based on the model trained earlier by "transferred-learning"
# Based on https://github.com/GoogleCloudPlatform/tensorflow-object-detection-example
#
# This code will run on a special GCE VM $ML_VM
##################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ./setenv.sh
print_header "Starting Object Detection App..."

CWD=$(pwd)
cd $TF_MODEL_DIR/models/research
export PYTHONPATH=$(pwd):$(pwd)/slim:$(pwd)/object_detection
echo_my "PYTHONPATH=$PYTHONPATH"
cd $CWD/python

if [ -f "*.jpg" ] ; then
    # Remove old jpg files
    rm *.jpg
fi

if [ -f "nohup.out" ] ; then
    rm -rf nohup.out
fi

echo_my "Running webapp: Change USERNAME and PASSWORD in decorator.py..."
### -u disables line buffering in python and shows everything in the nohup.out
nohup python -u ./app.py &

echo_my "To watch output of the app log, use command: tail -f python/nohup.out"