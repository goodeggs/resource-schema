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
    expect(@response.body[0].name).to.equal 'apples'
    expect(@response.body[0]._id).to.be.ok
    expect(@response.body[1].name).to.equal 'pears'
    expect(@response.body[1]._id).to.be.ok
    expect(@response.body[2].name).to.equal 'oranges'
    expect(@response.body[2]._id).to.be.ok

  it 'saves the models to the DB', fibrous ->
    modelsFound = @model.sync.find()
    expect(modelsFound.length).to.equal 3
    expect(modelsFound[0].name).to.equal 'apples'
    expect(modelsFound[1].name).to.equal 'pears'
    expect(modelsFound[2].name).to.equal 'oranges'
