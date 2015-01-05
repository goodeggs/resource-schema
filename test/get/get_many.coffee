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

{response, model} = {}

suite 'GET many', ({withModel, withServer}) ->
  describe 'with a simple resource', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      @resource = new ResourceSchema @model

    withServer (app) ->
      app.get '/res/', @resource.get(), @resource.send
      app

    it 'returns all of the objects', fibrous ->
      [0...10].forEach (i) => @model.sync.create name: "model_#{i}"
      response = @request.sync.get '/res/'
      expect(response.body.length).to.equal 10
      expect(response.body[0].name).to.equal 'model_0'

    it 'filters by a param', fibrous ->
      [0...10].forEach => @model.sync.create name: 'one'
      [0...10].forEach => @model.sync.create name: 'two'
      response = @request.sync.get '/res?name=one'
      expect(response.body.length).to.equal 10
      expect(response.body[0].name).to.equal 'one'

    it 'returns 400 if the supplied param is invalid', fibrous ->
      response = @request.sync.get '/res?_id=badId'
      expect(response.statusCode).to.equal 400
      expect(response.body).to.deep.equal
        statusCode: 400
        error: 'Bad Request'
        message: "'badId' is an invalid ObjectId for field '_id'"

  describe 'default limit', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach ->
      @resource = new ResourceSchema @model

    withServer (app) ->
      app.get '/res/', @resource.get(), @resource.send
      app

    it 'sets a default limit of 1000', fibrous ->
      [0...1050].forEach (i) => @model.sync.create name: "model_#{i}"
      response = @request.sync.get '/res/'
      expect(response.body.length).to.equal 1000

  describe 'optional: [Boolean]', ->
    before fibrous ->
      Model.sync.remove()
      targetId = new mongoose.Types.ObjectId()
      Model.sync.create
        name: 'test1'
        productCount: 5
      Model.sync.create
        name: 'test2'
        productCount: 3

    it 'adds optional field with add query parameter', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource?$add=productCount',
        json: true
      expect(response.body.length).to.equal 2
      expect(response.body[0].productCount).to.equal 5
      expect(response.body[1].productCount).to.equal 3

    it 'adds optional get field with $add query parameter', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource?$add=weeklyProductCount',
        json: true
      expect(response.body.length).to.equal 2
      expect(response.body[0].weeklyProductCount).to.equal 10
      expect(response.body[1].weeklyProductCount).to.equal 10

    it 'ignores optional get field if no $add query parameter', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource',
        json: true
      expect(response.body.length).to.equal 2
      expect(response.body[0].weeklyProductCount).to.be.undefined
      expect(response.body[1].weeklyProductCount).to.be.undefined

    it 'ignores optional field if no $add query parameter', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource',
        json: true
      expect(response.body.length).to.equal 2
      expect(response.body[0].productCount).to.be.undefined
      expect(response.body[1].productCount).to.be.undefined


  describe 'default filter', ->
    withModel (mongoose) ->
      mongoose.Schema name: String

    beforeEach fibrous ->
      @model.sync.create name: 'hello'
      @model.sync.create name: 'bad'
      @model.sync.create name: 'goodbye'

      @resource = new ResourceSchema @model, {'name'},
        filter: (documents) ->
          documents.filter ({name}) ->
            name isnt 'bad'

    withServer (app) ->
      app.get '/res', @resource.get(), @resource.send

    it 'filters out unwanted documents by default', fibrous ->
      response = @request.sync.get '/res'
      expect(response.body).to.deep.equal [
        {name: 'hello'}
        {name: 'goodbye'}
      ]

  describe 'filter: [Function]', ->
    before fibrous ->
      Model.sync.remove()
      Model.sync.create
        product: price: 10
      Model.sync.create
        product: price: 15
      Model.sync.create
        product: price: 20

    it 'filters by the correct values', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_with_query_params?minPrice=12',
        json: true

      expect(response.body.length).to.equal 2
      expect(response.body[0].product.price).to.equal 15
      expect(response.body[1].product.price).to.equal 20

  describe 'falsy value in model', ->
    describe 'single search field', ->
      before fibrous ->
        Model.sync.remove()
        Model.sync.create name: ''

        response = request.sync.get
          url: 'http://127.0.0.1:4000/resource',
          json: true

      it 'filters by the param', ->
        expect(response.body.length).to.equal 1
        expect(response.body[0].name).to.equal ''

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

  describe 'find: [Function]', ->
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

  describe 'get: [Function]', ->
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

  describe 'get nested field', ->
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()
      model1 = Model.sync.create name: 'foo'

    it 'returns the nested field as a normal object (not a dot string)', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 1
      expect(response.body[0].nested.dynamicValue).to.equal 2

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
      expect(response.body.length).to.equal 2
      expect(response.body[0].day).to.equal '2014-09-27'
      expect(response.body[1].day).to.equal '2014-10-05'

  describe 'options.resolve', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()

      # default limit is after 2014-10-05
      @model = Model.sync.create
        name: 'foo'
        day: '2014-09-18'
      @parentModel = ParentModel.sync.create
        name: 'parent'
        modelIds: [@model._id]

    it 'applies the resolve to all getters and setters', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 1
      expect(response.body[0].parentId).to.equal @parentModel._id.toString()

  describe 'options.queryParams', ->
    {model} = {}
    before fibrous ->
      Model.sync.remove()

      # default limit is after 2014-09-18
      model1 = Model.sync.create
        name: 'foo'
        day: '2014-09-18'
      model2 = Model.sync.create
        name: 'bar'
        day: '2014-09-27'
      model3 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'
      model4 = Model.sync.create
        name: 'lu'
        day: '2014-10-09'
      model5 = Model.sync.create
        name: 'la'
        day: '2014-10-15'

    it 'applies default query, if not overwritten', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 4
      expect(response.body[0].day).to.equal '2014-09-27'
      expect(response.body[1].day).to.equal '2014-10-05'
      expect(response.body[2].day).to.equal '2014-10-09'
      expect(response.body[3].day).to.equal '2014-10-15'

    it 'overwrites the default query', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config?startDate=2014-10-06',
        json: true
      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2
      expect(response.body[0].day).to.equal '2014-10-09'
      expect(response.body[1].day).to.equal '2014-10-15'

    it 'queries for arrays (still including the default query)', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config?containsDays=2014-09-18&containsDays=2014-10-05&containsDays=2014-10-15',
        json: true

      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2
      expect(response.body[0].day).to.equal '2014-10-05'
      expect(response.body[1].day).to.equal '2014-10-15'

  describe 'with a query parameter', ->
    withModel (mongoose) ->
      mongoose.Schema day: String

    beforeEach ->
      @resource = new ResourceSchema @model, {'day'}, queryParams:
        after:
          type: String
          validate: (value) ->
            /\d{4}-\d{2}-\d{2}/.test(value)
          find: (value) ->
            day: $gte: value

    withServer (app) ->
      app.get '/res/', @resource.get(), @resource.send
      app

    it 'returns a 400 if the query parameter is invalid', fibrous ->
      response = @request.sync.get '/res/?after=20141006'
      expect(response.statusCode).to.equal 400

  describe 'with an array query parameter', ->
    withModel (mongoose) ->
      mongoose.Schema day: String

    beforeEach ->
      weekdayMap =
        Mo: '2014-12-01'
        Tu: '2014-12-02'
        We: '2014-12-03'
        Th: '2014-12-04'
        Fr: '2014-12-05'
      @resource = new ResourceSchema @model, {'day'}, queryParams:
        weekdays:
          type: String
          isArray: true
          validate: (weekday) ->
            weekday in Object.keys weekdayMap
          find: (weekdays) ->
            day: $in: (weekdayMap[weekday] for weekday in weekdays)

    withServer (app) ->
      app.get '/res/', @resource.get(), @resource.send
      app

    it 'returns a 400 if the query parameter is invalid', fibrous ->
      response = @request.sync.get '/res/?weekdays=Mo&weekdays=Su'
      expect(response.statusCode).to.equal 400

  describe 'options.defaultLimit', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()

      # default limit 6
      model1 = Model.sync.create
        name: 'foo'
        day: '2014-10-05'
      model2 = Model.sync.create
        name: 'bar'
        day: '2014-10-05'
      model3 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'
      model4 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'
      model5 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'
      model6 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'
      model7 = Model.sync.create
        name: 'baz'
        day: '2014-10-05'

    it 'uses default limit', fibrous ->
      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_config',
        json: true


      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 6

  describe 'limit', ->
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

  describe 'select', ->
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
