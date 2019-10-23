# THIS SCRIPT WRITTEN FOR TESTING GOOGLE CLOUD DERBY HARDWARE
# COPYRIGHT DEXTER INDUSTRIES, SEP 2019

import gopigo3
import time
import easygopigo3 as easy
import sys
import atexit
import urllib2
import os.path


gpg = easy.EasyGoPiGo3()
atexit.register(gpg.stop)

gpg.reset_all()

def test_motors():
	print("Warning: The robot is about to move forward. ")
	time.sleep(1)  # let's give the reset_all() some time to finish
	gpg.set_speed(300)

	print("Motor Test:  test motor power.")
	gpg.forward()
	time.sleep(0.25)
	gpg.backward()
	time.sleep(0.25)
	gpg.stop()
	print("Motor Test:  end motor power tests.")

	print ("Both motors moving Forward with Dex Eyes On")
	gpg.open_eyes()
	gpg.drive_cm(5)
	print ("Both motors moving back with blinkers On")
	gpg.blinker_on(1)
	gpg.blinker_on(0)
	gpg.drive_cm(-5)
	print("Motor Test:  Encoders are ok!")

def test_dist_sensor():
	my_distance_sensor = gpg.init_distance_sensor()
	# Directly print the values of the sensor.
	for i in range(0,5):
 		print("Distance Sensor Reading (mm): " + str(my_distance_sensor.read_mm()))
 		time.sleep(1)

 	print("Distance sensor test complete!")

def servo_test():
	for i in range(1000, 2001):    # count from 1000 to 2000
            gpg.set_servo(gpg.SERVO_1, i)
            gpg.set_servo(gpg.SERVO_2, 3000-i)
            time.sleep(0.001)
	for i in range(1000, 2001):    # count from 1000 to 2000
            gpg.set_servo(gpg.SERVO_2, i)
            gpg.set_servo(gpg.SERVO_1, 3000-i)
            time.sleep(0.001)

def test_camera():
 print("Starting Camera Test Now.")
 # camera = PiCamera()
 from picamera import PiCamera
 from time import sleep

 camera = PiCamera()
 camera.start_preview()
 sleep(5)
 camera.capture('/home/pi/image.jpg')
 camera.stop_preview()
 fname = '/home/pi/image.jpg'
 if os.path.isfile(fname):
 	print("Camera Worked OK!")
 else:
 	print("ERROR WITH CAMERA CHECK!")


def internet_on():
    try:
        urllib2.urlopen('http://216.58.192.142', timeout=1)
        return True
    except urllib2.URLError as err: 
        return False
        
def test_internet():
	print("Testing Internet!")
	if internet_on():
		print("ON!")
	else:
		print("NOT ON!")

		
test_camera()
test_motors()
test_dist_sensor()
servo_test()
test_internet()
gpg.reset_all()	# Clean it up, turn it all off.
