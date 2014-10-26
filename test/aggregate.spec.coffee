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

describe 'aggregate resource', ->

  describe '.index()', ->
    describe 'no search fields', ->
      before fibrous ->
        Model.sync.remove()
        Model.sync.create name: 'test1'
        Model.sync.create name: 'test1'
        Model.sync.create name: 'test1'
        Model.sync.create name: 'test2'
        response = request.sync.get
          url: 'http://127.0.0.1:4000/resource_aggregate',
          json: true

      it 'returns only the aggregate objects', ->
        expect(response.body.length).to.equal 2
        expect(response.body[1].name).to.equal 'test1'
        expect(response.body[0].name).to.equal 'test2'

      it 'returns aggregate operations (like sum)', ->
        expect(response.body.length).to.equal 2
        expect(response.body[1].total).to.equal 3
        expect(response.body[0].total).to.equal 1

    describe 'search fields', ->
      describe 'single search field', ->
        before fibrous ->
          Model.sync.remove()
          Model.sync.create name: 'test1'
          Model.sync.create name: 'test1'
          Model.sync.create name: 'test1'
          Model.sync.create name: 'test2'
          response = request.sync.get
            url: 'http://127.0.0.1:4000/resource_aggregate?name=test1',
            json: true

        it 'filters by the param', ->
          expect(response.body.length).to.equal 1
          expect(response.body[0].name).to.equal 'test1'
          expect(response.body[0].total).to.equal 3

    describe 'dynamic search field', ->
      {model} = {}
      before fibrous ->
        ParentModel.sync.remove()
        Model.sync.remove()
        model1 = Model.sync.create name: 'foo'
        model2 = Model.sync.create name: 'bar'
        model3 = Model.sync.create name: 'baz'
        parentModel = ParentModel.sync.create
          name: 'banana'
          modelIds: [model1._id, model2._id]

        response = request.sync.get
          url: 'http://127.0.0.1:4000/resource_aggregate?parentName=banana',
          json: true

      it 'returns only the specified fields in the dynamic search', fibrous ->
        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].name).to.equal 'foo'
        expect(response.body[1].name).to.equal 'bar'
    #
    # xdescribe 'dynamic get field', ->
    #   {model} = {}
    #   before fibrous ->
    #     ParentModel.sync.remove()
    #     Model.sync.remove()
    #     model1 = Model.sync.create name: 'foo'
    #     model2 = Model.sync.create name: 'bar'
    #     model3 = Model.sync.create name: 'baz'
    #     parentModel1 = ParentModel.sync.create
    #       name: 'banana'
    #       modelIds: [model1._id, model2._id]
    #     parentModel2 = ParentModel.sync.create
    #       name: 'orange'
    #       modelIds: [model3._id]
    #
    #   it 'returns all fields in the model', fibrous ->
    #     response = request.sync.get
    #       url: 'http://127.0.0.1:4000/resource',
    #       json: true
    #
    #     expect(response.statusCode).to.equal 200
    #     expect(response.body.length).to.equal 3
    #     expect(response.body[0].parentName).to.equal 'banana'
    #     expect(response.body[1].parentName).to.equal 'banana'
    #     expect(response.body[2].parentName).to.equal 'orange'
    #
    # describe '$limit', ->
    #   before fibrous ->
    #     Model.sync.remove()
    #     targetId = new mongoose.Types.ObjectId()
    #     Model.sync.create product: name: 'apples'
    #     Model.sync.create product: name: 'peaches'
    #     Model.sync.create product: name: 'bananas'
    #
    #     response = request.sync.get
    #       url: 'http://127.0.0.1:4000/resource?$limit=2',
    #       json: true
    #
    #   it 'limits the returned results', ->
    #     expect(response.body.length).to.equal 2
    #
    # describe '$select', ->
    #   describe 'single select', ->
    #     before fibrous ->
    #       Model.sync.remove()
    #       targetId = new mongoose.Types.ObjectId()
    #       Model.sync.create
    #         name: 'test'
    #         product: name: 'apples'
    #
    #       response = request.sync.get
    #         url: 'http://127.0.0.1:4000/resource?$select=name',
    #         json: true
    #
    #     it 'selects from the available resource fields', ->
    #       expect(response.body.length).to.equal 1
    #       expect(response.body[0].name).to.equal 'test'
    #       expect(response.body[0].product).to.be.undefined
    #
    #   describe 'nested select', ->
    #     before fibrous ->
    #       Model.sync.remove()
    #       targetId = new mongoose.Types.ObjectId()
    #       Model.sync.create
    #         name: 'test'
    #         product: price: 25
    #
    #       response = request.sync.get
    #         url: 'http://127.0.0.1:4000/resource',
    #         json: true
    #         qs: $select: 'product.price'
    #
    #     it 'selects from the available resource fields', ->
    #       expect(response.body.length).to.equal 1
    #       expect(response.body[0].name).to.be.undefined
    #       expect(response.body[0].product.price).to.equal 25
    #
    #   describe 'nested select', ->
    #     before fibrous ->
    #       Model.sync.remove()
    #       targetId = new mongoose.Types.ObjectId()
    #       Model.sync.create
    #         name: 'test'
    #         product: price: 25
    #
    #       response = request.sync.get
    #         url: "http://127.0.0.1:4000/resource?$select=product.price",
    #         json: true
    #
    #     it 'selects from the available resource fields', ->
    #       expect(response.body.length).to.equal 1
    #       expect(response.body[0].name).to.be.undefined
    #       expect(response.body[0].product.price).to.equal 25
    #
    #   describe 'multiple select', ->
    #     before fibrous ->
    #       Model.sync.remove()
    #       targetId = new mongoose.Types.ObjectId()
    #       Model.sync.create
    #         name: 'test'
    #         product:
    #           price: 25
    #           name: 'apples'
    #
    #       response = request.sync.get
    #         url: "http://127.0.0.1:4000/resource?$select[]=product.price&$select[]=productName",
    #         json: true
    #
    #
    #     it 'selects from the available resource fields', ->
    #       expect(response.body.length).to.equal 1
    #       expect(response.body[0].name).to.be.undefined
    #       expect(response.body[0].productName).to.equal 'apples'
    #       expect(response.body[0].product.price).to.equal 25
    #
    #   describe 'multiple select space syntax', ->
    #     before fibrous ->
    #       Model.sync.remove()
    #       targetId = new mongoose.Types.ObjectId()
    #       Model.sync.create
    #         name: 'test'
    #         product:
    #           price: 25
    #           name: 'apples'
    #
    #       response = request.sync.get
    #         url: "http://127.0.0.1:4000/resource",
    #         json: true
    #         qs: $select: 'product.price productName'
    #
    #
    #     it 'selects from the available resource fields', ->
    #       expect(response.body.length).to.equal 1
    #       expect(response.body[0].name).to.be.undefined
    #       expect(response.body[0].productName).to.equal 'apples'
    #       expect(response.body[0].product.price).to.equal 25
