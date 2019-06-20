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

// For some reason car gets stuck in limbo when the turn angle is 3 degrees or less
const IGNORE_TURN_DEGREE = 3;

// Command indicates that car has ball in sight and moving towards it
const GO2BALL = "go2ball";

// Command indicates that Base is in sight and car is moving towards it
const GO2BASE = "go2base";

// Command indicates that there is no ball of needed color in sight and car is looking for it by turning
const SEEK_BALL_TURN = "seekBallTurn";

// Command indicates that there is no home base of needed color in sight and car is looking for it by turning
const SEEK_HOME_TURN = "seekHomeTurn";

// Command indicates that there is no ball of needed color in sight and car is looking for it by moving
const SEEK_BALL_MOVE = "seekBallMove";

// Command indicates that ball is within gripping distance - need to grab it now
const CAPTURE_BALL = "captureBall";

// This means the goal of the command is to verify that ball has been gripped
const CHECK_GRIP = "checkGrip";

// This indicated the end of the game when the car finished all tasks
const GAME_END = "missionComplete";

// Command indicates that the car will be operated manually from the cloud user and all incoming sensor messages will be ignored
// If this is not present in the command, this means car is in self-driving mode
const MANUAL_MODE = "manual";

// Command indicates that the car is controlled by debugger
const DEBUG_MODE = "debug";

// Command indicates that the car is controlled by debugger
const AUTOMATIC_MODE = "automatic";

// Tells the car to keep taking pictures and continuously send them to the cloud non-stop
const CONTINUOUS_SENSOR_RATE = "continuous";

// Tells the car to send sensor messages only when asked
const ON_DEMAND_SENSOR_RATE = "onDemand";

/**************************************************************************
 Driving command message sent from cloud to the car. Example of a message:
 { "cloudTimestampMs": 1519592078172,
      "carTimestampMs": 1519592078100,
      "mode": "go2base",
      "actions": [
          { "driveForward": 111 },
          { "turnRight": 22 },
          { "driveBackwardMm": 33 },
          { "speed": 44 },
          { "turnLeft": 55 },
          { "driveForwardMm": 66 },
          ...]
    }
 **************************************************************************/
class DriveMessage {
  
  constructor() {
    // Timestamp is generated at the time of creation of the message, not at the time of sending it
    this.cloudTimestampMs = new Date().getTime();
    // Timestamp of the original message from the car as correlation ID
    // Car needs to validate this field against the latest info that it sent to the cloud
    this.carTimestampMs = undefined;
    // By default the mode is as follows
    this.mode = MANUAL_MODE;
    // How often does the car need to send sensor messages
    this.sensorRate = ON_DEMAND_SENSOR_RATE;
    // Array of commands to execute - could be a long list, in which case car will have to execute
    // those in sequence. The list can be arbitrarily long
    this.actions = [];
  }
  
  // Tells the car that one more ball has been captured
  addBallCount() {
    this.ballCaptured = 1;
  }
  
  // Takes four basic colors of balls as input
  setColor(color) {
    if (color == "Blue" || color == "Red" || color == "Green" || color == "Yellow") {
      this.actions.push({"setColor": color});
    }
  }
  
  // This takes positive or negative angle and converts it into a proper command
  makeTurn(degrees) {
    if (degrees > 0) {
      this.turnRight(degrees);
    } else {
      this.turnLeft(degrees);
    }
  }
  
  // Cap max turn angle to 1000 degrees in any conditions
  turnLeft(degrees) {
    if (degrees < 0 && Math.abs(degrees) > IGNORE_TURN_DEGREE) {
      this.actions.push({"turnLeft": Math.min(degrees, 1000)});
    }
  }
  
  // Cap max turn angle to 1000 degrees in any conditions
  turnRight(degrees) {
    if (degrees > IGNORE_TURN_DEGREE) {
      this.actions.push({"turnRight": Math.min(degrees, 1000)});
    }
  }
  
  // This takes positive or negative value and converts it into a proper command
  // If speed is not explicitly set in the command, then drive at max speed
  drive(mm) {
    if (mm > 0) {
      this.driveForward(mm);
    } else {
      this.driveBackward(mm);
    }
  }
  
  // Cap max driving distance in any conditions to no more than 5 meters
  driveForward(mm) {
    if (mm > 0) {
      this.actions.push({"driveForwardMm": Math.min(mm, 5000)});
    }
  }
  
  // Cap max driving distance in any conditions to no more than 5 meters
  driveBackward(mm) {
    if (mm <= 0) {
      this.actions.push({"driveBackwardMm": Math.min(mm, 5000)});
    }
  }
  
  takePhoto() {
    this.actions.push({"takePhoto": true});
  }
  
  // Speed must be more than 0 and less than 1000 (per GoPiGo docs, otherwise this command will be ignored
  setSpeed(speed) {
    if (speed > 0) {
      this.actions.push({"setSpeed": Math.min(speed, 1000)});
    }
  }
  
  gripperOpen() {
    this.actions.push({"gripperPosition": "open"});
  }
  
  gripperClose() {
    this.actions.push({"gripperPosition": "close"});
  }
  
  sendSensorMessage() {
    this.actions.push({"sendSensorMessage": "true"});
  }
  
  setGoalGo2Ball() {
    this.goal = GO2BALL;
  }
  
  setGoalGo2Base() {
    this.goal = GO2BASE;
  }
  
  setGoalGameEnd() {
    this.goal = GAME_END;
  }
  
  setGoalSeekBallTurn() {
    this.goal = SEEK_BALL_TURN;
  }
  
  setGoalSeekHomeTurn() {
    this.goal = SEEK_HOME_TURN;
  }
  
  setGoalSeekBallMove() {
    this.goal = SEEK_BALL_MOVE;
  }
  
  setGoalCaptureBall() {
    this.goal = CAPTURE_BALL;
  }
  
  setGoalCheck4Grip() {
    this.goal = CHECK_GRIP;
  }
  
  setModeManual() {
    this.mode = MANUAL_MODE;
  }
  
  setModeDebug() {
    this.mode = DEBUG_MODE;
  }
  
  setModeAutomatic() {
    this.mode = AUTOMATIC_MODE;
  }
  
  setOnDemandSensorRate() {
    this.sensorRate = ON_DEMAND_SENSOR_RATE;
  }
  
  setContinuousSensorRate() {
    this.sensorRate = CONTINUOUS_SENSOR_RATE;
  }
  
  setCorrelationID(timestampMs) {
    this.carTimestampMs = timestampMs;
  }
}

/**************************************************************************
 Module exports
 **************************************************************************/
module.exports.DriveMessage = DriveMessage;
module.exports.SEEK_BALL_TURN = SEEK_BALL_TURN;
module.exports.MANUAL_MODE = MANUAL_MODE;
module.exports.DEBUG_MODE = DEBUG_MODE;
module.exports.AUTOMATIC_MODE = AUTOMATIC_MODE;
module.exports.CHECK_GRIP = CHECK_GRIP;
module.exports.GO2BASE = GO2BASE;
module.exports.SEEK_HOME_TURN = SEEK_HOME_TURN;