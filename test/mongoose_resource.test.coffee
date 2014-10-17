sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model.coffee'
unionizedMongoose = require 'unionized-mongoose'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

MongooseResource = require '..'

describe 'resource-schema', ->
  {response, model} = {}

  describe 'default model provided', ->

    describe '.query()', ->
      describe 'no search fields', ->
        before fibrous ->
          Model.sync.remove()
          Model.sync.create name: 'test'
          response = request.sync.get
            url: 'http://127.0.0.1:4000/resource',
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
              url: 'http://127.0.0.1:4000/resource?name=test1',
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
              url: 'http://127.0.0.1:4000/resource?product[price]=25',
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
              url: 'http://127.0.0.1:4000/resource?productName=apples',
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
            url: 'http://127.0.0.1:4000/resource?$limit=2',
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
              url: 'http://127.0.0.1:4000/resource?$select=name',
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
              url: 'http://127.0.0.1:4000/resource',
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
              url: "http://127.0.0.1:4000/resource?$select=product.price",
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
              url: "http://127.0.0.1:4000/resource?$select[]=product.price&$select[]=productName",
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
              url: "http://127.0.0.1:4000/resource",
              json: true
              qs: $select: 'product.price productName'


          it 'selects from the available resource fields', ->
            expect(response.body.length).to.equal 1
            expect(response.body[0].name).to.be.undefined
            expect(response.body[0].productName).to.equal 'apples'
            expect(response.body[0].product.price).to.equal 25

    describe '.get()', ->
      {model} = {}
      describe 'no params', ->
        before fibrous ->
          Model.sync.remove()
          model = Model.sync.create name: 'test'

        it 'returns the object if found', fibrous ->
          response = request.sync.get
            url: "http://127.0.0.1:4000/resource/#{model._id}"
            json: true
          expect(response.statusCode).to.equal 200
          expect(response.body.name).to.equal 'test'

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
            expect(response.body.name).to.equal 'test'
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

    describe '.save()', ->
      before fibrous ->
        Model.sync.remove()

        response = request.sync.post
          url: "http://127.0.0.1:4000/resource"
          json:
            name: 'test'
            productName: 'apples'
            product: price: 25

      it 'returns the saved resource', ->
        expect(response.statusCode).to.equal 201
        expect(response.body.name).to.equal 'test'
        expect(response.body.productName).to.equal 'apples'
        expect(response.body.product.price).to.equal 25
        expect(response.body._id).to.be.ok

      it 'saves to the DB, in the model schema', fibrous ->
        modelsFound = Model.sync.find()
        expect(modelsFound.length).to.equal 1
        expect(modelsFound[0].product.name).to.equal 'apples'
        expect(modelsFound[0].product.price).to.equal 25
        expect(modelsFound[0].name).to.equal 'test'

    describe '.update("paramVariableName")', ->
      before fibrous ->
        Model.sync.remove()
        model = Model.sync.create
          name: 'test'
          product:
            name: 'apples'
            price: 25

        response = request.sync.put
          url: "http://127.0.0.1:4000/resource/#{model._id}"
          json:
            name: 'test'
            productName: 'berries'
            product: price: 25

      it 'returns the updated resource', ->
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.equal 'test'
        expect(response.body.productName).to.equal 'berries'
        expect(response.body.product.price).to.equal 25
        expect(response.body._id).to.be.ok

      it 'saves to the DB, in the model schema', fibrous ->
        modelsFound = Model.sync.find()
        expect(modelsFound.length).to.equal 1
        expect(modelsFound[0].product.name).to.equal 'berries'
        expect(modelsFound[0].product.price).to.equal 25
        expect(modelsFound[0].name).to.equal 'test'

  describe 'no default model provided', ->
    describe '.get()', ->
      {model} = {}
      before fibrous ->
        Model.sync.remove()
        model = Model.sync.create
          name: 'test'
          product:
            name: 'apples'
            price: 25

      it 'returns all fields in the model', fibrous ->
        response = request.sync.get
          url: "http://127.0.0.1:4000/resource_no_schema/#{model._id}"
          json: true
        expect(response.statusCode).to.equal 200
        expect(response.body.name).to.equal 'test'
        expect(response.body.product.name).to.equal 'apples'
        expect(response.body.product.price).to.equal 25
