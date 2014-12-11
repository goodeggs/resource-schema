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
        expect(response.body).to.equal "No resources found with _id of #{id}"

      it 'returns 400 if objectId not valid', fibrous ->
        response = @request.sync.get "/res/badId"
        expect(response.statusCode).to.equal 400
        expect(response.body).to.equal "Cast to ObjectId failed for value \"badId\" at path \"_id\""

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
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        model = Model.sync.create
          name: 'test'
          product: name: 'apples'

        response = request.sync.get
          url: "http://127.0.0.1:4000/resource/#{model._id}?$select=name",
          json: true

      it 'selects from the available resource fields', ->
        expect(response.statusCode).to.equal 200
        expect(response.body).to.deep.equal name: 'test'
        expect(response.body.product).to.be.undefined

    describe 'nested select', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        model = Model.sync.create
          name: 'test'
          product: price: 25

        response = request.sync.get
          url: "http://127.0.0.1:4000/resource/#{model._id}",
          json: true
          qs: $select: 'product.price'

      it 'selects from the available resource fields', ->
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.be.undefined
        expect(response.body.product.price).to.equal 25

    describe 'nested select', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        model = Model.sync.create
          name: 'test'
          product: price: 25

        response = request.sync.get
          url: "http://127.0.0.1:4000/resource/#{model._id}?$select=product.price",
          json: true

      it 'selects from the available resource fields', ->
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.be.undefined
        expect(response.body.product.price).to.equal 25

    describe 'multiple select', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        model = Model.sync.create
          name: 'test'
          product:
            price: 25
            name: 'apples'

        response = request.sync.get
          url: "http://127.0.0.1:4000/resource/#{model._id}?$select[]=product.price&$select[]=productName",
          json: true


      it 'selects from the available resource fields', ->
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.be.undefined
        expect(response.body.productName).to.equal 'apples'
        expect(response.body.product.price).to.equal 25

    describe 'multiple select space syntax', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        model = Model.sync.create
          name: 'test'
          product:
            price: 25
            name: 'apples'

        response = request.sync.get
          url: "http://127.0.0.1:4000/resource/#{model._id}",
          json: true
          qs: $select: 'product.price productName'


      it 'selects from the available resource fields', ->
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.be.undefined
        expect(response.body.productName).to.equal 'apples'
        expect(response.body.product.price).to.equal 25
