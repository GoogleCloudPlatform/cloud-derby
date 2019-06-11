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

var app = require('../app');
var chai = require('chai');
var request = require('supertest');

const BALL_COLORS = require('../validate').BALL_COLORS;
const DRIVING_MODES = require('../validate').DRIVING_MODES;

var expect = chai.expect;

describe('API Successful Tests (/api)', function() {

  it('GET /: should return 200 and Welcome to the <APP NAME> API! message', function(done) {
    request(app)
      .get('/api')
      .end(function(err, res) {
        expect(res.body.message).to.be.an('string').that.does.include('Welcome to the');
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('GET /stats: should return 200 and stats keys', function(done) {
    request(app)
      .get('/api/stats')
      .end(function(err, res) {
        var keys = ["totalErrors", "totalMessagesSent", "totalMessagesReceived",
          "rejectedFormatMessages", "rejectedOutOfOrderMessages"];
        expect(res.body.data).to.all.keys(keys);
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('GET /config/options: should return 200 and valid config options', function(done) {
    request(app)
      .get('/api/config/options')
      .end(function(err, res) {
        expect(res.body.data.ballColors).to.have.members(BALL_COLORS);
        expect(res.body.data.drivingModes).to.have.members(DRIVING_MODES);
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('GET /config: should return 200 and config keys', function(done) {
    request(app)
      .get('/api/config')
      .end(function(err, res) {
        var keys = ["ballColor", "currentDrivingMode", "listenerStatus", "commandTopic",
          "sensorSubscription", "carId"];
        expect(res.body.data).to.all.keys(keys);
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('PUT /config: should return 200 for a sample payload', function(done) {
    request(app)
      .put('/api/config')
      .send({'ballColor': 'blue'})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('GET /messages: should return 200 and messages arrays', function(done) {
    request(app)
      .get('/api/messages')
      .end(function(err, res) {
        expect(res.body.data.inboundMsgHistory).to.be.an('array');
        expect(res.body.data.outboundMsgHistory).to.be.an('array');
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/debug: should return 201 for a sample payload', function(done) {
    request(app)
      .post('/api/messages/debug')
      .send({'sendCommand': true})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 201 for gripperOpen true', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'gripperOpen': true})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 201 for gripperOpen false', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'gripperOpen': false})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 201 for drivingSpeed:100, distance:100', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'drivingSpeed': 100, 'distance': 100})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 201 for turnSpeed:200, angle:180', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'turnSpeed': 200, 'angle': 180})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 201 for turnSpeed:200, angle:-180', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'turnSpeed': 100, 'angle': -180})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 201 for drivingSpeed:100, distance:-100', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'drivingSpeed': 100, 'distance': -100})
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.status).to.be.equal(201);
        expect(res.statusCode).to.be.equal(201);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

});
