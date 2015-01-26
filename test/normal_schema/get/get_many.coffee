fibrous = require 'fibrous'
mongoose = require 'mongoose'
expect = require('chai').expect
{suite, given} = require '../../support/helpers'
ResourceSchema = require '../../..'

suite 'GET many', ({withModel, withServer}) ->
  describe 'basic schema', ->
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

  describe 'schema properties', ->
    describe 'get', ->
      withModel (mongoose) ->
        mongoose.Schema
          firstName: String
          lastName: String

      beforeEach fibrous ->
        @model.sync.create
          firstName: 'eric'
          lastName: 'cartman'

        @model.sync.create
          firstName: 'kyle'
          lastName: 'broflovski'

        schema =
          'firstName': 'firstName'
          'lastName': 'lastName'
          'fullName':
            get: (employee) ->
              employee.firstName + ' ' + employee.lastName

        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/employees', @resource.get(), @resource.send

      it 'returns all fields in the model', fibrous ->
        response = @request.sync.get
          url: '/employees',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].fullName).to.equal 'eric cartman'
        expect(response.body[1].fullName).to.equal 'kyle broflovski'

    describe 'find', ->
      withModel (mongoose) ->
        mongoose.Schema
          price: Number

      beforeEach fibrous ->
        @model.sync.create price: 10
        @model.sync.create price: 20
        @model.sync.create price: 27
        schema =
          'price': 'price'
          'minPrice':
            find: (value) ->
              'price': {$gt: value}

        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/products', @resource.get(), @resource.send

      it 'queries with the finder', fibrous ->
        response = @request.sync.get
          url: '/products?minPrice=15',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].price).to.equal 20
        expect(response.body[1].price).to.equal 27

    describe 'filter', ->
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
        withModel (mongoose) ->
          mongoose.Schema
            price: Number

        beforeEach fibrous ->
          @model.sync.create price: 20
          @model.sync.create price: 27
          @model.sync.create price: 10

          schema =
            'price': 'price'
            'minPrice':
              filter: (value, documents) ->
                documents.filter (document) ->
                  document?.price > value

          @resource = new ResourceSchema @model, schema

        withServer (app) ->
          app.get '/products', @resource.get(), @resource.send

        it 'filters by the correct values', fibrous ->
          response = @request.sync.get
            url: '/products?minPrice=12',
            json: true

          expect(response.body.length).to.equal 2
          expect(response.body[0].price).to.equal 20
          expect(response.body[1].price).to.equal 27

    describe 'optional', ->
      withModel (mongoose) ->
        mongoose.Schema
          name: String
          calories: Number

      beforeEach ->
        schema =
          'name': 'name'
          'calories':
            optional: true
            field: 'calories'
          'isDelicious':
            optional: true
            get: -> true
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/foods', @resource.get(), @resource.send
        app

      beforeEach fibrous ->
        targetId = new mongoose.Types.ObjectId()
        @model.sync.create
          name: 'chocolate'
          calories: 5000
        @model.sync.create
          name: 'truffle'
          calories: 3000

      it 'excludes optional fields when no $add query parameter', fibrous ->
        response = @request.sync.get
          url: '/foods',
          json: true
        expect(response.body.length).to.equal 2
        expect(response.body[0].calories).to.be.undefined
        expect(response.body[0].isDelicious).to.be.undefined
        expect(response.body[1].calories).to.be.undefined
        expect(response.body[1].isDelicious).to.be.undefined

      it 'adds optional field with add query parameter', fibrous ->
        response = @request.sync.get
          url: '/foods?$add=calories',
          json: true
        expect(response.body.length).to.equal 2
        expect(response.body[0].calories).to.equal 5000
        expect(response.body[1].calories).to.equal 3000

      it 'adds optional get: field with $add query parameter', fibrous ->
        response = @request.sync.get
          url: '/foods?$add=isDelicious',
          json: true
        expect(response.body.length).to.equal 2
        expect(response.body[0].isDelicious).to.equal true
        expect(response.body[1].isDelicious).to.equal true

    describe 'validate', ->
      describe 'invalid query paramter', ->
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

      describe 'invalid array query parameter', ->
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

  describe 'query parameters', ->
    describe '$limit', ->
      withModel (mongoose) ->
        mongoose.Schema { name: String }

      beforeEach fibrous ->
        @model.sync.create { name: 'Bilbo' }
        @model.sync.create { name: 'Frodo' }
        @model.sync.create { name: 'Mary' }
        @model.sync.create { name: 'Pippin' }

        schema = { 'name' }
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/characters', @resource.get(), @resource.send

      it 'limits the returned results', fibrous ->
        response = @request.sync.get
          url: '/characters?$limit=2',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2

    describe '$select', ->
      describe 'normal field', ->
        withModel (mongoose) ->
          mongoose.Schema { name: String, weapon: String }

        beforeEach fibrous ->
          @model.sync.create { name: 'Frodo', weapon: 'dagger' }
          @model.sync.create { name: 'Aaragorn', weapon: 'sword' }

          schema = { 'name', 'weapon' }
          @resource = new ResourceSchema @model, schema

        withServer (app) ->
          app.get '/characters', @resource.get(), @resource.send

        it 'selects from the available resource fields', fibrous ->
          response = @request.sync.get
            url: '/characters?$select=name',
            json: true
          expect(response.body.length).to.equal 2
          expect(response.body[0].name).to.equal 'Frodo'
          expect(response.body[0].weapon).to.be.undefined

      describe 'nested field', ->
        withModel (mongoose) ->
          mongoose.Schema info: { name: String, weapon: String }

        beforeEach fibrous ->
          @model.sync.create info: { name: 'Frodo', weapon: 'dagger' }
          @model.sync.create info: { name: 'Aaragorn', weapon: 'sword' }

          schema = { 'info.name', 'info.weapon' }
          @resource = new ResourceSchema @model, schema

        withServer (app) ->
          app.get '/characters', @resource.get(), @resource.send

        it 'selects from the available resource fields', fibrous ->
          response = @request.sync.get
            url: '/characters?$select=info.name',
            json: true
          expect(response.body.length).to.equal 2
          expect(response.body[0].info.name).to.equal 'Frodo'
          expect(response.body[0].info.weapon).to.be.undefined

      describe 'multiple fields', ->
        withModel (mongoose) ->
          mongoose.Schema { name: String, weapon: String, age: Number }

        beforeEach fibrous ->
          @model.sync.create { name: 'Frodo', weapon: 'dagger', age: 50 }
          @model.sync.create { name: 'Aaragorn', weapon: 'sword', age: 87 }

          schema = { 'name', 'weapon', 'age' }
          @resource = new ResourceSchema @model, schema

        withServer (app) ->
          app.get '/characters', @resource.get(), @resource.send

        it 'selects from the available resource fields', fibrous ->
          response = @request.sync.get
            url: '/characters?$select=name&$select=age',
            json: true
          expect(response.body.length).to.equal 2
          expect(response.body[0].name).to.equal 'Frodo'
          expect(response.body[0].weapon).to.be.undefined
          expect(response.body[0].age).to.equal 50

        it 'selects from the available resource fields (space syntax)', fibrous ->
          response = @request.sync.get
            url: '/characters?$select=name age',
            json: true
          expect(response.body.length).to.equal 2
          expect(response.body[0].name).to.equal 'Frodo'
          expect(response.body[0].weapon).to.be.undefined
          expect(response.body[0].age).to.equal 50

    describe 'querying by schema fields', ->
      describe 'normal field', ->
        withModel (mongoose) ->
          mongoose.Schema name: String

        beforeEach ->
          @resource = new ResourceSchema @model

        withServer (app) ->
          app.get '/numbers', @resource.get(), @resource.send
          app

        it 'filters by a param', fibrous ->
          [0...10].forEach => @model.sync.create name: 'one'
          [0...10].forEach => @model.sync.create name: 'two'
          response = @request.sync.get '/numbers?name=one'
          expect(response.body.length).to.equal 10
          expect(response.body[0].name).to.equal 'one'

        it 'returns 400 if the supplied param is invalid', fibrous ->
          response = @request.sync.get '/numbers?_id=badId'
          expect(response.statusCode).to.equal 400
          expect(response.body).to.deep.equal
            statusCode: 400
            error: 'Bad Request'
            message: "'badId' is an invalid ObjectId for field '_id'"

      describe 'nested field', ->
        withModel (mongoose) ->
          mongoose.Schema
            product:
              price: Number

        beforeEach fibrous ->
          @model.sync.create product: price: 20
          @model.sync.create product: price: 27
          schema = {'product.price'}
          @resource = new ResourceSchema @model, schema

        withServer (app) ->
          app.get '/products', @resource.get(), @resource.send

        beforeEach fibrous ->
          @response = @request.sync.get
            url: '/products?product[price]=27',
            json: true

        it 'queries by the field', ->
          expect(@response.body.length).to.equal 1
          expect(@response.body[0].product.price).to.equal 27

      describe 'renamed field', ->
        withModel (mongoose) ->
          mongoose.Schema
            product:
              price: Number

        beforeEach fibrous ->
          @model.sync.create product: price: 20
          @model.sync.create product: price: 27
          schema = {'productPrice': 'product.price'}
          @resource = new ResourceSchema @model, schema

        withServer (app) ->
          app.get '/products', @resource.get(), @resource.send

        it 'filters by the field, and returns the resource with the renamed field', fibrous  ->
          response = @request.sync.get
            url: '/products?productPrice=27',
            json: true
          expect(response.body.length).to.equal 1
          expect(response.body[0].productPrice).to.equal 27

  describe 'options', ->
    describe 'defaultQuery', ->
      withModel (mongoose) ->
        mongoose.Schema
          price: Number
          active: Boolean

      beforeEach fibrous ->
        @model.sync.create
          price: 10
          active: true
        @model.sync.create
          price: 20
          active: true
        @model.sync.create
          price: 27
          active: false

        schema = { 'price' }
        options = defaultQuery: { active: true }
        @resource = new ResourceSchema @model, schema, options

      withServer (app) ->
        app.get '/products', @resource.get(), @resource.send

      it 'applies default query, if not overwritten', fibrous ->
        response = @request.sync.get
          url: '/products',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].price).to.equal 10
        expect(response.body[1].price).to.equal 20

    describe 'resolve', ->
      withModel (mongoose) ->
        mongoose.Schema { name: String }

      beforeEach fibrous ->
        user1 = @model.sync.create { name: 'Bilbo' }
        user2 = @model.sync.create { name: 'Frodo' }

        schema = {
          'name': 'name'
          'orderCount':
            get: (user, {orderCountByUserId}) ->
              orderCountByUserId[user._id]
        }

        @resource = new ResourceSchema @model, schema,
          resolve:
            orderCountByUserId: ({}, done) ->
              result = {}
              result[user1._id] = 5
              result[user2._id] = 10
              done(null, result)

      withServer (app) ->
        app.get '/users', @resource.get(), @resource.send

      it 'exposes the resolved variable to getters and setters', fibrous ->
        response = @request.sync.get
          url: '/users',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].name).to.equal 'Bilbo'
        expect(response.body[0].orderCount).to.equal 5
        expect(response.body[1].name).to.equal 'Frodo'
        expect(response.body[1].orderCount).to.equal 10

    describe 'defaultLimit', ->
      withModel (mongoose) ->
        mongoose.Schema { name: String }

      beforeEach fibrous ->
        @model.sync.create { name: 'Bilbo' }
        @model.sync.create { name: 'Frodo' }
        @model.sync.create { name: 'Mary' }
        @model.sync.create { name: 'Pippin' }

        schema = { 'name' }

        @resource = new ResourceSchema @model, schema,
          defaultLimit: 2

      withServer (app) ->
        app.get '/users', @resource.get(), @resource.send

      it 'uses default limit', fibrous ->
        response = @request.sync.get
          url: '/users',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2

    describe 'queryParams', ->
      withModel (mongoose) ->
        mongoose.Schema { name: String }

      beforeEach fibrous ->
        @model.sync.create { name: 'Aragorn' }
        @model.sync.create { name: 'Bilbo' }
        @model.sync.create { name: 'Gimli' }
        @model.sync.create { name: 'Frodo' }

        schema = { 'name' }

        queryParams =
          isHobbit:
            find: (value) ->
              name: $in: ['Bilbo', 'Frodo', 'Sam', 'Merry', 'Pippin']

        @resource = new ResourceSchema @model, schema, {queryParams}

      withServer (app) ->
        app.get '/characters', @resource.get(), @resource.send

      it 'searches by the parameter', fibrous ->
        response = @request.sync.get
          url: '/characters?isHobbit=true',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].name).to.equal 'Bilbo'
        expect(response.body[1].name).to.equal 'Frodo'

  describe 'edge cases', ->
    describe 'default limit of 1000', ->
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

    describe 'document with nested field', ->
      withModel (mongoose) ->
        mongoose.Schema
          firstName: String
          lastName: String

      beforeEach fibrous ->
        @model.sync.create
          firstName: 'eric'
          lastName: 'cartman'

        schema =
          'name':
            'first': 'firstName'
            'last': 'lastName'
            'full':
              get: (employee) ->
                employee.firstName + ' ' + employee.lastName

        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/employees', @resource.get(), @resource.send

      it 'returns the nested field as a normal object (not a dot string)', fibrous ->
        response = @request.sync.get
          url: '/employees',
          json: true

        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 1
        expect(response.body[0].name.full).to.equal 'eric cartman'

    describe 'getting document with falsy value', ->
      withModel (mongoose) ->
        mongoose.Schema
          name: String

      beforeEach fibrous ->
        @model.sync.create name: ''
        schema = {'name'}
        @resource = new ResourceSchema @model, schema

      withServer (app) ->
        app.get '/fruits', @resource.get(), @resource.send

      it 'filters by the param', fibrous ->
        response = @request.sync.get
          url: '/fruits',
          json: true

        expect(response.body.length).to.equal 1
        expect(response.body[0].name).to.equal ''