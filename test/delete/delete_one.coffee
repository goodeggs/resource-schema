fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
{suite, given} = require '../support/helpers'
ResourceSchema = require '../..'

suite 'DELETE one', ({withModel, withServer}) ->
  withModel (mongoose) ->
    mongoose.Schema name: String

  beforeEach fibrous ->
    schema = { '_id', 'name' }
    @resource = new ResourceSchema @model, schema
    @fruit = @model.sync.create name: 'banana'

  withServer (app) ->
    app.delete '/fruits/:_id', @resource.delete('_id'), @resource.send
    app

  it 'returns the saved resources', fibrous ->
    @response = @request.sync.del
      url: "/fruits/#{@fruit._id}"
      json: true
    expect(@response.statusCode).to.equal 204
    expect(@model.sync.count()).to.equal 0
