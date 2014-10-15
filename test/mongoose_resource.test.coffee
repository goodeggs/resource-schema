sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model.coffee'
unionizedMongoose = require 'unionized-mongoose'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

MongooseResource = require '..'

describe 'mongoose-resource', ->
  {response} = {}

  describe '.query()', ->
    describe 'no query params', ->
      before fibrous ->
        Model.sync.remove()
        Model.sync.create name: 'test'
        response = request.sync.get
          url: 'http://127.0.0.1:4000/model_resource',
          json: true

      it 'returns an array of objects', ->
        expect(response.body.length).to.equal 1
        expect(response.body[0].name).to.equal 'test'

    describe 'single query param', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        Model.sync.create name: 'test1'
        Model.sync.create name: 'test2'

        response = request.sync.get
          url: 'http://127.0.0.1:4000/model_resource?name=test1',
          json: true

      it 'filters by the param', ->
        expect(response.body.length).to.equal 1
        expect(response.body[0].name).to.equal 'test1'

    describe 'nested query param', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        Model.sync.create product: value: 20
        Model.sync.create product: value: 25

        response = request.sync.get
          url: 'http://127.0.0.1:4000/model_resource?product[price]=25',
          json: true

      it 'filters by the param', ->
        expect(response.body.length).to.equal 1
        expect(response.body[0].product.price).to.equal 25
