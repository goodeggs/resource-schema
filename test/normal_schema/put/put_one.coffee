fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
mongoose = require 'mongoose'
{suite, given} = require '../../support/helpers'

ResourceSchema = require '../../..'

suite 'PUT one', ({withModel, withServer}) ->
  given 'updating model values', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res/:_id', @resource.put('_id'), @resource.send
      app

    beforeEach fibrous ->
      model = @model.sync.create name: 'orange'
      model.name = 'apple'
      @response = @request.sync.put "/res/#{model._id}",
        json: {name: 'apple'}

    it 'returns the saved resources', fibrous ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body.name).to.equal 'apple'
      expect(@response.body._id).to.be.ok

    it 'saves the updated model to the DB', fibrous ->
      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 1
      expect(modelsFound[0].name).to.equal 'apple'

  given 'updating falsy values', ->
    withModel (mongoose) ->
      mongoose.Schema active: Boolean

    beforeEach ->
      schema = { '_id', 'active' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res/:_id', @resource.put('_id'), @resource.send
      app

    it 'updates the falsy value', fibrous ->
      model = @model.sync.create { active: true }
      model.active = false

      response = @request.sync.put "/res/#{model._id}", json: {active: false}
      expect(response.statusCode).to.equal 200
      expect(response.body.active).to.equal false
      expect(response.body._id).to.be.ok

      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 1
      expect(modelsFound[0].active).to.equal false

  given 'putting to a custom key (not _id)', ->
    withModel (mongoose) ->
      mongoose.Schema
        key: type: String
        name: String

    beforeEach ->
      schema = { 'key', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res/:key', @resource.put('key'), @resource.send
      app

    it 'updates the resource', fibrous ->
      model = @model.sync.create { key: '123', name: 'apple' }
      model.name = 'orange'

      response = @request.sync.put "/res/#{model.key}", json: model
      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'orange'

      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 1
      expect(modelsFound[0].name).to.equal 'orange'
      @model.sync.remove()

  given 'putting to uncreated resource (upserting)', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res/:_id', @resource.put('_id'), @resource.send
      app

    it 'upserts the resource', fibrous ->
      newId = new mongoose.Types.ObjectId()
      response = @request.sync.put "/res/#{newId}", json: {name: 'apple'}

      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'apple'
      expect(response.body._id).to.equal newId.toString()

      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 1
      expect(modelsFound[0].name).to.equal 'apple'

  given 'PUT resource with set field', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = {
        '_id'
        'name':
          field: 'name'
          set: (resource) -> resource.name.toLowerCase()
      }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res/:_id', @resource.put('_id'), @resource.send
      app

    it 'applies the setter', fibrous ->
      model = @model.sync.create name: 'Apple'
      response = @request.sync.put "/res/#{model._id}", json: model

      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'apple'
      expect(response.body._id).to.be.ok

      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 1
      expect(modelsFound[0].name).to.equal 'apple'

  given 'PUT resource with optional fields', ->
    withModel (mongoose) ->
      mongoose.Schema
        name: String
        age: Number

    beforeEach ->
      schema = {
        '_id'
        'name'
        'age':
          optional: true
          field: 'age'
        'score':
          optional: true
          get: -> 95
      }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res/:_id', @resource.put('_id'), @resource.send
      app

    it 'returns the optional field if it is included in the request body', fibrous ->
      model = @model.sync.create
        name: 'bob'
        age: 10

      response = @request.sync.put "/res/#{model._id}",
        json:
          name: 'joe'
          age: 10
          score: 95

      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'joe'
      expect(response.body.score).to.equal 95
      expect(response.body.age).to.equal 10

    it 'does not return the optional field if it is not included in the request body', fibrous ->
      model = @model.sync.create
        name: 'bob'
        age: 10

      response = @request.sync.put "/res/#{model._id}", json: {name: 'joe'}
      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'joe'
      expect(response.body.score).to.be.undefined
      expect(response.body.age).to.be.undefined

  given 'edge cases', ->
    describe 'default on mongoose model', ->
      withModel (mongoose) ->
        mongoose.Schema
          name: {type: String, default: 'foo'}

      withServer (app) ->
        @resource = new ResourceSchema @model, {'_id', 'name'}
        app.put '/bar/:_id', @resource.put('_id'), @resource.send

      it 'uses the mongoose schema defaults', fibrous ->
        _id = new mongoose.Types.ObjectId()
        response = @request.sync.put "/bar/#{_id}",
          json: {}
        expect(response.body).to.have.property '_id'
        expect(response.body).to.have.property 'name', 'foo'
