#!/usr/bin/env python

# https://github.com/DexterInd/GoPiGo3/blob/master/LICENSE.md
#
# MIT License
# Copyright (c) 2017 Dexter Industries
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
# (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, 
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Based on https://github.com/DexterInd/GoPiGo3/blob/master/Software/Python/easygopigo3.py
#

import easygopigo3
import time

class RobotDerbyCar(easygopigo3.EasyGoPiGo3):
    """
    This class is used for controlling a `RobotDerbyCar`_ robot.
    With this class you can do the following things with your `RobotDerbyCar`_:
     * Drive your robot while avoiding obstacles
     * Inheriting all EasyGoPiGo3 functionality: https://github.com/DexterInd/GoPiGo3/blob/master/Software/Python/easygopigo3.py
     * Inheriting all GoPiGo3 functionality: https://github.com/DexterInd/GoPiGo3/blob/master/Software/Python/gopigo3.py
     * Set the grippers of the robot to Open or Close positions
    """

    def __init__(self):
        """
        This constructor sets the variables to the following values:
        : CONST_GRIPPER_FULL_OPEN : Position of gripper servo when open
        : CONST_GRIPPER_FULL_CLOSE: Position of gripper servo when closed
        : CONST_GRIPPER_FULL_OPEN : Position of gripper servo to grab ball
        : easygopigo3.EasyGoPiGo3 Easy_GPG: Initialization of EasyGoPiGo3
        : easygopigo3 Easy_GPG: Initialization of EasyGoPiGo3
        : easygopigo3.Servo gpgGripper: Initialization of Gripper Servo on Servo Pin 1
        : init_distance_sensor my_distance_sensor: Initialization of Distance Sensor
        : IOError: When the GoPiGo3 is not detected. It also debugs a message in the terminal.
        : gopigo3.FirmwareVersionError: If the GoPiGo3 firmware needs to be updated. It also debugs a message in the terminal.
        : Exception: For any other kind of exceptions.
        """

        # GoPiGo Color Codes
        self.YELLOW = (255, 255, 0)
        self.GREEN = (0, 255, 0)
        self.RED = (255, 0, 0)
        self.BLUE = (0, 0, 255)

        # Settings for cars in US Reston Office (these grippers were built differently)
        self.CONST_GRIPPER_FULL_OPEN = 90
        self.CONST_GRIPPER_FULL_CLOSE = 0
        self.CONST_GRIPPER_GRAB_POSITION = 40
        
        # Settings for cars in London Office (default method of assembly for grippers)
        #self.CONST_GRIPPER_FULL_OPEN = 180
        #self.CONST_GRIPPER_FULL_CLOSE = 20
        #self.CONST_GRIPPER_GRAB_POSITION = 120
        
        self.Easy_GPG = easygopigo3.EasyGoPiGo3()  # Create an instance of the GoPiGo3 class. GPG will be the GoPiGo3 object.
        self.gpgGripper = easygopigo3.Servo("SERVO1", self.Easy_GPG)
        self.my_distance_sensor = self.Easy_GPG.init_distance_sensor()
        self.SetCarStatusLED(self.GREEN)

    def SetCarStatusLED(self,color):
        self.Easy_GPG.set_right_eye_color(color)
        self.Easy_GPG.open_right_eye()

    def SetCarModeLED(self,color):
        self.Easy_GPG.set_left_eye_color(color)
        self.Easy_GPG.open_left_eye()

    def SetBallModeLED(self,color):
        self.Easy_GPG.set_led(self.Easy_GPG.LED_WIFI,color[0],color[1],color[2])

    def GripperClose(self):
        self.SetCarStatusLED(self.RED)
        self.gpgGripper.rotate_servo(self.CONST_GRIPPER_GRAB_POSITION)
        self.SetCarStatusLED(self.GREEN)

    def GripperOpen(self):
        self.SetCarStatusLED(self.RED)
        self.gpgGripper.rotate_servo(self.CONST_GRIPPER_FULL_OPEN)
        self.SetCarStatusLED(self.GREEN)

    def ReadDistanceMM(self):
        return self.my_distance_sensor.read_mm()

    def ReadBatteryVoltage(self):
        return self.Easy_GPG.get_voltage_battery()

    def set_speed(self,speed):
        self.SetCarStatusLED(self.RED)
        self.Easy_GPG.set_speed(speed)
        self.SetCarStatusLED(self.GREEN)

    def drive_cm(self,distance):
        self.SetCarStatusLED(self.RED)
        self.Easy_GPG.drive_cm(distance,True)
        self.SetCarStatusLED(self.GREEN)

    def turn_degrees(self,degress):
        self.SetCarStatusLED(self.RED)
        self.Easy_GPG.turn_degrees(degress,True)
        self.SetCarStatusLED(self.GREEN)

    def drive(self,dist_requested,dist_limit):
        """
        Move the `GoPiGo3`_ forward / backward for ``dist`` amount of miliimeters.
        | For moving the `GoPiGo3`_ robot forward, the ``dist`` parameter has to be *positive*.
        | For moving the `GoPiGo3`_ robot backward, the ``dist`` parameter has to be *negative*.
        """

        # Have we found any obstacles in the path
        ObstaclesFound = False

        # the number of degrees each wheel needs to turn
        WheelTurnDegrees = ((dist_requested / self.Easy_GPG.WHEEL_CIRCUMFERENCE) * 360)

        # get the starting position of each motor
        CurrentPositionLeft = self.Easy_GPG.get_motor_encoder(self.Easy_GPG.MOTOR_LEFT)
        CurrentPositionRight = self.Easy_GPG.get_motor_encoder(self.Easy_GPG.MOTOR_RIGHT)

        # determine the end position of each motor
        EndPositionLeft = CurrentPositionLeft + WheelTurnDegrees
        EndPositionRight = CurrentPositionRight + WheelTurnDegrees

        self.SetCarStatusLED(self.RED)
        self.Easy_GPG.set_motor_position(self.Easy_GPG.MOTOR_LEFT, EndPositionLeft)
        self.Easy_GPG.set_motor_position(self.Easy_GPG.MOTOR_RIGHT, EndPositionRight)

        while self.Easy_GPG.target_reached(EndPositionLeft, EndPositionRight) is False:
            # read the distance of the laser sensor
            dist_read = self.ReadDistanceMM()

            # stop car if there is an object within the limit
            if ((dist_read is not None) and (int(dist_read) <= int(dist_limit)) and (int(dist_requested) > int(dist_limit))):
                print("RobotDerbyCar.drive(): Obstacle Found. Stopping Car before requested distance. Object distance: " + str(dist_read))
                ObstaclesFound = True
                CurrentPositionLeft = self.Easy_GPG.get_motor_encoder(self.Easy_GPG.MOTOR_LEFT)
                CurrentPositionRight = self.Easy_GPG.get_motor_encoder(self.Easy_GPG.MOTOR_RIGHT)
                self.Easy_GPG.set_motor_position(self.Easy_GPG.MOTOR_LEFT, CurrentPositionLeft)
                self.Easy_GPG.set_motor_position(self.Easy_GPG.MOTOR_RIGHT, CurrentPositionRight)
                break

            time.sleep(0.05)

        self.SetCarStatusLED(self.GREEN)
        return ObstaclesFound
