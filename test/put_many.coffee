sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model'
ModelCustomKey = require './fixtures/model_custom_key'
ParentModel = require './fixtures/parent_model'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

MongooseResource = require '..'

{response, model} = {}

describe 'PUT many', ->
  describe 'updating model values', ->
    before fibrous ->
      Model.sync.remove()
      ParentModel.sync.remove()
      model1 = Model.sync.create name: 'test1'
      model1.name = 'apple'
      model2 = Model.sync.create name: 'test2'
      model2.name = 'orange'
      response = request.sync.put
        url: "http://127.0.0.1:4000/resource"
        json: [model1, model2]

    it 'returns the updated resource', ->
      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2
      expect(response.body[0].name).to.equal 'apple'
      expect(response.body[1].name).to.equal 'orange'

    it 'saves to the DB, in the model schema', fibrous ->
      modelsFound = Model.sync.find()
      expect(modelsFound.length).to.equal 2
      expect(modelsFound[0].name).to.equal 'apple'
      expect(modelsFound[1].name).to.equal 'orange'
