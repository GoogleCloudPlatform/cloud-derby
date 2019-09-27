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
const VERSION = 1.01;
const APP = 'DRIVING-CONTROL-APP';
const express = require('express');
const cors = require('cors');
const PubSub = require('@google-cloud/pubsub');

console.log(`***${APP} is starting up***`);

let process = require('process'); // Required for mocking environment variables
let bodyParser = require('body-parser');
let path = require('path');
let Navigation = require('./navigation');
let manualDrivingForm = require('./manual-driving').manualDrivingForm;
let manualCommand = require('./manual-driving').manualCommand;
let DriveMessage = require('./drive-message').DriveMessage;

const MANUAL_MODE = require('./drive-message').MANUAL_MODE;
const AUTOMATIC_MODE = require('./drive-message').AUTOMATIC_MODE;
const DEBUG_MODE = require('./drive-message').DEBUG_MODE;

// Import the validation functions for the API
const validate = require('./validate');
const DRIVING_MESSAGE_PARAMS = require('./validate').DRIVING_MESSAGE_PARAMS;
const BALL_COLORS = require('./validate').BALL_COLORS;
const DRIVING_MODES = require('./validate').DRIVING_MODES;

// Configure external URL for help output
// const APP_URL = `https://${process.env.GOOGLE_CLOUD_PROJECT}.appspot.com/`;

// By default, the client will authenticate using the service account file
// specified by the GOOGLE_APPLICATION_CREDENTIALS environment variable and use
// the project specified by the GCLOUD_PROJECT environment variable. See
// https://googlecloudplatform.github.io/gcloud-node/#/docs/google-cloud/latest/guides/authentication
// These environment variables are set automatically on Google App Engine

// Instantiate a pubsub client
const pubsub = PubSub();
// References an existing subscription
const command_topic = pubsub.topic(process.env.COMMAND_TOPIC);
const sensorSubscription = pubsub.subscription(process.env.SENSOR_SUBSCRIPTION);
const carId = process.env.CAR_ID;
// Any sensor message with the time stamp older than this will be discarded as useless
const MAX_MSG_AGE_SEC = 60;

// Instantiate Express runtime
const app = express();
app.set('view engine', 'pug');
app.set('views', path.join(__dirname, 'views'));

// Support parsing of application/json type post data
app.use(bodyParser.json());

// Support parsing of application/x-www-form-urlencoded post data
app.use(bodyParser.urlencoded({extended: true}));
require('@google-cloud/debug-agent').start({allowExpressions: true});

// Color of the ball that this car controller will be after. It can be changed via control panel at run time
let ballColor = "unknown";

/************************************************************
 Keeping track of stats
 ************************************************************/
let totalMessagesReceived = 0;
let rejectedOutOfOrderMessages = 0;
let rejectedFormatMessages = 0;
let totalMessagesSent = 0;
// Tracking errors of any kind
let totalErrors = 0;
// Is inbound listener Up or Down now?
let listenerStatus = false;
// Value of the message with the maximum time stamp seen so far
let maxMsgTimeStampMs = 0;
// History of received messages
let inboundMsgHistory = [];
// Maximum size of received Msg history as # of messages stored - one msg per second for full hour
const MAX_INBOUND_HISTORY = 60 * 60;
// History of sent command messages
let outboundMsgHistory = [];
// Maximum size of sent command history as # of messages stored
const MAX_OUTBOUND_HISTORY = 60 * 60;
// Here we will keep the next driving command to be send to the car in debug mode
let nextDrivingCommand;
// Current driving mode of the car
let currentDrivingMode = MANUAL_MODE;
// Initialize Navigation logic
let navigation = new Navigation(outboundMsgHistory);

/************************************************************
 Error handler for PubSub inbound
 ************************************************************/
const errorHandler = function (error) {
  totalErrors++;
  console.error(`ERROR: ${error}`);
};

/************************************************************
 Event handler to handle inbound PubSub messages
 ************************************************************/
const inboundMessageHandler = function (message) {
  // "Ack" (acknowledge receipt of) the message
  message.ack();
  totalMessagesReceived++;
  console.log("inboundMessageHandler(carId=" + carId + "): <<<--------------- Received " + totalMessagesReceived + " messages");
  
  let data = JSON.parse(message.data);
  // Ignore invalid messages
  if (!isMessageValid(data)) {
    totalErrors++;
    console.error("ERROR: inboundMessageHandler(): Skipping this message since it did not pass validity check");
    return;
  }
  
  // Save valid message in history in memory
  saveInboundMessage(message);
  
  // Do not process inbound messages in manual driving mode
  if (currentDrivingMode == MANUAL_MODE) {
    return;
  }
  
  // Call navigation logic based on the sensor data and send new command to the car
  navigation.nextMove(data)
  .then((response) => {
    if (!(currentDrivingMode == DEBUG_MODE)) {
      publishCommand(response);
    } else {
      nextDrivingCommand = response;
    }
  });
};

/************************************************************
 Send prepared command message to the car via PubSub.
 Input:
 - Command object
 Output:
 - none, but the result of the function is that single PubSub message is sent
 ************************************************************/
function publishCommand(command) {
  if (command === undefined) {
    console.log("publishCommand(): Command is not defined - ignoring");
    return;
  }
  let txtMessage = JSON.stringify(command);
  // Only send a message when it is not empty
  if (txtMessage.length > 0) {
    command_topic.publish(txtMessage, (err) => {
      if (err) {
        console.log(err);
        totalErrors++;
        return;
      }
      totalMessagesSent++;
      console.log("publishCommand(carId=" + carId + "): --------------->>> Message #" + totalMessagesSent + " " + txtMessage);
      saveOutboundMessage(command);
    });
  } else {
    console.log("publishCommand(): Command is empty - Nothing to send");
  }
}

/************************************************************
 Validate the message from the car based on certain criteria. Example input message:
 {"carId":1,"msgId":8,"version":"1.0","timestampMs":1519509836918,"carState":{"ballsCollected":2,"batteryLeft":55,"sensors":{"frontLaserDistanceMm":11,"frontCameraImagePath":"gs://robot-derby-camera-1/images/image8.jpg"}}
 ************************************************************/
function isMessageValid(msg) {
  console.log("isMessageValid():" + JSON.stringify(msg));
  
  // Get the color of the ball from the car message
  ballColor = msg.carState.color;
  
  // Does this message carry timestamp field with it?
  if (!msg.timestampMs) {
    console.error("ERROR: isMessageValid(): msg.timestampMs is undefined");
    rejectedFormatMessages++;
    return false;
  }
  
  // Reject message if it has older timestamp than we have seen earlier
  if (maxMsgTimeStampMs > msg.timestampMs) {
    console.error("ERROR: isMessageValid(): msg.timestampMs is older than we have already seen by " + (maxMsgTimeStampMs - msg.timestampMs) + " ms");
    rejectedOutOfOrderMessages++;
    return false;
  }
  // Now we know this new message is more recent than anything we have seen so far
  maxMsgTimeStampMs = msg.timestampMs;
  
  // Reject very old messages
  let oldestAllowedMs = new Date().getTime() - MAX_MSG_AGE_SEC * 1000;
  if (msg.timestampMs < oldestAllowedMs) {
    console.error("ERROR: isMessageValid(): msg.timestampMs is older than max allowed age of " + MAX_MSG_AGE_SEC + "(sec) the message by " + (oldestAllowedMs - msg.timestampMs) + " ms");
    rejectedOutOfOrderMessages++;
    return false;
  }
  
  // Message has been successfully validated
  return true;
}

/************************************************************
 Save history of inbound messages
 ************************************************************/
function saveInboundMessage(message) {
  // Check for max size of history
  if (inboundMsgHistory.length >= MAX_INBOUND_HISTORY) {
    // Truncate 10% of the oldest history log
    inboundMsgHistory.splice(0, inboundMsgHistory.length / 10);
  }
  // Add message to history
  inboundMsgHistory.push(message);
}

/************************************************************
 Save history of outbound messages
 ************************************************************/
function saveOutboundMessage(message) {
  // Check for max size of history
  if (outboundMsgHistory.length >= MAX_OUTBOUND_HISTORY) {
    // Truncate 10% of the oldest history log to avoid memory overflow
    outboundMsgHistory.splice(0, outboundMsgHistory.length / 10);
  }
  // Add message to history
  outboundMsgHistory.push(message);
}

/************************************************************
 Read sensor data from the car - used by the worker to listen to pubsub messages.
 When more than one worker is running they will all share the same
 subscription, which means that pub/sub will evenly distribute messages to each worker.
 ************************************************************/
function startListener() {
  if (listenerStatus) {
    console.log("Listener is already running, nothing to do.");
    return;
  }
  // Listen for new messages
  sensorSubscription.on(`message`, inboundMessageHandler);
  sensorSubscription.on(`error`, errorHandler);
  listenerStatus = true;
  console.log("startListener(): started OK and ready");
}

/************************************************************
 Setup environment before we run the server and reset all counters to 0
 ************************************************************/
function reset() {
  totalMessagesReceived = 0;
  rejectedOutOfOrderMessages = 0;
  rejectedFormatMessages = 0;
  totalMessagesSent = 0;
  totalErrors = 0;
  nextDrivingCommand = undefined;
  inboundMsgHistory = [];
  outboundMsgHistory = [];
  // Will ignore any messages up until now
  maxMsgTimeStampMs = new Date().getTime();
}

/************************************************************
 Change color form
 ************************************************************/
function changeColorForm() {
  return `<a href="/">Home</a>
    <h1>Change target ball color</h1>
    <form action="/color_change_submit" method="post">
    <br>
    <label for="ball_color">New ball color for car to search:</label><br>
    <input type="radio" name="ball_color" value="Red"> Red<br>
    <input type="radio" name="ball_color" value="Blue"> Blue<br>
    <input type="radio" name="ball_color" value="Green"> Green<br>
    <input type="radio" name="ball_color" value="Yellow"> Yellow<br><br>
    <input type="submit" name="change_color" value="Submit"></form>`;
}

/************************************************************
 Debugger form
 ************************************************************/
function debugDrivingForm() {
  console.log("debugDrivingForm()...");
  let drivingCommandString;
  let mostRecentCarMessage;
  let imageUrl;
  
  if (nextDrivingCommand === undefined) {
    drivingCommandString = "nextDrivingCommand is undefined. No driving command to be sent to the car";
  } else {
    drivingCommandString = JSON.stringify(nextDrivingCommand);
  }
  
  if (inboundMsgHistory.length == 0) {
    mostRecentCarMessage = "No messages have been received from the car";
  } else {
    let msg = inboundMsgHistory[inboundMsgHistory.length - 1];
    mostRecentCarMessage = JSON.stringify(msg);
    
    if ((!(msg.data === undefined)) && (!(JSON.parse(msg.data).sensors === undefined)) && (!(JSON.parse(msg.data).sensors.frontCameraImagePath === undefined))) {
      imageUrl = JSON.parse(msg.data).sensors.frontCameraImagePath;
    }
  }
  
  console.log("debugDrivingForm(): drivingCommandString='" + drivingCommandString + "', mostRecentCarMessage='" + mostRecentCarMessage + "'");
  let debug_header = "Debugger is OFF";
  if (currentDrivingMode == DEBUG_MODE) {
    debug_header = "Debugger is ON";
  }
  
  let form = `<a href="/">Home</a>
    <form action="/debug_submit" method="post">
    <h1>${debug_header}</h1>
    <b>Sensor message:</b><br>${mostRecentCarMessage}<br><br>
    <b>Driving message:</b><br>${drivingCommandString}<br><br>
    <input type="submit" name="send_command" value="Send driving message to the car"><br><br>
    <input type="submit" name="next_sensor_message" value="Ask car to send new sensor message"><br><br>
    <input type="submit" name="refresh" value="Refresh page"></form>`;
  
  // Add an image to the form
  if (!(imageUrl === undefined)) {
    form = form + '<img src="' + imageUrl + '" alt="picture of the ball" style="width:700px;"/>';
  }
  
  return form;
}

/************************************************************
 API Endpoints
 ************************************************************/
const router = express.Router();              // get an instance of the express Router

// CORS will be controlled by the API GW layer
router.all('*', cors());

// All of the API routes will be prefixed with /api
app.use('/api', router);

// test route to make sure everything is working (accessed at GET http://localhost:8080/api)
router.get('/', function (req, res) {
  res.status(200).json({
    success: true, status: 200, message: 'Welcome to the ' + APP + ' API!'
  });
});

/************************************************************
 GET /stats
 Description: Retrieve all relevant device/car statistic variable values.
 ************************************************************/
router.get('/stats', (req, res) => {
  res.status(200).json({
    success: true, status: 200, data: {
      "totalErrors": totalErrors,
      "totalMessagesSent": totalMessagesSent,
      "totalMessagesReceived": totalMessagesReceived,
      "rejectedFormatMessages": rejectedFormatMessages,
      "rejectedOutOfOrderMessages": rejectedOutOfOrderMessages
    }
  })
});

/************************************************************
 GET /config/options
 Description: Retrieve available device/car configuration parameter options.
 This can be cached so not sending via the OPTIONS method.
 ************************************************************/
router.get('/config/options', (req, res) => {
  res.status(200).json({
    success: true, status: 200, data: {
      "ballColors": BALL_COLORS, "drivingModes": DRIVING_MODES
    }
  })
});

/************************************************************
 GET /config
 Description: Update the configuration of a device with specific configuration option(s)
 ************************************************************/
router.get('/config', (req, res) => {
  res.status(200).json({
    success: true, status: 200, data: {
      "ballColor": ballColor,
      "currentDrivingMode": currentDrivingMode,
      "listenerStatus": listenerStatus,
      "commandTopic": process.env.COMMAND_TOPIC || '',
      "sensorSubscription": process.env.SENSOR_SUBSCRIPTION || '',
      "carId": carId || ''
    }
  })
});

/************************************************************
 PUT /config
 Description: Retrieve the current device/car ID configuration variables.
 This includes both client and system defined; read write and read only variables.
 ************************************************************/
router.put('/config', validate.configParams, (req, res) => {
  // ballColor
  if (req.body.ballColor) {
    ballColor = req.body.ballColor;
    let command = new DriveMessage();
    command.setColor(ballColor);
    publishCommand(command);
  }
  
  // currentDrivingMode
  if (req.body.currentDrivingMode) {
    currentDrivingMode = req.body.currentDrivingMode;
    startListener();
    let command = new DriveMessage();
    if (currentDrivingMode == DEBUG_MODE) {
      command.setModeDebug();
    } else if (currentDrivingMode == MANUAL_MODE) {
      command.setModeManual();
    } else if (currentDrivingMode == AUTOMATIC_MODE) {
      command.setModeAutomatic();
      // We want to do all the driving with a closed gripper to prevent
      // random balls from getting into the grip
      command.gripperClose();
      command.sendSensorMessage();
    }
    command.setOnDemandSensorRate();
    publishCommand(command);
  }
  
  res.status(200).json({
    success: true, status: 200
  })
});

/************************************************************
 GET /messages
 Description: Retrieve inbound and outbound messages for the device/car.
 ************************************************************/
router.get('/messages', (req, res) => {
  res.status(200).json({
    success: true, status: 200, data: {
      "inboundMsgHistory": inboundMsgHistory, "outboundMsgHistory": outboundMsgHistory
    }
  })
});

/************************************************************
 POST /messages/driving
 Description: Create a new Manual driving message.
 ************************************************************/
router.post('/messages/driving', validate.drivingMessageParams, (req, res) => {
  // need to map the API request params to the manualCommand params
  let paramNames = Object.keys(DRIVING_MESSAGE_PARAMS);
  for (let i = 0; i < paramNames.length; i++) {
    let paramName = paramNames[i];
    req.body[DRIVING_MESSAGE_PARAMS[paramName]] = req.body[paramName];
  }
  publishCommand(manualCommand(req));
  
  res.status(201).json({
    success: true, status: 201
  })
});

/************************************************************
 POST /messages/debug
 Description: Create a new Debug message
 ************************************************************/
router.post('/messages/debug', validate.debugMessageParams, (req, res) => {
  let command;
  //
  // nextSensorMessage
  if (req.body.nextSensorMessage) {
    command = new DriveMessage();
    command.setModeDebug();
    command.sendSensorMessage();
    publishCommand(command);
  }
  
  // sendCommand
  if (req.body.sendCommand) {
    // Before we send the current message to the car, we need to make sure we add one action - that is to send sensor
    // message after processing other actions
    if (nextDrivingCommand === undefined) {
      // If there were no instructions to begin with, then we will create an empty command
      command = new DriveMessage();
    } else {
      command = nextDrivingCommand;
    }
    // Reset nextDrivingCommand to zero so it is not shown in the UI, unless we process another message
    nextDrivingCommand = undefined;
    command.setModeDebug();
    // Tell the car to send sensor message after acting on other actions
    command.setOnDemandSensorRate();
    // Push this command to the car
    publishCommand(command);
  }
  
  res.status(201).json({
    success: true, status: 201
  })
});

/************************************************************
 Changing the color of the ball
 ************************************************************/
app.post('/color_change_submit', (req, res) => {
  console.log(`***${APP}.GET.color_change_submit***`);
  
  if (req.body.ball_color) {
    ballColor = req.body.ball_color;
    let command;
    command = new DriveMessage();
    command.setColor(ballColor);
    publishCommand(command);
  }
  
  res.redirect('/');
});

/************************************************************
 Show history of inbound messages
 ************************************************************/
app.get('/inbound_history', (req, res) => {
  let status_message = '<a href="/">Home</a><p><h1>Inbound Message History</h1>' + '<p># of messages in history: <b>' + inboundMsgHistory.length + '</b></p>' + '<p>' + JSON.stringify(inboundMsgHistory) + '</b></p>';
  console.log(`***${APP}.GET.inbound_history***`);
  res.status(200).send(status_message);
});

/************************************************************
 Show history of outbound messages
 ************************************************************/
app.get('/outbound_history', (req, res) => {
  let status_message = '<a href="/">Home</a><p><h1>Outbound Message History</h1>' + '<p># of messages in history: <b>' + outboundMsgHistory.length + '</b></p>' + '<p>' + JSON.stringify(outboundMsgHistory) + '</b></p>';
  console.log(`***${APP}.GET.outbound_history***`);
  res.status(200).send(status_message);
});

/************************************************************
 Changing the color of the ball to chase
 ************************************************************/
app.get('/change_color', (req, res) => {
  console.log(`***${APP}.GET.change_color***`);
  
  let formPage = changeColorForm();
  res.status(200).send(formPage);
});

/************************************************************
 Debug mode - human control over sending driving commands to the car
 ************************************************************/
app.get('/debugger', (req, res) => {
  console.log(`***${APP}.GET.debugger***`);
  let formPage = debugDrivingForm();
  res.status(200).send(formPage);
});

/************************************************************
 Debug step - send message to the car
 ************************************************************/
app.post('/debug_submit', (req, res) => {
  console.log(`***${APP}.GET.debug_submit***`);
  let command;
  
  if (!(req.body.refresh === undefined)) {
    console.log('debug_submit(): User wants to ignore the current command and wait for the next message from the car');
    res.redirect('/debugger');
    return;
  }
  
  if (!(req.body.next_sensor_message === undefined)) {
    console.log('debug_submit(): User wants to ask for a new sensor message');
    command = new DriveMessage();
    command.setModeDebug();
    command.sendSensorMessage();
    publishCommand(command);
    res.redirect('/debugger');
    return;
  }
  
  console.log('debug_submit(): User wants to send current command to the car');
  
  // Before we send the current message to the car, we need to make sure we add one action - that is to send sensor
  // message after processing other actions
  if (nextDrivingCommand === undefined) {
    // If there were no instructions to begin with, then we will create an empty command
    command = new DriveMessage();
  } else {
    command = nextDrivingCommand;
  }
  // Reset nextDrivingCommand to zero so it is not shown in the UI, unless we process another message
  nextDrivingCommand = undefined;
  command.setModeDebug();
  // Tell the car to send sensor message after acting on other actions
  command.setOnDemandSensorRate();
  // Push this command to the car
  publishCommand(command);
  // Now we send user back to the human control page so he can repeat
  res.redirect('/debugger');
});

/************************************************************
 Turn ON DEBUG mode
 ************************************************************/
app.get('/debugger_on', (req, res) => {
  console.log(`***${APP}.GET.debugger_on***`);
  startListener();
  currentDrivingMode = DEBUG_MODE;
  let command = new DriveMessage();
  command.setModeDebug();
  command.setOnDemandSensorRate();
  publishCommand(command);
  res.status(200).redirect('/debugger');
});

/************************************************************
 Turn ON Self Driving mode
 ************************************************************/
app.get('/self_driving_mode', (req, res) => {
  console.log(`***${APP}.GET.self_driving_mode***`);
  startListener();
  currentDrivingMode = AUTOMATIC_MODE;
  let command = new DriveMessage();
  command.setModeAutomatic();
  command.setOnDemandSensorRate();
  // We want to do all the driving with a closed gripper to prevent random balls from getting into the grip
  command.gripperClose();
  command.sendSensorMessage();
  publishCommand(command);
  res.status(200).send('<a href="/">Home</a><p>Self driving mode is turned ON.');
});

/************************************************************
 Reset all statistics
 ************************************************************/
app.get('/reset', (req, res) => {
  console.log(`***${APP}.GET.reset***`);
  reset();
  res.status(200).send('<a href="/">Home</a></p>Statistics reset complete.');
});

/************************************************************
 Turn ON Manual driving mode
 ************************************************************/
app.get('/manual_mode', (req, res) => {
  console.log(`***${APP}.GET.manual_mode***`);
  currentDrivingMode = MANUAL_MODE;
  let formPage = manualDrivingForm(inboundMsgHistory);
  res.status(200).send(formPage);
});

/************************************************************
 Manual car control (as submitted from manual_control.html)
 ************************************************************/
app.post('/manual_control_action', (req, res) => {
  console.log(`***${APP}.GET.manual_control_action***`);
  publishCommand(manualCommand(req));
  // Now we send user back to the manual control page so he can repeat
  res.redirect('/manual_mode');
});

/************************************************************
 Start listener
 ************************************************************/
app.get('/start', (req, res) => {
  reset();
  startListener();
  console.log(`***${APP}.GET.start_listener***`);
  res.status(200).send('<a href="/">Home</a><p>Listener has been (re)started');
});

/************************************************************
 Stop listener
 ************************************************************/
app.get('/stop', (req, res) => {
  res.status(200).send('<a href="/">Home</a><p>Listener has been stopped');
});

/************************************************************
 Show stats HTML page
 ************************************************************/
app.get('/', (req, res) => {
  console.log(`***${APP}.GET.main_page***`);
  let html = "<h1>Cloud Derby Driving Controller</h1>" + "<p>Current driving mode: <b>" + currentDrivingMode + "</b></p>" + "<p>Set driving mode to: <a href='/self_driving_mode'>Self driving</a> / <a href='/manual_mode'>Manual</a> / <a href='/debugger_on'>Debug</a></p>" + "<p>Car color (<a href='/change_color'>change it</a>): <b>" + ballColor + "</b></p>" + "<p>Message history: <a href='/inbound_history'>Inbound sensor data</a> / <a href='/outbound_history'>Outbound driving commands</a></p>" + "<p>Errors: <b>" + totalErrors + "</b></p>" + "<p>Messages received: <b>" + totalMessagesReceived + "</b></p>" + "<p>Messages sent: <b>" + totalMessagesSent + "</b></p>" + "<p>Rejected out of order or old messages: <b>" + rejectedOutOfOrderMessages + "</b></p>" + "<p>Rejected format messages: <b>" + rejectedFormatMessages + "</b></p>" + "<p>Most recent message: <b>" + new Date(maxMsgTimeStampMs).toUTCString() + "</b></p>" + "<p>Listener status <a href='/start'>Start</a>/<a href='/stop'>Stop</a>: <b>" + listenerStatus + "</b></p>" + "<p>Statistics: <a href='/reset'>Reset</a></p>" + "<p>Command topic: <b>" + process.env.COMMAND_TOPIC + "</b></p>" + "<p>Sensor subscription: <b>" + process.env.SENSOR_SUBSCRIPTION + "</b></p>";
  
  let imageUrl;
  if (inboundMsgHistory.length > 0) {
    let msg = inboundMsgHistory[inboundMsgHistory.length - 1];
    if ((!(msg.data === undefined)) && (!(JSON.parse(msg.data).sensors === undefined)) && (!(JSON.parse(msg.data).sensors.frontCameraImagePath === undefined))) {
      imageUrl = JSON.parse(msg.data).sensors.frontCameraImagePath;
    }
  }
  
  // Add an image to the form
  if (!(imageUrl === undefined)) {
    html = html + '<img src="' + imageUrl + '" alt="picture of the ball" style="width:600px;"/>';
  }
  
  html = html + '<p style="color:LightGray"><small>Software Version ' + VERSION + '<br>' + new Date().toUTCString() + '</small></p>';
  res.status(200).send(html);
});

/************************************************************
 Start server
 ************************************************************/
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log("Listening on port " + PORT + ". Press Ctrl+C to quit.");
  startListener();
});

module.exports = app;
