sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require '../fixtures/model.coffee'
ParentModel = require '../fixtures/parent_model.coffee'
expect = require('chai').expect
request = require 'request'
require '../support/bootstrap'

MongooseResource = require '../..'

{response, model} = {}

describe 'DELETE one', ->
  {model} = {}
  describe 'no params', ->
    before fibrous ->
      Model.sync.remove()
      model = Model.sync.create name: 'test'

    it 'returns 204 if successful', fibrous ->
      response = request.sync.del
        url: "http://127.0.0.1:4000/resource/#{model._id}"
        json: true
      expect(response.statusCode).to.equal 204

    it 'removes the instance from the database', fibrous ->
      expect(Model.sync.count()).to.equal 0
