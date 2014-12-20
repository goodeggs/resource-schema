sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require '../fixtures/model'
ModelCustomKey = require '../fixtures/model_custom_key'
ParentModel = require '../fixtures/parent_model'
expect = require('chai').expect
request = require 'request'
require '../support/bootstrap'
{suite, given} = require '../support/helpers'

ResourceSchema = require '../..'
MongooseResource = require '../..'

{response, model} = {}

suite 'PUT many', ({withModel, withServer}) ->
  given 'valid request', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res', @resource.put(), @resource.send
      app

    beforeEach fibrous ->
      model1 = @model.sync.create name: 'Eric Cartman'
      model1.name = 'Stan Marsh'
      model2 = @model.sync.create name: 'Kyle Broflovski'
      model2.name = 'Kenny McCormick'
      @response = @request.sync.put "/res", json: [model1, model2]

    it '200s with the updated resource', ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body.length).to.equal 2
      names = @response.body.map (model) -> model.name
      expect(names).to.contain 'Stan Marsh'
      expect(names).to.contain 'Kenny McCormick'

    it 'saves to the DB', fibrous ->
      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 2
      names = modelsFound.map (model) -> model.name
      expect(names).to.contain 'Stan Marsh'
      expect(names).to.contain 'Kenny McCormick'

  given 'PUT an empty array', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res', @resource.put(), @resource.send
      app

    beforeEach fibrous ->
      @response = @request.sync.put "/res", json: []

    it '200s with an empty array', ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body).to.deep.equal []
