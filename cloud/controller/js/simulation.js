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
var DriveMessage = require('./drive-message');
var VisionResponse = require('./vision-response');
var BoundingBox = require('./bounding-box');
var Settings = require('./game-settings');

/************************************************************
  Simulation for car commands. Pre-set messages being sent to the car regardless of input
 ************************************************************/
class DriveMessageSimulator {

  constructor() {
    // Are we simulating driving commands or not?
    this.simulate = false;
    // Iteration of the fake driving command
    this.index = 0;

    // These are fake driving commands
    this.COMMANDS = [
      { turn1: 0, setSpeed: 80, driveForward: 100, turn2: 0, driveBackward: 0 },
      { turn1: -90, setSpeed: 80, driveForward: 0, turn2: 180, driveBackward: 0 },
      { turn1: 0, setSpeed: 80, driveForward: 40, turn2: 0, driveBackward: 0 },
      { turn1: 45, setSpeed: 80, driveForward: 0, turn2: -12, driveBackward: 0 },
      { turn1: 0, setSpeed: 80, driveForward: 60, turn2: 0, driveBackward: 0 },
      { turn1: -10, setSpeed: 80, driveForward: 0, turn2: 0, driveBackward: 0 },
      { turn1: 0, setSpeed: 80, driveForward: 80, turn2: 0, driveBackward: 0 },
      { turn1: 25, setSpeed: 80, driveForward: 0, turn2: 0, driveBackward: 0 },
      { turn1: 0, setSpeed: 80, driveForward: 10, turn2: 0, driveBackward: 0 },
      { turn1: -5, setSpeed: 80, driveForward: 0, turn2: 0, driveBackward: 0 }
    ];
  }

  /************************************************************
    Iterate over multiple fake driving commands and add them to the car message
    Input: 
      - none
    Output: 
      - driving command to be sent to the car
   ************************************************************/
  nextDrivingCommand() {
    let command = new DriveMessage();
    let fake = this.COMMANDS[this.index];
    command.makeTurn(fake.turn1);
    command.setSpeed(fake.setSpeed);
    command.driveForward(fake.driveForward);
    command.makeTurn(fake.turn2);
    command.driveBackward(fake.driveBackward);

    this.index++;
    if (this.index >= this.COMMANDS.length) {
      this.index = 0;
    }
    return command;
  }
}

/************************************************************
  Simulation for vision API when Object Detection is turned off
 ************************************************************/
class VisionSimulator {

  constructor() {
    // Are we simulating vision responses or not?
    this.simulate = false;
    // Iteration of the fake vision responses
    this.index = 0;

    // These are fake vision responses
    this.COMMANDS = [
      [new BoundingBox("red_ball", 240, 230, 1, 1, 0.92),
        new BoundingBox("red_ball", 600, 200, 20, 20,0.98),
        new BoundingBox("red_ball", 50, 10, 1, 1,0.88),
        new BoundingBox("green_ball", 50, 70, 100, 200, 0.98),
        new BoundingBox("border", 10, 20, 10, 800, 0.92)
      ],
      [new BoundingBox("blue_ball", 640, 30, 25, 25,0.93)],
      [new BoundingBox("blue_ball", 40, 30, 25, 25, 0.97)],
      [new BoundingBox("blue_ball", 0, 30, 25, 25,0.98)],
      [new BoundingBox("blue_ball", 4, 30, 25, 25,0.96)],
      [new BoundingBox("yellow_ball", 440, 130, 30, 30, 0.92),
        new BoundingBox("green_ball", 50, 70, 100, 100, 0.91)
      ],
      [new BoundingBox("blue_ball", 640, 30, 25, 25, 0.98)],
      [new BoundingBox("yellow_ball", 440, 130, 30, 30, 0.94),
        new BoundingBox("green_ball", 50, 70, 100, 100,0.88)
      ],
      [new BoundingBox("red_ball", 640, 30, 25, 25, 0.92)],
      [new BoundingBox("red_ball", 440, 130, 30, 30, 0.93),
        new BoundingBox("green_ball", 50, 70, 100, 100, 0.94)
      ],
      // Ball occupies entire frame - testing capture method
      [new BoundingBox("red_ball", 0, 0, Settings.camera.HORIZONTAL_RESOLUTION_PIXELS, Settings.camera.VERTICAL_RESOLUTION_PIXELS, 0.92),
        new BoundingBox("blue_ball", 150, 170, 200, 200, 0.95)
      ]
    ];
  }

  /************************************************************
    Iterate over multiple fake driving commands and add them to the car message
    Input: 
      - none
    Output: 
      - vision response (taken from the hard-coded array above)
   ************************************************************/
  nextVisionResponse() {

    let response = new VisionResponse();
    let fake = this.COMMANDS[this.index];
    // Randomly generate fake objects
    for (var i = fake.length; i--;) {
      response.addBox(fake[i]);
    }

    this.index++;
    if (this.index >= this.COMMANDS.length) {
      this.index = 0;
    }
    return response;
  }
}

/**************************************************************************
  Module exports
**************************************************************************/
module.exports.DriveMessageSimulator = DriveMessageSimulator;
module.exports.VisionSimulator = VisionSimulator;
