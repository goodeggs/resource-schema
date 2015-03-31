fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
sinon = require 'sinon'
{suite, given} = require '../../support/helpers'

ResourceSchema = require '../../..'

suite 'PUT many', ({withModel, withServer}) ->
  given 'valid request', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res', @resource.put(), @resource.send
      app

    beforeEach fibrous ->
      model1 = @model.sync.create name: 'Eric Cartman'
      model1.name = 'Stan Marsh'
      model2 = @model.sync.create name: 'Kyle Broflovski'
      model2.name = 'Kenny McCormick'
      @response = @request.sync.put "/res", json: [model1, model2]

    it '200s with the updated resource', ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body.length).to.equal 2
      names = @response.body.map (model) -> model.name
      expect(names).to.contain 'Stan Marsh'
      expect(names).to.contain 'Kenny McCormick'

    it 'saves to the DB', fibrous ->
      modelsFound = @model.sync.find()
      expect(modelsFound.length).to.equal 2
      names = modelsFound.map (model) -> model.name
      expect(names).to.contain 'Stan Marsh'
      expect(names).to.contain 'Kenny McCormick'

  given 'PUT an empty array', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      schema = { '_id', 'name' }
      @resource = new ResourceSchema @model, schema

    withServer (app) ->
      app.put '/res', @resource.put(), @resource.send
      app

    beforeEach fibrous ->
      @response = @request.sync.put "/res", json: []

    it '200s with an empty array', ->
      expect(@response.statusCode).to.equal 200
      expect(@response.body).to.deep.equal []

  given 'default on mongoose model', ->
    withModel (mongoose) ->
      mongoose.Schema
        name: {type: String, default: 'foo'}

    withServer (app) ->
      @resource = new ResourceSchema @model, {'_id', 'name'}
      app.put '/bar', @resource.put(), @resource.send

    it 'uses the mongoose schema defaults', fibrous ->
      _id = new mongoose.Types.ObjectId()
      response = @request.sync.put "/bar",
        json: [{_id}]
      expect(response.body[0]).to.have.property '_id'
      expect(response.body[0]).to.have.property 'name', 'foo'

  given 'save hook on mongoose model', ->
    saveSpy = sinon.spy()

    withModel (mongoose) ->
      schema = mongoose.Schema
        name: String

      schema.pre 'save', (next) ->
        saveSpy()
        next()

    withServer (app) ->
      @resource = new ResourceSchema @model, {'_id', 'name'}
      app.put '/fruit', @resource.put(), @resource.send

    beforeEach fibrous ->
      @apple = @model.sync.create name: 'apple'
      @banana = @model.sync.create name: 'banana'
      saveSpy.reset()

    it 'calls the save hook for each resource', fibrous ->
      @request.sync.put "/fruit", json: [{_id: @apple._id}, {_id: @banana._id}]
      expect(saveSpy.callCount).to.equal 2
