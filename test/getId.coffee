sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model.coffee'
ParentModel = require './fixtures/parent_model.coffee'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

MongooseResource = require '..'

{response, model} = {}

describe '.get(id)', ->
  {model} = {}
  describe 'no params', ->
    before fibrous ->
      Model.sync.remove()
      model = Model.sync.create name: 'test'
      ParentModel.sync.create
        name: 'parent'
        modelIds: [model._id]

    it 'returns the object if found', fibrous ->
      response = request.sync.get
        url: "http://127.0.0.1:4000/resource/#{model._id}"
        json: true
      expect(response.statusCode).to.equal 200
      expect(response.body.name).to.equal 'test'

    it 'returns the dynamic get value', fibrous ->
      response = request.sync.get
        url: "http://127.0.0.1:4000/resource/#{model._id}"
        json: true
      expect(response.statusCode).to.equal 200
      expect(response.body.parentName).to.equal 'parent'

    it 'returns 404 if object not found', fibrous ->
      response = request.sync.get
        url: "http://127.0.0.1:4000/resource/#{new mongoose.Types.ObjectId()}"
        json: true
      expect(response.statusCode).to.equal 404

    it 'returns 400 if objectId not valid', fibrous ->
      response = request.sync.get
        url: "http://127.0.0.1:4000/resource/1234"
        json: true
      expect(response.statusCode).to.equal 400

  describe '$select', ->
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
