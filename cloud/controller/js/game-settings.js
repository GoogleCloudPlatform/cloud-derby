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
var process = require('process'); // Required for mocking environment variables

/************************************************************
    Settings for the car robot
 ************************************************************/
module.exports = ({
  // How many balls need to be collected to win the game
  BALLS_NEEDED: 3,

  // Diameter of the ball (165.744 mm)
  BALL_SIZE_MM: 60.638,

  // Width of the Home Base sign (letter size is 216mm, but the letter is not printed on 100% of the paper)
  HOME_SIZE_MM: 200,

  // Various labels returned by vision API, such as <color><suffix> - aka "red_ball"
  BALL_LABEL_SUFFIX: "Ball",

  // Various labels returned by vision API, such as <color><suffix> - aka "red_home"
  HOME_LABEL_SUFFIX: "Home",

  // Distance from the camera to the ball in a fully captured position
  MIN_DISTANCE_TO_CAMERA_MM: 21,

  // Max car speed (wheel rotation degrees per second)
  MAX_SPEED: 1000,

  // Here is the camera model used in the car:
  // https://www.amazon.com/gp/product/B00RMV53Z2
  camera: {

    // Horizontal field of view for the camera mounted on the car - degrees out of 360
    H_FIELD_OF_VIEW: 120,

    // Size of the camera sensor is 1/4 inch
    SENSOR_HEIGHT_MM: 6.35,

    // Focal length of the camera - it is adjustable, so we need to calibrate it before using this camera for navigation
    FOCAL_LENGTH_MM: 6.1,

    // Horizontal resolution
    HORIZONTAL_RESOLUTION_PIXELS: process.env.HORIZONTAL_RESOLUTION_PIXELS,
    VERTICAL_RESOLUTION_PIXELS: process.env.VERTICAL_RESOLUTION_PIXELS
  }
});