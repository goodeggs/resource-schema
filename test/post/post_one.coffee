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

suite 'POST one', ({withModel, withServer}) ->
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
      json: { name: 'apple' }

  it 'returns the saved resources', fibrous ->
    expect(@response.statusCode).to.equal 201
    expect(@response.body.name).to.equal 'apple'
    expect(@response.body._id).to.be.ok

  it 'saves the models to the DB', fibrous ->
    modelsFound = @model.sync.find()
    expect(modelsFound.length).to.equal 1
    expect(modelsFound[0].name).to.equal 'apple'
