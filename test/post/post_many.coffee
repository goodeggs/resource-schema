sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require '../fixtures/model.coffee'
expect = require('chai').expect
request = require 'request'
{suite, given} = require '../support/helpers'

MongooseResource = require '../..'
ResourceSchema = require '../..'

{response, model} = {}

suite 'POST many', ({withModel, withServer}) ->
  given 'valid post', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.post '/res', @resource.post(), @resource.send
      app

    beforeEach fibrous ->
      @response = @request.sync.post "/res",
        json: [
          { name: 'apples' }
          { name: 'pears' }
          { name: 'oranges' }
        ]

    it 'returns the saved resources', fibrous ->
      expect(@response.statusCode).to.equal 201
      expect(@response.body.length).to.equal 3
      savedNames = @response.body.map (m) -> m.name
      expect(savedNames).to.contain 'apples'
      expect(savedNames).to.contain 'pears'
      expect(savedNames).to.contain 'oranges'
      expect(@response.body[0]._id).to.be.ok
      expect(@response.body[1]._id).to.be.ok
      expect(@response.body[2]._id).to.be.ok

    it 'saves the models to the DB', fibrous ->
      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 3
      savedNames = modelsFound.map (m) -> m.name
      expect(savedNames).to.contain 'apples'
      expect(savedNames).to.contain 'pears'
      expect(savedNames).to.contain 'oranges'

  given 'posting empty array', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.post '/res', @resource.post(), @resource.send
      app

    beforeEach fibrous ->
      [0..10].forEach => @model.sync.create name: 'bam'
      @response = @request.sync.post "/res", json: []

    it '200s with an empty array', ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body).to.deep.equal []
