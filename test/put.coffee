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

describe '.put(id)', ->
  describe 'updating model values', ->
    before fibrous ->
      Model.sync.remove()
      model = Model.sync.create
        name: 'test'
        product:
          name: 'apples'
          price: 25

      response = request.sync.put
        url: "http://127.0.0.1:4000/resource/#{model._id}"
        json:
          name: 'test'
          productName: 'berries'
          product: price: 25

    it 'returns the updated resource', ->
      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'test'
      expect(response.body.productName).to.equal 'berries'
      expect(response.body.product.price).to.equal 25
      expect(response.body._id).to.be.ok

    it 'saves to the DB, in the model schema', fibrous ->
      modelsFound = Model.sync.find()
      expect(modelsFound.length).to.equal 1
      expect(modelsFound[0].product.name).to.equal 'berries'
      expect(modelsFound[0].product.price).to.equal 25
      expect(modelsFound[0].name).to.equal 'test'

  describe 'updating falsy values', ->
    before fibrous ->
      Model.sync.remove()
      model = Model.sync.create
        name: 'test'
        active: true

    it 'sets the values', fibrous ->
      response = request.sync.put
        url: "http://127.0.0.1:4000/resource/#{model._id}"
        json:
          name: 'test'
          active: false

      expect(Model.sync.findById(model._id).active).to.equal false
      expect(response.body.active).to.equal false

  describe 'putting to uncreated resource (upserting)', ->
    before fibrous ->
      ModelCustomKey.sync.remove()
      modelCustomKey = ModelCustomKey.sync.create
        key: 'foo'
        name: 'test1'

      response = request.sync.put
        url: "http://127.0.0.1:4000/resource_custom_key/bar"
        json:
          key: 'bar'
          name: 'test2'

    it 'returns the upserted resource', ->
      expect(response.statusCode).to.equal 200
      expect(response.body).to.deep.equal
        key: 'bar'
        name: 'test2'

    it 'creates the resource in teh database', fibrous ->
      modelFound = ModelCustomKey.sync.findOne(key: 'bar')
      expect(ModelCustomKey.sync.count()).to.equal 2
      expect(modelFound.name).to.equal 'test2'
      expect(modelFound.key).to.equal 'bar'

  describe 'updating dynamic $set values', ->
    before fibrous ->
      Model.sync.remove()
      model = Model.sync.create name: 'hello'

      response = request.sync.put
        url: "http://127.0.0.1:4000/resource/#{model._id}"
        json: { name: 'GoodBye' }

    it 'sets the value to lowercase when saved', fibrous ->
      model = Model.sync.findOne()
      expect(model.name).to.equal 'goodbye'
