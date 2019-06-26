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
 Outline of the object as found by object detection API
 ************************************************************/
module.exports = class BoundingBox {
  constructor(label, x, y, w, h, score) {
    // Label of the object - aka 'red_ball', 'home_base', 'border', 'obstacle', etc.
    this.label = label;
    // x coordinate - lower left (in pixels on the image)
    this.x = x;
    // y coordinate - lower left (in pixels on the image)
    this.y = y;
    // object width in pixels - to the right of the x (in pixels on the image)
    this.w = w;
    // object height in pixels - above of the y (in pixels on the image)
    this.h = h;
    // object detection probability - between 0 and 1
    this.score = score;
  }
  
  // Returns YY coordinate (top border of the object)
  yy() {
    return this.y + this.h;
  }
  
  // Returns XX coordinate (right border of the object)
  xx() {
    return this.x + this.w;
  }
};