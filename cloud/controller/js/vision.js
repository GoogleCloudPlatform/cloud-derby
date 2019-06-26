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
const request = require('request');

// User credentials to authenticate to remote Inference VM service
const INFERENCE_USER_NAME = process.env.INFERENCE_USER_NAME;
const INFERENCE_PASSWORD = process.env.INFERENCE_PASSWORD;

const APP_URL = `http://${process.env.INFERENCE_IP}`;
const HTTP_PORT = process.env.HTTP_PORT;
const INFERENCE_URL = process.env.INFERENCE_URL;
const OBJECT_INFERENCE_API_URL = APP_URL + ':' + HTTP_PORT + INFERENCE_URL;

require('dotenv').config();
const VisionResponse = require('./vision-response');
const BoundingBox = require('./bounding-box');

// Initialize simulation engine (it may be On or Off)
const VisionSimulator = require('./simulation').VisionSimulator;
let visionSimulator = new VisionSimulator();

/**************************************************************************
 Vision class calls Object Detection API to figure out where are all the
 balls in the image so navigation logic can use it for driving decisions
 **************************************************************************/
module.exports = class Vision {
  
  constructor() {
    // Whatever needs to be done here...
  }
  
  /************************************************************
   Send image to ML and parse it
   Input:
   - sensorMessage - includes GCS URL to the Image (gs://...)
   Output:
   - VisionResponse - Coordinates of various objects that were recognized
   ************************************************************/
  recognizeObjects(sensorMessage) {
    console.log("vision.recognizeObjects(): start...");
    
    // Are we in a simulation mode? If so, return hard coded responses
    if (visionSimulator.simulate) {
      return Promise.resolve()
      .then(() => {
        console.log("vision.recognizeObjects(): returning a simulated response");
        return visionSimulator.nextVisionResponse();
      });
    }
    
    // Call REST API - Object Detection - ML Engine or TensorFlow
    // this returns a Promise which when resolved returns the VisionResponse object
    return this.recognizeObjectAPIAsync(sensorMessage)
    .then((response) => {
      return Promise.resolve()
      .then(() => {
        return this.createVisionResponse(response);
      });
    })
    .catch((error) => {
      console.log("vision.recognizeObjects(): Error calling remote Object Detection API: " + error);
      // In case of an error, return empty response
      return new VisionResponse();
    });
  }
  
  /************************************************************
   Generate response from the ML Vision
   Input:
   - jsonAPIResponse - response from the Vision API
   Output:
   - VisionResponse - Coordinates of various objects that were recognized
   ************************************************************/
  createVisionResponse(jsonAPIResponse) {
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
  recognizeObjectAPIAsync(sensorMessage) {
    return new Promise(function (resolve, reject) {
      const gcsURI = sensorMessage.sensors.frontCameraImagePathGCS;
  
      if (!gcsURI) {
        reject("Error: No gcURI found in sensorMessage");
        
      } else if (!gcsURI.startsWith("gs://")) {
        reject("Error: gcsURI must start with gs://");
        
      } else {
        // Example request for the inference VM: http://xx.xx.xx.xx:8082/v1/objectInference?gcs_uri=gs%3A%2F%2Fcamera-9-roman-test-oct9%2Fimage1.jpg
        const apiUrl = OBJECT_INFERENCE_API_URL + "?gcs_uri=" + encodeURIComponent(gcsURI);
        console.log("Vision API URL: " + apiUrl);
        // var visionResponse = new VisionResponse();
        const auth = {user: INFERENCE_USER_NAME, pass: INFERENCE_PASSWORD};
        
        // Measure the time it takes to call inference API
        const startTime = Date.now();
  
        request({uri: apiUrl, auth: auth}, function (err, response, body) {
          if (err) {
            console.log("!!! ERROR !!! calling remote ML API: " + err + ". Please verify that your Inference VM and the App are up and running and proper HTTP port is open in the firewall.");
            reject(err);
          } else {
            console.log("Vision API call took " + (Date.now() - startTime) + " ms. Result: " + body);
            if (response.statusCode != 200) {
              reject("Error: Received  " + response.statusCode + " from API");
              
            } else {
              resolve(body);
            }
          }
        });
      }
    });
  }
};