{suite, given} = require '../../support/helpers'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
sinon = require 'sinon'

ResourceSchema = require '../../..'

suite 'GET one', ({withModel, withServer}) ->
  given 'no params', ->
    describe 'with a simple resource', ->
      withModel (mongoose) ->
        mongoose.Schema name: String

      beforeEach ->
        @resource = new ResourceSchema @model

      withServer (app) ->
        app.get '/res/:_id', @resource.get('_id'), @resource.send
        app

      it 'returns the object if found', fibrous ->
        model = @model.sync.create name: 'test'
        response = @request.sync.get "/res/#{model._id}"
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.equal 'test'

      it 'returns 404 if object not found', fibrous ->
        id = new mongoose.Types.ObjectId()
        response = @request.sync.get "/res/#{id}"
        expect(response.statusCode).to.equal 404
        expect(response.body).to.deep.equal
          statusCode: 404
          error: 'Not Found'
          message: "No resources found with _id of #{id}"

      it 'returns 400 if objectId not valid', fibrous ->
        response = @request.sync.get "/res/badId"
        expect(response.statusCode).to.equal 400
        expect(response.body).to.deep.equal
          statusCode: 400
          error: 'Bad Request'
          message: "'badId' is an invalid ObjectId for field '_id'"

      it 'returns 500 if there are issues querying the database', fibrous ->
        sinon.stub(@model, 'findOne').throws()
        response = @request.sync.get "/res/#{mongoose.Types.ObjectId()}"
        @model.findOne.restore()
        expect(response.statusCode).to.equal 500

    describe 'with a resource that has a synchronous dynamic field', ->
      withModel (mongoose) ->
        mongoose.Schema name: String

      beforeEach ->
        schema = {
          '_id'
          'name'
          extra:
            get: (model) -> "Hello there #{model.name}!"
        }
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/res/:_id', @resource.get('_id'), @resource.send
        app

      it 'returns the dynamic get value', fibrous ->
        model = @model.sync.create name: 'test'
        response = @request.sync.get "/res/#{model._id}"
        expect(response.statusCode).to.equal 200
        expect(response.body.extra).to.equal 'Hello there test!'

  given '$select', ->
    {response, model} = {}

    describe 'single select', ->
      withModel (mongoose) ->
        mongoose.Schema
          name: String
          active: Boolean

      beforeEach ->
        schema = { 'name', 'active' }
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/res/:_id', @resource.get('_id'), @resource.send
        app

      it 'selects given resource field', fibrous ->
        model = @model.sync.create { name: 'test', active: true }
        response = @request.sync.get "/res/#{model._id}?$select=name"
        expect(response.statusCode).to.equal 200
        expect(response.body).to.deep.equal name: 'test'
        expect(response.body.product).to.be.undefined

    describe 'nested select', ->
      withModel (mongoose) ->
        mongoose.Schema
          product:
            name: String
            price: Number

      beforeEach ->
        schema = { 'product.name', 'product.price' }
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/res/:_id', @resource.get('_id'), @resource.send
        app

      it 'selects from the available resource fields', fibrous ->
        model = @model.sync.create { product: { name: 'test', price: 2.99 } }
        response = @request.sync.get "/res/#{model._id}?$select=product.price"
        expect(response.statusCode).to.equal 200
        expect(response.body).to.deep.equal {product: {price: 2.99}}

    describe 'multiple select', ->
      withModel (mongoose) ->
        mongoose.Schema
          product:
            name: String
            unit: String
            price: Number

      beforeEach ->
        schema = { 'product.name', 'product.price', 'product.unit'  }
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/res/:_id', @resource.get('_id'), @resource.send
        app

      it 'selects from the available resource fields', fibrous ->
        model = @model.sync.create { product: { name: 'apple', price: 2.99, unit: 'bag'} }
        response = @request.sync.get "/res/#{model._id}?$select=product.price&$select=product.name"
        expect(response.statusCode).to.equal 200
        expect(response.body).to.deep.equal {product: {price: 2.99, name: 'apple'}}

    describe 'multiple select space syntax', ->
      withModel (mongoose) ->
        mongoose.Schema
          name: String
          unit: String
          price: Number

      beforeEach ->
        schema = { 'name', 'price', 'unit'  }
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/res/:_id', @resource.get('_id'), @resource.send
        app

      it 'selects from the available resource fields', fibrous ->
        model = @model.sync.create { name: 'apple', price: 2.99, unit: 'bag'}
        response = @request.sync.get "/res/#{model._id}?$select=price%20name"
        expect(response.statusCode).to.equal 200
        expect(response.body).to.deep.equal {price: 2.99, name: 'apple'}

  given 'edge cases', ->
    describe 'default on mongoose model', ->
      withModel (mongoose) ->
        mongoose.Schema
          name: {type: String, default: 'foo'}

      withServer (app) ->
        @resource = new ResourceSchema @model, {'_id', 'name'}
        app.get '/bar/:_id', @resource.get('_id'), @resource.send

      it 'uses the mongoose schema defaults', fibrous ->
        _id = new mongoose.Types.ObjectId()
        @model.collection.sync.insert {_id}
        response = @request.sync.get "/bar/#{_id}"
        expect(response.body).to.have.property '_id'
        expect(response.body).to.have.property 'name', 'foo'
