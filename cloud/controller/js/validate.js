/**
 * Copyright 2018, Google, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.  * You may obtain a copy of the License at
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
const MANUAL_MODE = require('./drive-message').MANUAL_MODE;
const AUTOMATIC_MODE = require('./drive-message').AUTOMATIC_MODE;
const DEBUG_MODE = require('./drive-message').DEBUG_MODE;

/************************************************************
 immutable constant options
 ************************************************************/
const BALL_COLORS = ["red", "blue", "green", "yellow"];
const DRIVING_MODES = [AUTOMATIC_MODE, MANUAL_MODE, DEBUG_MODE];
const CONFIG_PARAMS = ["ballColor", "currentDrivingMode", "listenerStatus"];
// map the client params to field names for now
const DRIVING_MESSAGE_PARAMS = {
  "turnSpeed": "turn_speed_field",
  "angle": "angle_field",
  "driveSpeed": "drive_speed_field",
  "distance": "distance_field",
  "gripperOpen": "gripper_open",
  "gripperClosed": "gripper_closed",
  "ondemandMessages": "ondemand_messages",
  "nonstopMessages": "nonstop_messages"
};
const DEBUG_MESSAGE_PARAMS = {
  "sendCommand": "send_command", "nextSensorMessage": "next_sensor_message"
};

/************************************************************
 Validate the configuration parameters based of required
 Inputs:
 - request, response, next
 Returns:
 - response or next
 ************************************************************/
module.exports.configParams = function (req, res, next) {
  var errors = [];
  
  // validParams validation
  var valid = false;
  var validParams = CONFIG_PARAMS;
  for (var i = 0; i < validParams.length; i++) {
    if (typeof req.body[validParams[i]] != 'undefined') {
      valid = true;
      break;
    }
  }
  if (!valid) {
    errors.push(`Valid request param required: [${validParams}]`);
  }
  if (errors.length > 0) {
    return res.status(400).json({
      success: false, errors: errors, status: 400
    })
  }
  
  // ballColor validation
  if (typeof req.body.ballColor != 'undefined' && BALL_COLORS.indexOf(req.body.ballColor) == -1) {
    errors.push("Valid ballColor required");
  }
  
  // currentDrivingMode validation
  if (typeof req.body.currentDrivingMode != 'undefined' && DRIVING_MODES.indexOf(req.body.currentDrivingMode) == -1) {
    errors.push("Valid currentDrivingMode required");
  }
  
  if (errors.length > 0) {
    return res.status(400).json({
      success: false, errors: errors, status: 400
    })
  }
  return next();
};

/************************************************************
 Validate the driving Message parameters
 Inputs:
 - request, response, next
 Returns:
 - response or next
 ************************************************************/
module.exports.drivingMessageParams = function (req, res, next) {
  var errors = [];
  
  // validParams validation. We need the keys here
  var valid = false;
  var validParams = Object.keys(DRIVING_MESSAGE_PARAMS);
  for (var i = 0; i < validParams.length; i++) {
    if (typeof req.body[validParams[i]] != 'undefined') {
      valid = true;
      break;
    }
  }
  if (!valid) {
    errors.push(`Valid request param required: [${validParams}]`);
  }
  if (errors.length > 0) {
    return res.status(400).json({
      success: false, errors: errors, status: 400
    })
  }
  
  // range checks
  var rangeParams = ["turnSpeed", "drivingSpeed"];
  for (var i = 0; i < rangeParams.length; i++) {
    var paramName = rangeParams[i];
    if (typeof req.body[paramName] != 'undefined' && !(req.body[paramName] >= 1 && req.body[paramName] <= 1000)) {
      errors.push(`Valid ${paramName} required: number [1-1000]`);
    }
  }
  
  // number checks
  var numberParams = ["angle", "distance"];
  for (var i = 0; i < numberParams.length; i++) {
    var paramName = numberParams[i];
    if (typeof req.body[paramName] != 'undefined' && isNaN(req.body[paramName])) {
      errors.push(`Valid ${paramName} required: number`);
    }
  }
  
  // boolean param checks
  var booleanParams = ["gripperOpen", "gripperClosed", "ondemandMessages", "nonstopMessages"];
  for (var i = 0; i < booleanParams.length; i++) {
    var paramName = booleanParams[i];
    if (typeof req.body[paramName] != 'undefined' && !(req.body[paramName] === true || req.body[paramName] == false)) {
      errors.push(`Valid ${paramName} required: boolean`);
    }
  }
  
  if (errors.length > 0) {
    return res.status(400).json({
      success: false, errors: errors, status: 400
    })
  }
  return next();
};

/************************************************************
 Validate the debug Message parameters
 Inputs:
 - request, response, next
 Returns:
 - response or next
 ************************************************************/
module.exports.debugMessageParams = function (req, res, next) {
  var errors = [];
  
  // validParams validation. We need the keys here
  var valid = false;
  var validParams = Object.keys(DEBUG_MESSAGE_PARAMS);
  for (var i = 0; i < validParams.length; i++) {
    if (typeof req.body[validParams[i]] != 'undefined') {
      valid = true;
      break;
    }
  }
  if (!valid) {
    errors.push(`Valid request param required: [${validParams}]`);
  }
  if (errors.length > 0) {
    return res.status(400).json({
      success: false, errors: errors, status: 400
    })
  }
  
  // boolean param checks
  var booleanParams = ["sendCommand", "nextSensorMessage"];
  for (var i = 0; i < booleanParams.length; i++) {
    var paramName = booleanParams[i];
    if (typeof req.body[paramName] != 'undefined' && !(req.body[paramName] === true || req.body[paramName] == false)) {
      errors.push(`Valid ${paramName} required: boolean`);
    }
  }
  
  if (errors.length > 0) {
    return res.status(400).json({
      success: false, errors: errors, status: 400
    })
  }
  return next();
};

/**************************************************************************
 Module exports
 **************************************************************************/
module.exports.DRIVING_MESSAGE_PARAMS = DRIVING_MESSAGE_PARAMS;
module.exports.BALL_COLORS = BALL_COLORS;
module.exports.DRIVING_MODES = DRIVING_MODES;