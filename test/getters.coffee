sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model'
ParentModel = require './fixtures/parent_model'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

{response, model} = {}

describe 'dynamic model getters', ->
  describe '.get()', ->
    {model1} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()
      model1 = Model.sync.create name: 'foo'
      model2 = Model.sync.create name: 'bar'
      model3 = Model.sync.create name: 'baz'
      parent = ParentModel.sync.create
        name: 'banana'
        modelIds: [model1._id, model2._id]

    it 'returns all fields in the model', fibrous ->
      response = request.sync.get
        url: "http://127.0.0.1:4000/resource_dynamic_get/#{model1._id}",
        json: true

      console.log 'RESPONSE', response.body

      expect(response.statusCode).to.equal 200
      expect(response.body.parentName).to.equal 'banana'
