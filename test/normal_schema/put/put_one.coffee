fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
mongoose = require 'mongoose'
sinon = require 'sinon'
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

  given 'default on mongoose model', ->
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

  given 'save hooks on mongoose model', ->
    saveSpy = sinon.spy()

    withModel (mongoose) ->
      schema = mongoose.Schema
        name: String

      schema.pre 'save', (next) ->
        saveSpy()
        next()

    withServer (app) ->
      @resource = new ResourceSchema @model, {'_id', 'name'}
      app.put '/fruit/:_id', @resource.put('_id'), @resource.send

    beforeEach fibrous ->
      @apple = @model.sync.create name: 'apple'
      saveSpy.reset()

    it 'calls the save hook', fibrous ->
      @request.sync.put "/fruit/#{@apple._id}", json: {name: 'orange'}
      expect(saveSpy.callCount).to.equal 1

  given 'schema with nested requires', ->
    saveSpy = sinon.spy()

    withModel (mongoose) ->
      mongoose.Schema
        name: String
        siblings: [
          name: String
          age: type: Number, required: true
        ]

    withServer (app) ->
      @resource = new ResourceSchema @model, {'_id', 'name', 'siblings'}
      app.put '/person/:_id', @resource.put('_id'), @resource.send

    beforeEach fibrous ->
      @michael = @model.sync.create name: 'Michael', siblings: [
        {name: 'Matthew', age: 33},
        {name: 'Jon', age: 38}
      ]

    it 'allows you to remove and update items in the array', fibrous ->
      response = @request.sync.put "/person/#{@michael._id}", json: {siblings: [{name: 'Jon', age:39, _id: @michael.siblings[1]._id}]}
      expect(response.statusCode).to.equal 200

  given 'mongoose model field with default is already set, and resource does not contain the field', ->
    withModel (mongoose) ->
      mongoose.Schema
        name: String
        # mongoose arrays default to an empty array
        siblings: [
          name: String
          age: type: Number, required: true
        ]

    withServer (app) ->
      # resource does not contain the array...
      @resource = new ResourceSchema @model, {'_id', 'name'}
      app.put '/person/:_id', @resource.put('_id'), @resource.send

    beforeEach fibrous ->
      @michael = @model.sync.create name: 'Michael', siblings: [
        {name: 'Matthew', age: 33},
        {name: 'Jon', age: 38}
      ]

    it 'does not overwrite the model value with the default value', fibrous ->
      response = @request.sync.put "/person/#{@michael._id}",
        json:
          name: 'Max'
      expect(response.statusCode).to.equal 200
      model = @model.sync.findById @michael._id
      # the array still has both items (it was not overwritten with an empty array)
      expect(model.siblings).to.have.length 2

