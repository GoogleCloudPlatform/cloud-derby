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

##################################################################################
# Environment settings that are to be kept secret and not exposed to the GitHub repo
# This file needs to be put into the user $HOME directory.
##################################################################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

echo "setenv-private.sh: start..."

### Billing accound ID used to pay for project resources
export BILLING_ACCOUNT_ID="<set your Billing ID here>"

### This is the project that hosts the Git Repo with source code and other admin elements
export ADMIN_PROJECT_ID="<set your Admin Project ID here>"

echo "setenv-private.sh: done"
