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

describe('API Failure Tests (/api)', function() {

  it('GET /unknown: should return 404', function(done) {
    request(app)
      .get('/api/unknown')
      .end(function(err, res) {
        expect(res.statusCode).to.be.equal(404);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('PUT /config: should return 400 for a bad payload', function(done) {
    request(app)
      .put('/api/config')
      .send({'abc': 123})
      .end(function(err, res) {
        ///console.log(res);
        expect(res.body.success).to.be.false;
        expect(res.body.status).to.be.equal(400);
        expect(res.statusCode).to.be.equal(400);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/debug: should return 400 for a bad payload', function(done) {
    request(app)
      .post('/api/messages/debug')
      .send({'abc': 123})
      .end(function(err, res) {
        expect(res.body.success).to.be.false;
        expect(res.body.status).to.be.equal(400);
        expect(res.statusCode).to.be.equal(400);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

  it('POST /messages/driving: should return 400 for a bad payload', function(done) {
    request(app)
      .post('/api/messages/driving')
      .send({'abc': 123})
      .end(function(err, res) {
        expect(res.body.success).to.be.false;
        expect(res.body.status).to.be.equal(400);
        expect(res.statusCode).to.be.equal(400);
        expect(res.headers).to.have.property('access-control-allow-origin');
        done();
      });
  });

});
