#!/bin/bash

###########################################################
# Configure inference VM to start python inference app n restart
###########################################################

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

source ./setenv.sh

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

gcloud compute instances add-metadata ${ML_VM} --metadata-from-file startup-script=vm-startup-script.sh