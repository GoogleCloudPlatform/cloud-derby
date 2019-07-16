#!/usr/bin/env python

#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""
This application pulls messages from the Cloud Pub/Sub API.
For more information, see the README.md .
"""

import argparse
import time
import json
import os
import datetime
import picamera
from collections import deque
from google.cloud import pubsub_v1
from google.cloud import storage
import six
import jwt
import ssl
import paho.mqtt.client as mqtt
from curtsies import Input
from robotderbycar import RobotDerbyCar

### for image processing
from PIL import Image

action_queue = deque([])
previous_command_timestamp = 0
# assigned mode from the most recent processed driving command - see drive-message.js for details
mode = "undefined"
sensor_rate = "undefined"
# If this is true, the car will be streaming sensor messages non stop, otherwise it will only send messages when asked to do so
stream_messages = False
print("*****************************************************")
print("*** Starting the car in NO message streaming mode ***")
print("*****************************************************")
# If this is true, then the car needs to send one sensor message to the server
# only used when stream_messages = False
send_next_message = False
obstacle_found = False

# How many balls have been collected so far
balls_collected = 0

def callback(message):
        global previous_command_timestamp
        global action_queue
        global mode
        global sensor_rate
        global stream_messages
        global balls_collected
        envelope = json.loads(message.data.decode('utf-8'))
        output = json.dumps(envelope)

        print("callback()<---------------- received msg: {}".format(output))

        #### process the data
        dict_data = json.loads(envelope)  # convert json to type dict

        if 'cloudTimestampMs' in dict_data and 'actions' in dict_data and 'mode' in dict_data and 'sensorRate' in dict_data:
            mode = dict_data['mode']
            sensor_rate = dict_data['sensorRate']
            print("callback(): command sensorRate: {}".format(sensor_rate))
            print("callback(): command mode: {}".format(mode))

            if sensor_rate == 'onDemand':
                stream_messages = False

            if sensor_rate == 'continuous':
                stream_messages = True

            if 'ballCaptured' in dict_data:
                balls_collected += 1

            ### process only new commads and disgregard old messages
            if dict_data['cloudTimestampMs'] > previous_command_timestamp:
                previous_command_timestamp = dict_data['cloudTimestampMs']

                for i in range(len(dict_data['actions'])):
                    for key in dict_data['actions'][i].keys():
                        new_action = previous_command_timestamp, key, dict_data['actions'][i][key]
                        print("callback(): new_action: {}".format(new_action))
                        action_queue.append(new_action)

            else:
                print('callback(): message received out of order. previous_command_timestamp: {}'.format(previous_command_timestamp) + '. Message ignored')

        else:
            print('callback(): message ignored. Missing necessary tokens: "cloudTimestampMs" or "actions" or "mode" or "sensorRate')

        message.ack()


def takephoto(project_id,bucket_id,cam_pos):
    image_file_name = str(datetime.datetime.now())
    camera = picamera.PiCamera()

    camera.resolution = (int(camera_horizontal_pixels), int(camera_vertical_pixels))

    # box = (0.0, 0.0, 1.0, 1.9)
    # camera.zoom = box
    # camera.iso = 100
    # camera.sharpness = 100

    if cam_pos != "1":
      camera.vflip = True
      camera.hflip = True

    image_file_name = 'image' + image_file_name + '.jpg'
    image_file_name = image_file_name.replace(":", "")  # Strip out the colon from date time.
    image_file_name = image_file_name.replace(" ", "")  # Strip out the space from date time.
    print("takephoto(): image " + image_file_name)
    camera.capture(image_file_name)
    camera.close()  # We need to close off the resources or we'll get an error.

    client = storage.Client(project=project_id)
    mybucket = client.bucket(bucket_id)
    myblob = mybucket.blob(image_file_name)
    print("takephoto(): uploading...")
    start_time = time.time()
    # See docs: http://google-cloud-python.readthedocs.io/en/latest/storage/blobs.html
    myblob.upload_from_filename(image_file_name, content_type='image/jpeg')
    print("takephoto(): completed upload in %s seconds" % (time.time() - start_time))

    # Remove file from local directory to avoid overflow
    os.remove(image_file_name)

    # Process GCS URL
    url = myblob.public_url
    gcs_url = str(myblob.path).replace("/b/","gs://")
    gcs_url = gcs_url.replace("/o/","/")
    if isinstance(url, six.binary_type):
        url = url.decode('utf-8')

    if isinstance(gcs_url, six.binary_type):
        gcs_url = gcs_url.decode('utf-8')

    return gcs_url, url


def verifyEnv(var):
    if var not in os.environ.keys():
        print("The GCP '" + str(var) + "' Environment Variable has not been initialized. Terminating program")
        print("Here are the available Environment Variables: " + os.environ.keys())
        exit()
    else:
        return os.environ[var]


def create_jwt(project_id, private_key_file, algorithm):
    """Create a JWT (https://jwt.io) to establish an MQTT connection."""
    token = {
        'iat': datetime.datetime.utcnow(),
        'exp': datetime.datetime.utcnow() + datetime.timedelta(minutes=60),
        'aud': project_id
    }
    with open(private_key_file, 'r') as f:
        private_key = f.read()
    print('create_jwt(): creating JWT using {} from private key file {}'.format(
        algorithm, private_key_file))
    return jwt.encode(token, private_key, algorithm=algorithm)


def error_str(rc):
    """Convert a Paho error to a human readable string."""
    return '{}: {}'.format(rc, mqtt.error_string(rc))


class Device(object):
    """Represents the state of a single device."""

    def __init__(self):
        self.connected = False

    def wait_for_connection(self, timeout):
        """Wait for the device to become connected."""
        total_time = 0
        while not self.connected and total_time < timeout:
            time.sleep(1)
            total_time += 1

        if not self.connected:
            raise RuntimeError('Could not connect to MQTT bridge.')

    def on_connect(self, unused_client, unused_userdata, unused_flags, rc):
        """Callback for when a device connects."""
        print('on_connect(): connection Result:', error_str(rc))
        self.connected = True

    def on_disconnect(self, unused_client, unused_userdata, rc):
        """Callback for when a device disconnects."""
        print('on_disconnect(): disconnected:', error_str(rc))
        self.connected = False

    def on_publish(self, unused_client, unused_userdata, unused_mid):
        """Callback when the device receives a PUBACK from the MQTT bridge."""
        print('on_publish(): msg sent.')

    def on_subscribe(self, unused_client, unused_userdata, unused_mid,
                     granted_qos):
        """Callback when the device receives a SUBACK from the MQTT bridge."""
        print('on_subscribe(): subscribed: ', granted_qos)
        if granted_qos[0] == 128:
            print('Subscription failed.')

    def on_message(self, unused_client, unused_userdata, message):
        """Callback when the device receives a message on a subscription."""
        payload = message.payload
        print('on_message(): received message \'{}\' on topic \'{}\' with Qos {}'.format(
            payload, message.topic, str(message.qos)))

        # The device will receive its latest config when it subscribes to the
        # config topic. If there is no configuration for the device, the device
        # will receive a config with an empty payload.
        if not payload:
            return

        # The config is passed in the payload of the message. In this example,
        # the server sends a serialized JSON string.
        data = json.loads(payload)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('project', help='Your Google Cloud project ID')
    parser.add_argument('topic', help='Your PubSub topic name')
    parser.add_argument('--non-interactive', action="store_true", dest="nonInteractive", help='non-interactive mode')
    args = parser.parse_args()

    project_var = verifyEnv("PROJECT")
    bucket_var = verifyEnv("CAR_CAMERA_BUCKET")
    region_var = verifyEnv("REGION")
    registry_id = verifyEnv("IOT_CORE_REGISTRY")
    logical_car_id = verifyEnv("CAR_ID")
    ball_color = verifyEnv("CAR_COLOR")
    device_id = verifyEnv("IOT_CORE_DEVICE_ID")
    carId = verifyEnv("CAR_ID")
    sensor_topic = verifyEnv("SENSOR_TOPIC")
    camera_position = verifyEnv("CAR_CAMERA_NORMAL")
    camera_horizontal_pixels = verifyEnv("HORIZONTAL_RESOLUTION_PIXELS")
    camera_vertical_pixels = verifyEnv("VERTICAL_RESOLUTION_PIXELS")
    dist_limit = verifyEnv("BARRIER_DAMPENING")
    counter = 1

    print("Project ID: " + project_var)
    print("Car ID: " + logical_car_id)
    print("Ball color: " + ball_color)
    print("Bucket: " + bucket_var)
    print("Image vertical resolution: " + camera_vertical_pixels)
    print("Image horizontal resolution: " + camera_horizontal_pixels)

    # Initialize Cloud Derby Car System and Sensors
    print("Initializing Cloud Derby Car...")
    myCar = RobotDerbyCar()
    print("Car Initialized.")

    # Create the MQTT client and connect to Cloud IoT.
    client = mqtt.Client(client_id=(
        'projects/{}/locations/{}/registries/{}/devices/{}'.format(project_var, region_var, registry_id, device_id)))

    # With Google Cloud IoT Core, the username field is ignored, and the
    # password field is used to transmit a JWT to authorize the device.
    client.username_pw_set(username='unused', password=create_jwt(project_var, "../rsa_private.pem", "RS256"))

    # Enable SSL/TLS support.
    client.tls_set(ca_certs="../roots.pem", tls_version=ssl.PROTOCOL_TLSv1_2)

    device = Device()

    client.on_connect = device.on_connect
    client.on_publish = device.on_publish
    client.on_disconnect = device.on_disconnect
    client.on_subscribe = device.on_subscribe
    client.on_message = device.on_message

    # Connect to the Google MQTT bridge.
    client.connect("mqtt.googleapis.com", int(443))

    client.loop_start()

    mqtt_telemetry_topic = '/devices/{}/events/{}'.format(device_id,sensor_topic)

    # Wait up to 5 seconds for the device to connect.
    device.wait_for_connection(5)

    # Subscribe to the command topic.
    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(args.project, args.topic)
    flow_control = pubsub_v1.types.FlowControl(max_messages=1)
    subscription = subscriber.subscribe(subscription_path, callback=callback, flow_control=flow_control)

    startup_time = int(time.time() * 1000)

    # Flag that indicates we are processing a series of actions recieved from the cloud - will not be sending any messages until all actions are executed
    action_sequence_complete = True

    # Main Loop
    try:
        
        if (args.nonInteractive is False):
          print("Initiating the GoPiGo processing logic in interactive mode. Press <ESC> at anytime to exit.\n")
          input_generator = Input(keynames="curtsies", sigint_event=True)
        else:
          print("Initiating the GoPiGo processing logic in non-interactive mode.\n")

        while True:
                # End loop on <ESC> key
                print("main(" + str(counter) + ")---> carId='" + carId + "' balls_collected='"+ str(balls_collected) +"' ball_color='" + ball_color + "' mode='" + mode + "' sensorRate='" + sensor_rate + "'")
                counter += 1

                if (args.nonInteractive is False):
                    key = input_generator.send(1 / 20)
                    if ((key is not None) and (key == '<ESC>')):
                        break

                if (mode=="automatic"):
                    myCar.SetCarModeLED(myCar.GREEN)
                elif (mode=="manual"):
                    myCar.SetCarModeLED(myCar.BLUE)
                elif (mode=="debug"):
                    myCar.SetCarModeLED(myCar.RED)


                # process any new commands in the queue
                if (len(action_queue) > 0):
                    action_sequence_complete = False
                    # Processing older action first
                    action = action_queue.popleft()
                    # action_queue.clear()

                    command_timestamp = str(action[0])

                    # Only process commands that were received after time of startup.
                    # We should only be processing commands when we haven't sent any data
                    if(command_timestamp>=startup_time):
                        action_type = str(action[1])
                        action_value = action[2]
                        if (action_type == "driveForwardMm"):
                            print("main(): drive forward " + str(action_value) + " mm")
                            if (myCar.drive(int(action_value),dist_limit)):
                                send_next_message = True
                                obstacle_found = True
                        elif (action_type == "driveBackwardMm"):
                            print("main(): drive backward " + str(action_value) + " mm")
                            myCar.drive(int(action_value),dist_limit)
                        elif (action_type == "turnRight"):
                            print("main(): turn right by " + str(action_value) + " degrees")
                            myCar.turn_degrees(int(action_value))
                            time.sleep(0.5)     # Short delay to prevent overlapping commands and car confusion
                        elif (action_type == "turnLeft"):
                            print("main(): turn left by " + str(action_value) + " degrees")
                            myCar.turn_degrees(int(action_value))
                            time.sleep(0.5)     # Short delay to prevent overlapping commands and car confusion
                        elif (action_type == "setColor"):
                            print("main(): set color to " + str(action_value))
                            ball_color = str(action_value)

                            if (ball_color=="Red"):
                                myCar.SetBallModeLED(myCar.RED)
                            elif (ball_color=="Yellow"):
                                myCar.SetBallModeLED(myCar.YELLOW)
                            elif (ball_color=="Green"):
                                myCar.SetBallModeLED(myCar.GREEN)
                            elif (ball_color=="Blue"):
                                myCar.SetBallModeLED(myCar.BLUE)
                            else:
                                print("main(): Invalid ball color received")


                            print("main(): After changing the color of the ball, # of collected balls reset to 0")
                            balls_collected = 0
                        elif (action_type == "setSpeed"):
                            print("main(): set speed to " + str(action_value))
                            myCar.set_speed(int(action_value))
                        elif (action_type == "gripperPosition" and action_value == "open"):
                            print("main(): open gripper")
                            myCar.GripperOpen()
                        elif (action_type == "gripperPosition" and action_value == "close"):
                            print("main(): close gripper")
                            myCar.GripperClose()
                            time.sleep(0.3)     # Short delay to prevent overlapping commands and car confusion
                        elif (action_type == "sendSensorMessage" and action_value == "true"):
                            send_next_message = True
                        else:
                            print("main(): received invalid action: " + str(action_type))
                    else:
                        print("main(): stale messages received from before startup. Ignoring and only processing new commands")

                    print("main()<--- completed action: '" + action[1] + " " + str(action[2]))

                    if len(action_queue) == 0:
                        action_sequence_complete = True
                        print("main(): no more actions in the queue")

                ######### Once commands are processed collect picture, distance, voltage
                elif ((stream_messages or send_next_message) and action_sequence_complete):
                    print("main(): stream_messages='" + str(stream_messages) + "' send_next_message='" + str(send_next_message) + "'")
                    # Start the network loop.
                    voltage = myCar.ReadBatteryVoltage()
                    distance = myCar.ReadDistanceMM()
                    print("main(): distance Sensor (mm): " + str(distance))
                    # Sleep briefly before taking a photo to prevent blurry images
                    myCar.SetCarStatusLED(myCar.YELLOW)
                    time.sleep(0.1)
                    gcs_image_url, public_image_url = takephoto(project_var,bucket_var, camera_position)
                    print("main(): image URL: " + str(public_image_url))
                    print("main(): publishing message")
                    timestampMs = int(time.time() * 1000)
                    carId = logical_car_id
                    carState = {}
                    carState["color"] = ball_color
                    carState["batteryLeft"] = voltage
                    # Need to keep count of balls collected
                    carState["ballsCollected"] = balls_collected

                    if (obstacle_found):
                        carState["obstacleFound"] = True
                        obstacle_found = False

                    sensors = {}
                    sensors["frontLaserDistanceMm"] = distance
                    sensors["frontCameraImagePath"] = public_image_url
                    sensors["frontCameraImagePathGCS"] = gcs_image_url
                    data = {}
                    data["timestampMs"] = timestampMs
                    data["carId"] = carId
                    data["carState"] = carState
                    data["sensors"] = sensors
                    envelope = json.dumps(data)
                    payload = json.dumps(envelope).encode('utf8')
                    client.publish(mqtt_telemetry_topic, payload, qos=1)
                    # In case we are in a single message sensorRate - mark this message as being sent to prevent more messages
                    send_next_message = False
                    print("main()----------------------> msg published to the cloud")
                    myCar.SetCarStatusLED(myCar.GREEN)
                else:
                    time.sleep(2)

    except Exception as e:
        print(
            'Exception(): listening for messages on {} threw an Exception: {}.'.format(subscription, e))
        raise
