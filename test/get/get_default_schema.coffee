{suite, given} = require '../support/helpers'
sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require '../fixtures/model.coffee'
ParentModel = require '../fixtures/parent_model.coffee'
expect = require('chai').expect
request = require 'request'
require '../support/bootstrap'

ResourceSchema = require '../..'

suite 'GET default schema', ({withModel, withServer}) ->
  describe 'get resource by custom key', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      @resource = new ResourceSchema @model

    withServer (app) ->
      app.get '/fruits/:name', @resource.get('name'), @resource.send
      app

    it 'returns the requested object', fibrous ->
      model = @model.sync.create name: 'apple'
      model = @model.sync.create name: 'banana'
      response = @request.sync.get "/fruits/banana"
      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'banana'
