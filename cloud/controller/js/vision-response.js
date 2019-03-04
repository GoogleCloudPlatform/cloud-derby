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

/************************************************************
  This object is the response from the Vision.class and
  contains resulting data from Object Detection API
 ************************************************************/
module.exports = class VisionResponse {

  constructor() {
    // List of bounding boxes for objects found by Object Detection
    this.bBoxes = [];
  }

  addBox(boundingBox) {
    this.bBoxes.push(boundingBox);
  }
};
