// Copyright 2017, Google, Inc.
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

'use strict';
// import our local settings and define constants
// change the below topic to the pubsub topic used for your car messages
let COMMAND_TOPIC = '<CAR_MESSAGE_TOPIC>';

//import * as Tools from "../../../js/tools";

let PubSub = require('@google-cloud/pubsub');
const pubsub = PubSub();
const command_topic = pubsub.topic(COMMAND_TOPIC);
const timeout = 3000;


// Command indicates that car has ball in sight and moving towards it
const GO2BALL = "go2ball";
// Command indicates that Base is in sight and car is moving towards it
const GO2BASE = "go2base";
// Command indicates that there is no ball of needed color in sight and car is looking for it by turning
const SEEK_BALL_TURN = "seekBallTurn";
// Command indicates that there is no ball of needed color in sight and car is looking for it by moving
const SEEK_BALL_MOVE = "seekBallMove";
// Command indicates that there is no ball of needed color in sight and car is looking for it
const CAPTURE_BALL = "captureBall";
// Command indicates that the car will be operated manually from the cloud user and all incoming sensor messages will be ignored
// If this is not present in the command, this means car is in self-driving mode
const MANUAL_MODE = "manualMode";
// Command indicates that the car is controlled by debugger
const AUTOMATIC_MODE = "automatic";
// Allowed values of the GOAL variable
const GOALS = [GO2BALL, GO2BASE, SEEK_BALL_TURN, SEEK_BALL_MOVE, CAPTURE_BALL, MANUAL_MODE];


exports.dialogflowFirebaseFulfillment = (req, res) => {
    // Get the direction and distance from the request
    let number = req.body.queryResult.parameters['number']; // distance to move
    let direction = req.body.queryResult.parameters['direction']; // direction to move (currently only front/back)
    let unitlength = req.body.queryResult.parameters['unit-length'];
    let color = req.body.queryResult.parameters['color'];
    let vision = req.body.queryResult.parameters['Vision'];
    
    console.log('Distance: ' + number);
    console.log('Direction: ' + direction);
    console.log('Unit Length: ' + unitlength);
    console.log('Vision: ' + vision);
    console.log('Color: ' + color);

    if (vision) {
        callVision(vision).then((output) => {
        res.json({ 'fulfillmentText': output }); // Return the results of the robot command
    }).catch(() => {
        res.json({ 'fulfillmentText': `I don't know about robots but they sound neat!` });
    });
    
    }
    
    if (direction || color) {
    // Send robot command to pubsub
    callRobotController(number, direction, unitlength, color).then((output) => {
        res.json({ 'fulfillmentText': output }); // Return the results of the robot command
    }).catch(() => {
        res.json({ 'fulfillmentText': `I don't know about robots but they sound neat!` });
    });
    }
};

function callVision (vision) {
    return new Promise((resolve, reject) => {
        let newestMessage;
        let subscriptionName;
        let read_subscription;
        subscriptionName = `projects/talk-to-your-robot/subscriptions/${vision}`;
        read_subscription = pubsub.subscription(subscriptionName);
        console.log(`subscription: ${subscriptionName}`);

        console.log("callVision(): vision");
        global.messages = [];
        console.log('Getting new messages');
        function messageHandler(message){
            global.messages.push(message);
            
        }
                    // Listen for new messages until timeout is hit
        read_subscription.on('message', messageHandler);
        setTimeout(() => {
            read_subscription.removeListener('message', messageHandler);
            console.log(global.messages.length);
            var newestTime = 0;
            for (var i = 0; i < global.messages.length; i++) { 
                console.log(global.messages[i]);
                var message = global.messages[i].data;
                var currentTime=message.timestamp;
                console.log(currentTime);
                console.log(newestTime);
                    if (currentTime>newestTime){
                        newestMessage = message.text;
                        newestTime=currentTime;
                        console.log(newestMessage);
                    }
                // "Ack" (acknowledge receipt of) the message
                global.messages[i].ack();
            }
            console.log(newestTime);
            console.log(newestMessage);
            resolve(newestMessage);
        }, timeout);
        
    })
}

function callRobotController (number, direction, unitlength, color) {

    /************************************************************
     Send manual driving command to the car
     ************************************************************/
    return new Promise((resolve, reject) => {
        drivingMessage.resetMessage();
        console.log("callRobotController(): number=" + number);
        console.log("callRobotController(): direction" + direction);
        let output = "";
        let mm = "";
        let inches = "";
        if (unitlength.unit == 'mm'){
            mm = unitlength.amount;
        } else if (unitlength.unit == 'ft') {
            inches = unitlength.amount * 12;
            mm = inches * 25.4;
        } else if (unitlength.unit == 'inch') {
            mm = unitlength.amount * 25.4;
        }

        drivingMessage.setOnDemandSensorRate();
        drivingMessage.setModeManual();

        console.log("callRobotController(): color= " + color);
        if (color){
            console.log("changing color to : " + color);
            drivingMessage.setColor(color);
            output = `Seeking the ${color} ball as you commanded.`;
        }

        if (direction) {
            console.log("direction if statement");
            switch (direction) {
                case 'rest':
                    console.log("napping!");
                    drivingMessage.setOnDemandSensorRate();
                    output = `Nap time already?`;
                    break;
                case 'dance':
                    console.log("Dancing!");
                    drivingMessage.setContinuousSensorRate();
                    drivingMessage.setSpeed(1000);
                    drivingMessage.turnRight(270);
                    drivingMessage.turnLeft(360);
                    drivingMessage.setModeManual();
                    drivingMessage.setSpeed(1000);
                    drivingMessage.gripperOpen();
                    drivingMessage.driveBackward(100);
                    drivingMessage.gripperClose();
                    drivingMessage.driveForward(100);
                    drivingMessage.gripperOpen();
                    drivingMessage.turnRight(20);
                    drivingMessage.turnLeft(45);
                    drivingMessage.turnRight(360);
                    output = `Yippee!`;
                    break;
                case 'forward':
                    console.log("Driving forward: " + mm);
                    drivingMessage.driveForward(mm);
                    output = `Marching ${direction} ${unitlength.amount} ${unitlength.unit}`;
                    break;
                case 'reverse':
                    console.log("Reversing: " + unitlength.amount + " " + unitlength.unit);
                    drivingMessage.driveBackward(-Math.abs(mm));
                    output = `Beep beep beep. Reversing ${unitlength.amount} ${unitlength.unit}`;
                    break;
                case 'right':
                    console.log("Turning Right: " + number);
                    drivingMessage.turnRight(number);
                    output = `Changing heading ${number} degrees to the ${direction}`;
                    break;
                case 'left':
                    console.log("Turning Left: " + number);
                    let rightoption = 360 - number;
                    drivingMessage.turnLeft(-Math.abs(number));
                    output = `You know you could have just turned right ${rightoption} instead and had a lot more fun!`;
                    break;
                case 'open':
                    console.log("Opening the gripper");
                    drivingMessage.gripperOpen();
                    output = `Opening the claw!`;
                    break;
                case 'close':
                    console.log("Closing the gripper");
                    drivingMessage.gripperClose();
                    output = `Pinch warning! Closing the gripper.`;
                    break;
                case 'photo':
                    console.log("taking a photo");
                    drivingMessage.setContinuousSensorRate();
                    drivingMessage.sendSensorMessage();
                    output = `smile for the camera`;
                    break;
                default:
                    console.log('Sorry, I did not understand the command - number: ' + number + 'direction: ' + direction + 'unitlength: ' + unitlength);
            }
        }

        publishCommand(drivingMessage);

        // Resolve the promise with the output text
        console.log(output);
        resolve(output);
    })
}

/************************************************************
 Send prepared command message to the car via PubSub.
 Input:
 - Command object
 Output:
 - none, but the result of the function is that single PubSub message is sent
 ************************************************************/
function publishCommand(command) {
    let txtMessage = JSON.stringify(command);
    txtMessage = txtMessage.replace(/\\/g, "");
    console.log("pubsub message: " + txtMessage);
    // Only send a message when it is not empty
    if (txtMessage.length > 0) {
        command_topic.publish(txtMessage, (err) => {
            if (err) {
                console.log(err);
                return;
            }
            console.log("publishCommand(): message # " + txtMessage);
        });
    }
    else {
        console.log("publishCommand(): Command is empty - Nothing to send");
    }
}

let drivingMessage;
drivingMessage = {

    resetMessage() {
        // Timestamp is generated at the time of creation of the message, not at the time of sending it
        this.cloudTimestampMs = new Date().getTime();
        // Timestamp of the original message from the car as correlation ID
        // Car needs to validate this field against the latest info that it sent to the cloud
        this.carTimestampMs = undefined;
        // Purpose of the command
        this.goal = undefined;
        // Array of commands to execute - could be a long list, in which case car will have to execute
        // those in sequence. The list can be arbitrarily long
        this.actions = [];
    },
    // This takes positive or negative angle and converts it into a proper command
    makeTurn(degrees) {
        if (degrees > 0) {
            this.turnRight(degrees);
        }
        else {
            this.turnLeft(degrees);
        }
    },
    // Takes four basic colors of balls as input
    setColor(color) {
        if (color == "Blue" || color == "Red" || color == "Green" || color == "Yellow") {
            this.actions.push({ "setColor": color });
        }
    },

    turnLeft(degrees) {
        if (degrees < 0) {
            this.actions.push({"turnLeft": degrees});
        }
    },

    turnRight(degrees) {
        if (degrees > 0) {
            this.actions.push({"turnRight": degrees});
        }
    },

    // This takes positive or negative value and converts it into a proper command
    // If speed is not explicitely set in the command, then drive at max speed
    drive(mm) {
        if (mm > 0) {
            this.driveForward(mm);
        }
        else {
            this.driveBackward(mm);
        }
    },

    driveForward(mm) {
        if (mm > 0) {
            this.actions.push({"driveForwardMm": mm});
        }
    },

    driveBackward(mm) {
        if (mm < 0) {
            this.actions.push({"driveBackwardMm": mm});
        }
    },

    takePhoto() {
        this.actions.push({"takePhoto": true});
    },

    // Speed must be more than 0, otherwise this command will be ignored
    setSpeed(speedMmSec) {
        if (speedMmSec > 0) {
            this.actions.push({"setSpeedMmSec": speedMmSec});
        }
    },

    gripperOpen() {
        this.actions.push({ "gripperPosition": "open" });
    },

    gripperClose() {
        this.actions.push({ "gripperPosition": "close" });
    },

    sendSensorMessage() {
        this.actions.push({ "sendSensorMessage": "true" });
    },

    setOnDemandSensorRate() {
        this.sensorRate = "onDemand";
    },

    setContinuousSensorRate() {
        this.sensorRate = "continuous";
    },

    setCorrelationID(timestampMs) {
        this.carTimestampMs = timestampMs;
    },
    setModeAutomatic() {
        this.mode = AUTOMATIC_MODE;
    },
    setModeManual() {
        this.mode = MANUAL_MODE;
    }
};