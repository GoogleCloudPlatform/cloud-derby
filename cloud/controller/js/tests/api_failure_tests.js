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
        done();
      });
  });

});
