sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model'
ParentModel = require './fixtures/parent_model'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

{response, model} = {}

describe 'dynamic model finders', ->
  describe '.query()', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()
      model1 = Model.sync.create name: 'foo'
      model2 = Model.sync.create name: 'bar'
      model3 = Model.sync.create name: 'baz'
      parentModel = ParentModel.sync.create
        name: 'banana'
        modelIds: [model1._id, model2._id]

    it 'returns all fields in the model', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource?parentName=banana',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2
      expect(response.body[0].name).to.equal 'foo'
      expect(response.body[1].name).to.equal 'bar'
