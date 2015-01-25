{suite, given} = require '../support/helpers'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect

ResourceSchema = require '../..'

suite 'no schema - GET one', ({withModel, withServer}) ->
  describe 'no search fields', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      @resource = new ResourceSchema @model

    withServer (app) ->
      app.get '/superheroes', @resource.get(), @resource.send
      app

    it 'returns entire collection', fibrous ->
      @model.sync.create name: 'batman'
      @model.sync.create name: 'chuck norris'
      response = @request.sync.get
        url: '/superheroes',
        json: true
      expect(response.body.length).to.equal 2
      expect(response.body[0].name).to.equal 'batman'
      expect(response.body[1].name).to.equal 'chuck norris'

  describe "with query params", ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      @resource = new ResourceSchema @model

    withServer (app) ->
      app.get '/superheroes', @resource.get(), @resource.send
      app

    it "filters by query params", fibrous ->
      @model.sync.create name: 'batman'
      @model.sync.create name: 'chuck norris'
      response = @request.sync.get
        url: '/superheroes?name=batman',
        json: true
      expect(response.body).to.have.length 1
      expect(response.body[0]).to.have.property 'name', 'batman'

  describe 'querying by custom key', ->
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
