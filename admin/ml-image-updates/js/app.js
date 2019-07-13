/**
 * Copyright 2018, Google, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';
console.log(`***Image processing is starting up***`);

// Imports
const process = require('process'); // Required for mocking environment variables
const request = require('request');

const Storage = require('@google-cloud/storage');
const storage = new Storage(process.env.PROJECT);

const VisionResponse = require('../../../cloud/controller/js/vision-response');
const BoundingBox = require('../../../cloud/controller/js/bounding-box');

// Constants
const APP_URL = `http://${process.env.INFERENCE_IP}`;
const HTTP_PORT = process.env.HTTP_PORT;
const INFERENCE_URL = process.env.INFERENCE_URL;
const OBJECT_INFERENCE_API_URL = APP_URL + ':' + HTTP_PORT + INFERENCE_URL;
// User credentials to authenticate to remote Inference VM service
const INFERENCE_USER_NAME = process.env.INFERENCE_USER_NAME;
const INFERENCE_PASSWORD = process.env.INFERENCE_PASSWORD;
const ALL_OBJECT_LABELS = process.env.ALL_OBJECT_LABELS.split(" ");
const DESTINATION_BUCKET = process.env.DESTINATION_BUCKET;

// Global counter of processed files
let successCount = 0;

/************************************************************
 Scan all files in the bucket
 Great examples of API use can be found here:
 https://github.com/googleapis/nodejs-storage/blob/99e3b17f0b12ea66ed46060ca291124b10772111/samples/files.js#L26
 ************************************************************/

/************************************************************
 Process one file
 Input:
 - Source Bucket
 - Source File
 Output:
 - None
 ************************************************************/
async function processOneFileAsync(srcBucket, srcFile) {
  let visionResponse = await recognizeObjectsAsync('gs://' + srcBucket + '/' + srcFile);
  // console.log('processOneFileAsync(): vision response: ' + JSON.stringify(visionResponse));
  
  for (let label of ALL_OBJECT_LABELS) {
    let prefix = findObject(label, visionResponse);
    await gcsCopy(srcBucket, srcFile, DESTINATION_BUCKET, prefix + srcFile);
  }
  
  // After all labels have been processed, we delete the file from the source bucket
  gcsDelete(srcBucket, srcFile)
  .catch(function (error) {
    console.error("!!!!!!!!!!!!! Error deleting file: " + error);
  });
  // console.log('Finished processing file ' + srcFile);
}

/************************************************************
 Copy file from one bucket into another
 Input:
 - source GCS URI
 - destination GCS URI
 ************************************************************/
async function gcsCopy(srcBucket, srcFile, destBucket, destFile) {
  console.log('Copy from <gs://' + srcBucket + '/' + srcFile + '> to <gs://' + destBucket + '/' + destFile + '>');
  await storage.bucket(srcBucket).file(srcFile).copy(storage.bucket(destBucket).file(destFile))
  .catch(function (error) {
    console.error('!!!!!!!!!!!!! ERROR: Failed to copy a file: ' + destFile + ' with error: ' + error);
  });
}

/************************************************************
 Delete file from the bucket
 Input:
 - source GCS URI
 ************************************************************/
async function gcsDelete(bucket, file) {
  // console.log('Deleting file: '+file);
  storage.bucket(bucket).file(file).delete()
  .catch(function (error) {
    console.error("!!!!!!!!!!!! Failed to delete a file: " + error);
  });
}

/************************************************************
 Find the right object based on objectType input in the image
 Input:
 - object label
 - list of object bounding boxes found by Object Detection
 Output:
 - prefix file path for the future file in the format:
 "<Label_name>/<#objects>_<high_score>_<low_score>_file_"
 or for cases when object is not found:
 "<Label_name>/not_found/"
 ************************************************************/
function findObject(objectType, visionResponse) {
  let isFound = false;
  let count = 0;
  let highScore = 0.0;
  let lowScore = 1.0;
  for (let i = visionResponse.bBoxes.length; i--;) {
    // Is this the right object type?
    if (visionResponse.bBoxes[i].label.toLocaleLowerCase().indexOf(objectType.toLowerCase()) >= 0) {
      isFound = true;
      count++;
      let score = parseFloat(visionResponse.bBoxes[i].score);
      if (highScore < score) {
        highScore = score;
      }
      if (lowScore > score) {
        lowScore = score;
      }
    }
  }
  
  let response = objectType + '/none/';
  
  if (isFound) {
    response = objectType +
      '/count_' + count +
      '_high_' + highScore.toFixed(4).split('.')[1] +
      '_low_' + lowScore.toFixed(4).split('.')[1] +
      '_file_';
  }
  return response;
}

/************************************************************
 Call Vision API to recognize objects in the file
 Input: full path to GCS object
 Output: VisionResponse object
 ************************************************************/
async function recognizeObjectsAsync(gcsPath) {
  console.log('recognizeObjectsAsync(): ' + gcsPath);
  
  // Call REST API Object Detection
  // this returns a Promise which when resolved returns the VisionResponse object
  return recognizeObjectAPIAsync(gcsPath)
  .then((response) => {
    return Promise.resolve()
    .then(() => {
      return createVisionResponse(response);
    });
  })
  .catch((error) => {
    console.error("!!!!!!!!!!!!!!! Error calling remote Object Detection API: " + error);
    throw error;
  });
}

/************************************************************
 Generate response from the ML Vision
 Input:
 - jsonAPIResponse - response from the Vision API
 Output:
 - VisionResponse - Coordinates of various objects that were recognized
 ************************************************************/
function createVisionResponse(jsonAPIResponse) {
  let response = new VisionResponse();
  const objResponse = JSON.parse(jsonAPIResponse);
  
  for (let key in objResponse) {
    for (let i = 0; i < objResponse[key].length; i++) {
      //console.log("objResponse[key]["+i+"]: "+JSON.stringify(objResponse[key][i]));
      const bBox = new BoundingBox(key, objResponse[key][i]["x"], objResponse[key][i]["y"], objResponse[key][i]["w"], objResponse[key][i]["h"], objResponse[key][i]["score"]);
      response.addBox(bBox);
    }
  }
  return response;
}

/************************************************************
 Generate response from the ML Vision
 Input:
 - sensorMessage - message from the car with sensor data
 Output:
 -
 ************************************************************/
function recognizeObjectAPIAsync(gcsURI) {
  return new Promise(function (resolve, reject) {
    
    if (!gcsURI) {
      reject("!!!!!!!!!! Error: No gcURI found in sensorMessage");
      
    } else if (!gcsURI.startsWith("gs://")) {
      reject("!!!!!!!!!! Error: gcsURI must start with gs://");
      
    } else {
      // Example request for the inference VM:
      // http://xx.xx.xx.xx:8082/v1/objectInference?gcs_uri=gs%3A%2F%2Fcamera-9-roman-test-oct9%2Fimage1.jpg
      const apiUrl = OBJECT_INFERENCE_API_URL + "?gcs_uri=" + encodeURIComponent(gcsURI);
      const auth = {user: INFERENCE_USER_NAME, pass: INFERENCE_PASSWORD};
      
      // Measure the time it takes to call inference API
      const startTime = Date.now();
      
      request({uri: apiUrl, auth: auth}, function (err, response, body) {
        if (err) {
          console.error("!!!!!!!!! ERROR calling remote ML API: " + err + ". Please verify that your Inference VM and the App are up and running and proper HTTP port is open in the firewall.");
          reject(err);
        } else {
          console.log("Vision API call took " + (Date.now() - startTime) + " ms. URI: " + apiUrl);
          if (response.statusCode !== 200) {
            reject("!!!!!!!!!!!! Error: Received  " + response.statusCode + " from API");
          } else {
            resolve(body);
          }
        }
      });
    }
  });
}

/************************************************************
 Recursively process list of files
 Input:
 - List of files to be processed
 Output:
 - None
 ************************************************************/
async function processFilesAsync(files) {
  for (let file of files) {
    console.log('--- #' + successCount + ': ' + file.name);
    if (DEBUG_COUNT > MAX_COUNT) {
      break;
    } else {
      DEBUG_COUNT++;
    }
    
    await processOneFileAsync(process.env.CLOUD_BUCKET, file.name)
    .then(() => {
      console.log('=== done: #' + successCount + ': ' + file.name);
      successCount++;
    })
    .catch(function (error) {
      console.error('!!! Error processing file <' + file.name + '> with the error: ' + error);
    });
  }
}

/************************************************************
 MAIN
 ************************************************************/
console.log("Starting up: Vroom Vroom...");

let DEBUG_COUNT = 0;
const MAX_COUNT = 50000;

let bucket = storage.bucket(process.env.CLOUD_BUCKET);

// bucket.getFiles({}, (err, files) => {console.log(err,files)});
bucket.getFiles({}, (err, files) => {
  if (err) {
    console.error('!!! ERROR listing of files in bucket <: ' + process.env.CLOUD_BUCKET + '>: ' + err);
  } else {
    console.log('Bucket <' + process.env.CLOUD_BUCKET + '> contains <' + files.length + '> files.');
    processFilesAsync(files).then(() => {
      console.log('# of files processed successfully: ' + successCount);
    })
  }
});