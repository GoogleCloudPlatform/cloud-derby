Google Cloud Derby
=====

This project is designed to help you learn Google Cloud Platform (GCP) 
in a fun way by building a self driving robot car that plays ball game 
against other robots. We provide all the instructions to build hardware and software. With 
this project you will learn how to use various GCP services:

- IoT Core
- TensorFlow Object Detection API
- Pub/Sub
- Cloud Storage
- Compute Engine
- App Engine
- Cloud Functions
- DialogFlow
- Security
- Networking
- IAM

There are two subsystems in this project: (1) car, and (2) cloud. 
Software running on the cloud controls movement of the car. 
In order to do it, several interconnected modules work together and 
interact with the software running on the car via GCP PubSub and IoT Core.
We use Raspberry Pi based GoPiGo cars made by Dexter for this game with wide angle camera 
and laser sensor.

Architecture diagrams, contact information, and build instructions can be found on the
[Project website](https://www.cloudderby.io).