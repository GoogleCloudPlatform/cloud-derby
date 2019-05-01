var app = require('../app');
var chai = require('chai');
var request = require('supertest');

var expect = chai.expect;

describe('API Tests (/api)', function() {
  it('/: should return 200 and Welcome to the <APP NAME> API! message', function(done) {
    request(app)
      .get('/api')
      .end(function(err, res) {
        expect(res.body.success).to.be.true;
        expect(res.body.message).to.be.an('string').that.does.include('Welcome to the');
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        done();
      });
  });
  it('/stats: should return 200 and stats', function(done) {
    request(app)
      .get('/api/stats')
      .end(function(err, res) {
        expect(res.body.data.totalErrors).to.be.an('number');
        expect(res.body.data.totalMessagesSent).to.be.an('number');
        expect(res.body.data.totalMessagesReceived).to.be.an('number');
        expect(res.body.data.rejectedFormatMessages).to.be.an('number');
        expect(res.body.data.rejectedOutOfOrderMessages).to.be.an('number');
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        done();
      });
  });
  it('/config/options: should return 200 and config options', function(done) {
    request(app)
      .get('/config/options')
      .end(function(err, res) {
        expect(res.body.data.ballColors).to.be.an('array');
        expect(res.body.data.drivingModes).to.be.an('array');
        expect(res.body.status).to.be.equal(200);
        expect(res.statusCode).to.be.equal(200);
        done();
      });
  });
});
