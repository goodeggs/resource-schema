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

describe '.index()', ->
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

    xdescribe 'invalid search field', ->
      before fibrous ->
        Model.sync.remove()
        targetId = new mongoose.Types.ObjectId()
        Model.sync.create product: name: 'apples'
        Model.sync.create product: name: 'peaches'

        response = request.sync.get
          url: 'http://127.0.0.1:4000/resource?productType=fruit',
          json: true

      it 'returns an empty array', ->
        expect(response.body.length).to.equal 0

  describe 'dynamic $find field', ->
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

    it 'returns only the specified fields in the dynamic search', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource?parentName=banana',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2
      expect(response.body[0].name).to.equal 'foo'
      expect(response.body[1].name).to.equal 'bar'

  describe 'dynamic $get field', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()
      model1 = Model.sync.create name: 'foo'
      model2 = Model.sync.create name: 'bar'
      model3 = Model.sync.create name: 'baz'
      parentModel1 = ParentModel.sync.create
        name: 'banana'
        modelIds: [model1._id, model2._id]
      parentModel2 = ParentModel.sync.create
        name: 'orange'
        modelIds: [model3._id]

    it 'returns all fields in the model', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 3
      expect(response.body[0].parentName).to.equal 'banana'
      expect(response.body[1].parentName).to.equal 'banana'
      expect(response.body[2].parentName).to.equal 'orange'

  describe 'second dynamic $get field', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()
      model1 = Model.sync.create name: 'foo'
      model2 = Model.sync.create name: 'bar'
      model3 = Model.sync.create name: 'baz'
      parentModel1 = ParentModel.sync.create
        name: 'banana'
        modelIds: [model1._id, model2._id]
      parentModel2 = ParentModel.sync.create
        name: 'orange'
        modelIds: [model3._id]

    it 'returns all fields in the model', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 3
      expect(response.body[0].secondGet).to.equal 'test'
      expect(response.body[1].secondGet).to.equal 'test'
      expect(response.body[2].secondGet).to.equal 'test'

  describe 'options.defaultQuery', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()

      # default limit is after 2014-10-05
      model1 = Model.sync.create
        name: 'foo'
        day: '2014-09-18'
      model2 = Model.sync.create
        name: 'bar'
        day: '2014-09-27'
      model3 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'

    it 'applies default query, if not overwritten', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 1
      expect(response.body[0].day).to.equal '2014-10-05'

  xdescribe 'options.queryParams', ->
    {model} = {}
    before fibrous ->
      Model.sync.remove()

      # default limit is after 2014-10-05
      model1 = Model.sync.create
        name: 'foo'
        day: '2014-09-18'
      model2 = Model.sync.create
        name: 'bar'
        day: '2014-09-27'
      model3 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'

    it 'applies default query, if not overwritten', fibrous ->
      console.log {count: Model.sync.count()}
      console.log {response: response.body}
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config?startDate=2014-09-27',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2

  describe 'options.defaultLimit', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()

      # default limit is after 2014-10-05
      model1 = Model.sync.create
        name: 'foo'
        day: '2014-10-05'
      model2 = Model.sync.create
        name: 'bar'
        day: '2014-10-05'
      model3 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'

    it 'uses default limit', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config',
        json: true


      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2

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
