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
const DriveMessage = require('./drive-message').DriveMessage;

/************************************************************
 Display Manual Driving form on Get
 Input:
 - inboundMsgHistory
 ************************************************************/
module.exports.manualDrivingForm = function (inboundMsgHistory) {
  let imageUrl;
  
  if (inboundMsgHistory.length > 0) {
    let msg = inboundMsgHistory[inboundMsgHistory.length - 1];
    if ((!(msg.data === undefined)) && (!(JSON.parse(msg.data).sensors === undefined)) && (!(JSON.parse(msg.data).sensors.frontCameraImagePath === undefined))) {
      imageUrl = JSON.parse(msg.data).sensors.frontCameraImagePath;
    }
  }
  
  let form = `<a href="/">Home</a> / <a href="/manual_mode">Refresh page</a>
    <h1>Manual car control</h1>
    <form action="/manual_control_action" method="post">
    <label for="turn_speed">Turn speed: </label>
    <input id="turn_speed" type="number" name="turn_speed_field">(wheel angle/sec) - from 1 to 1000
    <br>
    <label for="Turn angle">Turn: </label>
    <input id="Turn angle" type="number" name="angle_field">(degrees) - positive for right, negative for left
    <br>
    <label for="drive_speed">Driving speed: </label>
    <input id="drive_speed" type="number" name="drive_speed_field">(wheel angle/sec) - from 1 to 1000
    <br>
    <label for="distance_drive">Drive distance: </label>
    <input id="distance" type="number" name="distance_field">(mm) - positive for forward, negative for backward
    <br>
    <label for="gripper_open">Open gripper: </label>
    <input id="gripper_open" type="checkbox" name="gripper_open">
    <br>
    <label for="gripper_close">Close gripper: </label>
    <input id="gripper_close" type="checkbox" name="gripper_close">
    <br>
    <label for="photo">Send sensor messages when asked: </label>
    <input id="photo" type="checkbox" name="ondemand_messages">
    <br>
    <label for="msgs">Send sensor messages non-stop: </label>
    <input id="msgs" type="checkbox" name="nonstop_messages">
    <br><br>
    <input type="submit" value="Send control message to the car">
</form>`;
  
  // Add an image to the form
  if (!(imageUrl === undefined)) {
    form = form + '<img src="' + imageUrl + '" alt="picture of the ball" style="width:600px;"/>';
  }
  
  return form;
};

/************************************************************
 Send manual driving command to the car
 ************************************************************/
module.exports.manualCommand = function (req) {
  let command = new DriveMessage();
  
  command.setModeManual();
  
  if (req.body.turn_speed_field) {
    command.setSpeed(req.body.turn_speed_field);
  }
  
  if (req.body.angle_field) {
    command.makeTurn(req.body.angle_field);
  }
  
  if (req.body.drive_speed_field) {
    command.setSpeed(req.body.drive_speed_field);
  }
  
  if (req.body.distance_field) {
    command.drive(req.body.distance_field);
  }
  
  if (req.body.ondemand_messages) {
    command.setOnDemandSensorRate();
    command.takePhoto();
  }
  
  if (req.body.gripper_open) {
    command.gripperOpen();
  }
  
  if (req.body.gripper_close) {
    command.gripperClose();
  }
  
  if (req.body.nonstop_messages) {
    command.setContinuousSensorRate();
    command.takePhoto();
  }
  
  command.sendSensorMessage();
  
  return command;
};