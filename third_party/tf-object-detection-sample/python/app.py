#!/usr/bin/python
# -*- coding: utf-8 -*-

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

# Based on: https://github.com/GoogleCloudPlatform/tensorflow-object-detection-example

import base64
import cStringIO
import sys
import tempfile
import os
import json
import time

from decorator import requires_auth
from flask import Flask
from flask import redirect
from flask import render_template
from flask import request
from flask import url_for
from flask_wtf.file import FileField
from flask import jsonify
import numpy as np
from PIL import Image
from PIL import ImageDraw
import tensorflow as tf
from utils import label_map_util
from werkzeug.datastructures import CombinedMultiDict
from wtforms import Form
from wtforms import ValidationError
from google.cloud import storage
from google.cloud.exceptions import NotFound
from urllib2 import unquote

app = Flask(__name__)

@app.before_request
@requires_auth
def before_request():
  pass

# Anything with the probability score lower than this will not be deleted from results
PROBABILITY_TRESHOLD = 0.05

# Consider different proximity thresholds for objects of the same type and of different type
# aka same type=0.5, different type=0.05 (for example)

# Any objects located near each other within this % (relative to the image size) will be deemed as onee object
# Considering that the final game will allow for 4 balls overall, chances are those balls are pretty far apart from each other
PROXIMITY_THRESHOLD = 0.04

PATH_TO_CKPT = os.environ['PATH_TO_CKPT'] + '/frozen_inference_graph.pb'
MODEL_BASE = os.environ['MODEL_BASE']
PATH_TO_LABELS = os.environ['PATH_TO_LABELS']

# The name of the current VM - for debug
VM_NAME = os.environ['VM_NAME']

PORT = int(os.environ['HTTP_PORT'])
INFERENCE_URL = os.environ['INFERENCE_URL']

content_types = {'jpg': 'image/jpeg',
                 'jpeg': 'image/jpeg',
                 'png': 'image/png'}

extensions = sorted(content_types.keys())
label_map = { "1":"BlueBall", "2":"RedBall", "3":"YellowBall", "4":"GreenBall", "5":"BlueHome", "6":"RedHome", "7":"YellowHome", "8":"GreenHome" }

storage_client = storage.Client()

def is_image():
  def _is_image(form, field):
    if not field.data:
      raise ValidationError()
    elif field.data.filename.split('.')[-1].lower() not in extensions:
      raise ValidationError()

  return _is_image


class PhotoForm(Form):
  input_photo = FileField(
      'File extension should be: %s (case-insensitive)' % ', '.join(extensions),
      validators=[is_image()])


class ObjectDetector(object):

  def __init__(self):
    self.detection_graph = self._build_graph()
    self.sess = tf.Session(graph=self.detection_graph)

    label_map = label_map_util.load_labelmap(PATH_TO_LABELS)
    categories = label_map_util.convert_label_map_to_categories(
        label_map, max_num_classes=90, use_display_name=True)
    self.category_index = label_map_util.create_category_index(categories)

  def _build_graph(self):
    detection_graph = tf.Graph()
    with detection_graph.as_default():
      od_graph_def = tf.GraphDef()
      with tf.gfile.GFile(PATH_TO_CKPT, 'rb') as fid:
        serialized_graph = fid.read()
        od_graph_def.ParseFromString(serialized_graph)
        tf.import_graph_def(od_graph_def, name='')

    return detection_graph

  def _load_image_into_numpy_array(self, image):
    (im_width, im_height) = image.size
    return np.array(image.getdata()).reshape(
        (im_height, im_width, 3)).astype(np.uint8)

  def detect(self, image):
    image_np = self._load_image_into_numpy_array(image)
    image_np_expanded = np.expand_dims(image_np, axis=0)

    graph = self.detection_graph
    image_tensor = graph.get_tensor_by_name('image_tensor:0')
    boxes = graph.get_tensor_by_name('detection_boxes:0')
    scores = graph.get_tensor_by_name('detection_scores:0')
    classes = graph.get_tensor_by_name('detection_classes:0')
    num_detections = graph.get_tensor_by_name('num_detections:0')

    (boxes, scores, classes, num_detections) = self.sess.run(
        [boxes, scores, classes, num_detections],
        feed_dict={image_tensor: image_np_expanded})

    boxes, scores, classes, num_detections = map(
        np.squeeze, [boxes, scores, classes, num_detections])

    return boxes, scores, classes.astype(int), num_detections


def draw_bounding_box_on_image(image, box, color='red', thickness=4):
  draw = ImageDraw.Draw(image)
  im_width, im_height = image.size
  ymin, xmin, ymax, xmax = box
  (left, right, top, bottom) = (xmin * im_width, xmax * im_width,
                                ymin * im_height, ymax * im_height)
  draw.line([(left, top), (left, bottom), (right, bottom),
             (right, top), (left, top)], width=thickness, fill=color)


def encode_image(image):
  image_buffer = cStringIO.StringIO()
  image.save(image_buffer, format='PNG')
  imgstr = 'data:image/png;base64,{:s}'.format(
      base64.b64encode(image_buffer.getvalue()))
  return imgstr


def detect_objects(image_path):
  image = Image.open(image_path).convert('RGB')
  boxes, scores, classes, num_detections = client.detect(image)
  image.thumbnail((480, 480), Image.ANTIALIAS)

  new_images = {}
  for i in range(num_detections):
    if scores[i] < PROBABILITY_TRESHOLD: continue
    cls = classes[i]
    if cls not in new_images.keys():
      new_images[cls] = image.copy()

    draw_bounding_box_on_image(new_images[cls], boxes[i],
                               thickness=int(scores[i]*10)-4)

  result = {}
  result['original'] = encode_image(image.copy())

  for cls, new_image in new_images.iteritems():
    category = client.category_index[cls]['name']
    result[category] = encode_image(new_image)
  result['response_msg'] = json.dumps(build_json_response(boxes, scores, classes, num_detections, image),indent=4)
  return result


def detect_object_bounding_boxes(image_path):
  image = Image.open(image_path).convert('RGB')
  im_width, im_height = image.size
  boxes, scores, classes, num_detections = client.detect(image)
  response_msg = build_json_response(boxes, scores, classes, num_detections, image)
  return response_msg


def build_json_response(boxes, scores, classes, num_detections, image):
  response_msg = {}
  im_width, im_height = image.size
  print "DEBUG: image width:",im_width,"image height:",im_height,"num_detections:",num_detections,"PROBABILITY_TRESHOLD:",PROBABILITY_TRESHOLD,"PROXIMITY_THRESHOLD:",PROXIMITY_THRESHOLD
  for i in range(num_detections):
    if scores[i] > PROBABILITY_TRESHOLD:
      ymin, xmin, ymax, xmax = boxes[i]
      (left, right, bottom, top) = (xmin, xmax, ymin, ymax)
      width = right-left
      height = top - bottom
      label = label_map[str(classes[i])] + str(i)
      response_msg[label] = []
      response_msg[label].append({"x":str(left), "y":str(bottom), "w":str(width), "h":str(height), "score":str(scores[i])})
      print "label:",label_map[str(classes[i])],", score:", scores[i]," x:",left," y:",bottom," h:",height," w:",width
    else:
      label = label_map[str(classes[i])]
  return check_for_ball_proximity(response_msg)
  

def check_for_ball_proximity(response_msg):
  responses_to_remove = [] 
  for k,v in response_msg.iteritems():
    if k not in responses_to_remove:
      # Since we are using relative coordinates 0 to 1 - using float
      x1 = float(response_msg[k][0]["x"])
      y1 = float(response_msg[k][0]["y"])
      width1 = float(response_msg[k][0]["w"])
      height1 = float(response_msg[k][0]["h"])

      for key,val in response_msg.iteritems():
        if key != k and key not in responses_to_remove:
          x_diff = abs(x1 - float(response_msg[key][0]["x"]))
          y_diff = abs(y1 - float(response_msg[key][0]["y"]))
          w_threshold = width1 * PROXIMITY_THRESHOLD
          h_threshold = height1 * PROXIMITY_THRESHOLD

          if x_diff <= w_threshold and  y_diff <= h_threshold: 
            if float(response_msg[k][0]["score"]) >= float(response_msg[key][0]["score"]):
              print "Removing ",key," because it is in close proximity to k: ",k
              responses_to_remove.append(key)
            else:
              if k not in responses_to_remove:
                print "Removing ",k," because it is in close proximity to key: ",key
                responses_to_remove.append(k)

  for dkey in responses_to_remove:
    del response_msg[dkey]
  
  return response_msg


def get_image_from_GCS(gcs_uri):
  try: 
    uri_split = gcs_uri.split("/");
    bucket_name = uri_split[2];
    bucket = storage_client.get_bucket(bucket_name)
    file_and_path = "/".join(uri_split[3:])
    blob = bucket.get_blob(file_and_path)
    file_name = uri_split[-1]
    blob.download_to_filename(file_name)
    return file_name
  except (NotFound, Exception):
    return None


@app.route('/')
def upload():
  photo_form = PhotoForm(request.form)
  return render_template('upload.html', photo_form=photo_form, result={})


@app.route('/post', methods=['GET', 'POST'])
def post():
  form = PhotoForm(CombinedMultiDict((request.files, request.form)))
  if request.method == 'POST' and form.validate():
    with tempfile.NamedTemporaryFile() as temp:
      form.input_photo.data.save(temp)
      temp.flush()
      start_time = time.time()
      result = detect_objects(temp.name)
      print("--- post() inference took %s seconds" % (time.time() - start_time))

    photo_form = PhotoForm(request.form)
    return render_template('upload.html',
                           photo_form=photo_form, result=result)
  else:
    return redirect(url_for('upload'))


@app.route(INFERENCE_URL,methods=['GET'])
def object_inference():
    gcs_uri = unquote(request.args.get('gcs_uri'))
    print("")
    print("-------------------------- object_inference() on file '%s'" % gcs_uri)
    file_name = get_image_from_GCS(gcs_uri)
    if file_name != None:
      print("Starting inference on file '%s'..." % file_name)
      start_time = time.time()
      response_from_ml = detect_object_bounding_boxes(file_name)
      print("--- rest() inference took %s seconds" % (time.time() - start_time))
      print response_from_ml
      return jsonify(response_from_ml)
    else:
      error_msg = {"Error" : "GCS file {file} not found or access is denied.".format(file=gcs_uri) }
      print error_msg
      return jsonify(error_msg), 404
      

@app.route('/v1/objectInferenceDummyData',methods=['GET'])
def object_inference_dummy_Data():

    response_msg = {}
    response_msg['label1'] = []    
    response_msg['label1'].append({ "x" : 0, "y" : 0, "width" : 100, "height" : 100})
    response_msg['label1'].append({ "x" : 10, "y" : 10, "width" : 100, "height" : 100})
    response_msg['label2'] = []    
    response_msg['label2'].append({ "x" : 0, "y" : 0, "width" : 100, "height" : 100})
    response_msg['label2'].append({ "x" : 10, "y" : 10, "width" : 100, "height" : 100})
    return jsonify(response_msg)

client = ObjectDetector()


if __name__ == '__main__':
  app.run(host='0.0.0.0', port=PORT, debug=False)
