/**
 * Copyright 2018, Google, Inc.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
'use strict';

const process = require('process'); // Required for mocking environment variables
var SensorMessage = require('../../../cloud/controller/js/sensor-message'); // Library for messages and sensors

const SIMULATION_IMG_FOLDER = process.env.TEST_IMAGE_FOLDER; // Location of test images
const BUCKET = process.env.CAR_CAMERA_BUCKET; // Bucket where images will be uploaded to
const TOPIC = process.env.SENSOR_TOPIC; // Where to post messages
const ITERATIONS = process.env.NUM_ITERATIONS; // How many messages to send
const THINK_TIME = process.env.DELAY; // How long to wait between sending simulated messages to the topic
const TEST_IMAGE_FILE = process.env.TEST_IMAGE_FILE; // If this is specified, it will be the only file to be tested
const CAR_ID = process.env.CAR_ID;

// Simulated messages content
let data = [
  { "car": CAR_ID, "laser": 90, "balls": 0, "battery": 99, "color": "Blue" },
  { "car": CAR_ID, "laser": 80, "balls": 0, "battery": 90, "color": "Blue" },
  { "car": CAR_ID, "laser": 70, "balls": 0, "battery": 85, "color": "Blue" },
  { "car": CAR_ID, "laser": 60, "balls": 1, "battery": 80, "color": "Blue" },
  { "car": CAR_ID, "laser": 50, "balls": 1, "battery": 75, "color": "Blue" },
  { "car": CAR_ID, "laser": 40, "balls": 1, "battery": 70, "color": "Blue" },
  { "car": CAR_ID, "laser": 30, "balls": 2, "battery": 65, "color": "Blue" },
  { "car": CAR_ID, "laser": 20, "balls": 2, "battery": 60, "color": "Blue" },
  { "car": CAR_ID, "laser": 11, "balls": 2, "battery": 55, "color": "Blue" },
  { "car": CAR_ID, "laser": 10, "balls": 3, "battery": 50, "color": "Blue" },
];

log(`START: Simulating car sensors... SIMULATION_IMG_FOLDER=${SIMULATION_IMG_FOLDER}, BUCKET=${BUCKET}, THINK_TIME=${THINK_TIME}, TOPIC=${TOPIC}`);

// Pubsub client
const PubSub = require('@google-cloud/pubsub');
const pubsub = PubSub();
const sensorTopic = pubsub.topic(TOPIC);

// GCS client
const Storage = require('@google-cloud/storage');
const storage = new Storage();

// Internal statistics variables
let messagesSent = 0;
let totalErrors = 0;
let iteration = 0;

/**************************************************************************
  Upload an image to GCS, for details see: 
  https://github.com/googleapis/nodejs-storage/blob/master/samples/files.js
 **************************************************************************/
function uploadImage(image) {
  let imagePath = `${SIMULATION_IMG_FOLDER}/${image}`;
  log(`uploadImage(): Uploading ${imagePath}...`);
  storage
    .bucket(BUCKET)
    .upload(imagePath)
    .then(() => {
      log(`${imagePath} uploaded to ${BUCKET}.`);
    })
    .catch(err => {
      console.error('ERROR:', err);
      process.exit(1);
    });

  return `gs://${BUCKET}/${image}`;
}

/**************************************************************************
  Single iteration of simulator
 **************************************************************************/
function sendOneMessage() {
  let i = iteration;
  if (i >= data.length) {
    i = i % data.length;
  }
  log(`Iteration: ${iteration}, index: ${i}`);
  iteration++;

  let image;
  log("TEST_IMAGE_FILE='" + TEST_IMAGE_FILE+"'");
  if (TEST_IMAGE_FILE.length == 0) {
    log("Using images from the subfolder...");
    image = `image${i+1}.jpg`;
  }
  else {
    log("Using image " + TEST_IMAGE_FILE);
    image = TEST_IMAGE_FILE;
  }

  let imageGcsPath = uploadImage(`${image}`);
  // Make HTTP URL from the GCS one
  let imageUrl = "https://storage.googleapis.com/" + imageGcsPath.substr(5,imageGcsPath.length);
  
  // Make sure there is type checking and consistency if sensor message constructor is changed
  let message = JSON.stringify(
    new SensorMessage(data[i].car, data[i].balls, false, data[i].battery, data[i].laser, imageUrl, imageGcsPath, data[i].color));
    
  // Using timeout to make sure all GCS upload processes have completed before we send the message
  const sleepTimeMs = 1000;
  setTimeout(function sendMessage() {
    if (message.length > 0) {
      sensorTopic.publish(message, (err) => {
        if (err) {
          log(err);
          totalErrors++;
          return;
        }
        messagesSent++;
        log(`Message #${messagesSent} sent to PubSub: <${message}>`);
      });
    }
    else {
      log('Command is empty - Nothing to send');
    }
  }, sleepTimeMs);

}

/**************************************************************************
 * Log function
 * Returns: nothing
 **************************************************************************/
function log(string) {
  console.log("simulator.js > " + string);
}

/************************************************************
 * MAIN
 ************************************************************/
for (var i = 0; i < ITERATIONS; i++) {
  setTimeout(function() {
    sendOneMessage();
  }, i * THINK_TIME * 1000);
}

log("Sensor simulation finished.");
