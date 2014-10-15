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
    describe 'no search fields', ->
      before fibrous ->
        Model.sync.remove()
        Model.sync.create name: 'test'
        response = request.sync.get
          url: 'http://127.0.0.1:4000/model_resource',
          json: true

      it 'returns an array of objects', ->
        expect(response.body.length).to.equal 1
        expect(response.body[0].name).to.equal 'test'

    describe 'search fields', ->
      describe 'single search field', ->
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

      describe 'nested search field', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create product: price: 20
          Model.sync.create product: price: 25

          response = request.sync.get
            url: 'http://127.0.0.1:4000/model_resource?product[price]=25',
            json: true

        it 'filters by the field', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].product.price).to.equal 25

      describe 'renamed search field', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create product: name: 'apples'
          Model.sync.create product: name: 'peaches'

          response = request.sync.get
            url: 'http://127.0.0.1:4000/model_resource?productName=apples',
            json: true

        it 'filters by the field, and returns the resource with the renamed field', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].productName).to.equal 'apples'

    describe '$limit', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        Model.sync.create product: name: 'apples'
        Model.sync.create product: name: 'peaches'
        Model.sync.create product: name: 'bananas'

        response = request.sync.get
          url: 'http://127.0.0.1:4000/model_resource?$limit=2',
          json: true

      it 'limits the returned results', ->
        expect(response.body.length).to.equal 2

    describe '$select', ->
      describe 'single select', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create
            name: 'test'
            product: name: 'apples'

          response = request.sync.get
            url: 'http://127.0.0.1:4000/model_resource?$select=name',
            json: true

        it 'selects from the available resource fields', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].name).to.equal 'test'
          expect(response.body[0].product).to.be.undefined

      describe 'nested select', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create
            name: 'test'
            product: price: 25

          response = request.sync.get
            url: 'http://127.0.0.1:4000/model_resource',
            json: true
            qs: $select: 'product.price'

        it 'selects from the available resource fields', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].name).to.be.undefined
          expect(response.body[0].product.price).to.equal 25

      describe 'nested select', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create
            name: 'test'
            product: price: 25

          response = request.sync.get
            url: "http://127.0.0.1:4000/model_resource?$select=product.price",
            json: true

        it 'selects from the available resource fields', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].name).to.be.undefined
          expect(response.body[0].product.price).to.equal 25

      describe 'multiple select', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create
            name: 'test'
            product:
              price: 25
              name: 'apples'

          response = request.sync.get
            url: "http://127.0.0.1:4000/model_resource?$select[]=product.price&$select[]=productName",
            json: true


        it 'selects from the available resource fields', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].name).to.be.undefined
          expect(response.body[0].productName).to.equal 'apples'
          expect(response.body[0].product.price).to.equal 25

      describe 'multiple select space syntax', ->
        before fibrous ->
          Model.sync.remove()
          targetId = new mongoose.Types.ObjectId()
          Model.sync.create
            name: 'test'
            product:
              price: 25
              name: 'apples'

          response = request.sync.get
            url: "http://127.0.0.1:4000/model_resource",
            json: true
            qs: $select: 'product.price productName'


        it 'selects from the available resource fields', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].name).to.be.undefined
          expect(response.body[0].productName).to.equal 'apples'
          expect(response.body[0].product.price).to.equal 25
