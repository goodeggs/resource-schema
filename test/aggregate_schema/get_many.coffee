fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
{suite, given} = require '../support/helpers'

ResourceSchema = require '../..'

suite 'aggregate resource - GET ', ({withModel, withServer}) ->
  describe 'many', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = {'name'}
      config = groupBy: ['name']
      @resource = new ResourceSchema @model, schema, config

    withServer (app) ->
      app.get '/animals', @resource.get(), @resource.send
      app

    beforeEach fibrous ->
      @model.sync.create name: 'goat'
      @model.sync.create name: 'goat'
      @model.sync.create name: 'goat'
      @model.sync.create name: 'kangaroo'
      @response = @request.sync.get
        url: '/animals',
        json: true

    it 'returns only the aggregate objects', ->
      expect(@response.body.length).to.equal 2
      expect(@response.body[1].name).to.equal 'goat'
      expect(@response.body[0].name).to.equal 'kangaroo'

    it 'populates the _id with the aggregate value (for saving in the future)', ->
      expect(@response.body.length).to.equal 2
      expect(@response.body[1]._id).to.equal 'goat'
      expect(@response.body[0]._id).to.equal 'kangaroo'

  describe 'aggregate operations (like $sum)', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema =
        'name': 'name'
        'total':
          get: {$sum: 1}
      config = groupBy: ['name']
      @resource = new ResourceSchema @model, schema, config

    withServer (app) ->
      app.get '/animals', @resource.get(), @resource.send
      app

    beforeEach fibrous ->
      @model.sync.create name: 'goat'
      @model.sync.create name: 'goat'
      @model.sync.create name: 'goat'
      @model.sync.create name: 'kangaroo'

    it 'returns aggregate operations (like $sum)', ->
      response = @request.sync.get
        url: '/animals',
        json: true
      expect(response.body.length).to.equal 2
      expect(response.body[1].total).to.equal 3
      expect(response.body[0].total).to.equal 1

  describe 'search fields', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = {'name'}
      config = groupBy: ['name']
      @resource = new ResourceSchema @model, schema, config

    withServer (app) ->
      app.get '/animals', @resource.get(), @resource.send
      app

    beforeEach fibrous ->
      @model.sync.create name: 'goat'
      @model.sync.create name: 'goat'
      @model.sync.create name: 'goat'
      @model.sync.create name: 'kangaroo'
      @response = @request.sync.get
        url: '/animals?name=goat',
        json: true

    it 'queries by the parameter', ->
      expect(@response.body.length).to.equal 1
      expect(@response.body[0].name).to.equal 'goat'

  describe 'aggregate by multiple fields', ->
    withModel (mongoose) ->
      mongoose.Schema
        name: String
        region: String

    beforeEach ->
      schema = {'name', 'region'}
      config = groupBy: ['name', 'region']
      @resource = new ResourceSchema @model, schema, config

    withServer (app) ->
      app.get '/animals', @resource.get(), @resource.send
      app

    beforeEach fibrous ->
      @model.sync.create
        name: 'goat'
        region: 'australia'
      @model.sync.create
        name: 'goat'
        region: 'australia'
      @model.sync.create
        name: 'goat'
        region: 'new zealand'
      @response = @request.sync.get
        url: '/animals',
        json: true

    it 'returns only the specified fields in the dynamic search', fibrous ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body.length).to.equal 2
      expect(@response.body[1].name).to.equal 'goat'
      expect(@response.body[1].region).to.equal 'australia'
      expect(@response.body[0].name).to.equal 'goat'
      expect(@response.body[0].region).to.equal 'new zealand'

    it 'returns an id from all the combined aggregated values', ->
      expect(@response.body[1]._id).to.equal('goat|australia')
