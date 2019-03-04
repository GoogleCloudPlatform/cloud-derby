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
# Car driving receiver simulator
###############################################

set -u # This prevents running the script if any of the variables have not been set
set -e # Exit if error is detected during pipeline execution

source ../../setenv-global.sh

print_header "Driver simulator"

TEST_COMMAND_SUBSCRIPTION=simulator_driving_command_subscription
echo "Listen for messages from the driving controller..."

if gcloud pubsub subscriptions list | grep $TEST_COMMAND_SUBSCRIPTION; then
	echo_my "Subscription '$TEST_COMMAND_SUBSCRIPTION' already exists for topic '$COMMAND_TOPIC'..."
else
	echo_my "Creating a subscription '$TEST_COMMAND_SUBSCRIPTION' to topic '$COMMAND_TOPIC'..."
	gcloud pubsub subscriptions create $TEST_COMMAND_SUBSCRIPTION --topic $COMMAND_TOPIC | true
fi

MAX_MSGS=20

RESULT="blah"
while [ "$RESULT" != "" ]; do 
	RESULT="$( gcloud beta pubsub subscriptions pull --auto-ack --limit=10 $TEST_COMMAND_SUBSCRIPTION )"
	echo "$RESULT"
done

# In some cases you may need to drop the subscription and re-create it
# gcloud pubsub subscriptions delete $TEST_COMMAND_SUBSCRIPTION

print_footer "Driver simulator completed - no more messages from the Driving Controller in the Subscription."
