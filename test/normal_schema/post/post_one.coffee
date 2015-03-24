fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
{suite, given} = require '../../support/helpers'

ResourceSchema = require '../../..'

suite 'POST one', ({withModel, withServer}) ->
  withModel (mongoose) ->
    schema = mongoose.Schema name: type: String, required: true
    schema.pre 'save', (next) ->
      @quantity = 1
      next()

  beforeEach ->
    schema = { '_id', 'name', 'price', 'quantity' }
    @resource = new ResourceSchema @model, schema

  withServer (app) ->
    app.post '/res', @resource.post(), @resource.send
    app

  it 'returns the saved resources', fibrous ->
    @response = @request.sync.post "/res",
      json: { name: 'apple' }
    expect(@response.statusCode).to.equal 201
    expect(@response.body.name).to.equal 'apple'
    expect(@response.body._id).to.be.ok
    expect(@response.body.quantity).to.be.ok

  it 'saves the models to the DB', fibrous ->
    @response = @request.sync.post "/res",
      json: { name: 'apple' }
    modelsFound = @model.sync.find()
    expect(modelsFound.length).to.equal 1
    expect(modelsFound[0].name).to.equal 'apple'

  it '400s when posting invalid field', fibrous ->
    @response = @request.sync.post "/res",
      json: { _id: '123', name: 'apple' }
    expect(@response.statusCode).to.equal 400

  it '400 when validation failed', fibrous ->
    @response = @request.sync.post "/res",
      json: { }
    expect(@response.statusCode).to.equal 400
