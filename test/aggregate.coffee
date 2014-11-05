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

      it 'populates the _id with the aggregate value (for saving in the future)', ->
        expect(response.body.length).to.equal 2
        expect(response.body[1]._id).to.equal 'test1'
        expect(response.body[0]._id).to.equal 'test2'

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
        model2 = Model.sync.create name: 'foo'
        model3 = Model.sync.create name: 'bar'
        model4 = Model.sync.create name: 'baz'
        parentModel = ParentModel.sync.create
          name: 'banana'
          modelIds: [model1._id, model3._id]

        response = request.sync.get
          url: 'http://127.0.0.1:4000/resource_aggregate?parentName=banana',
          json: true

      it 'returns only the specified fields in the dynamic search', fibrous ->
        expect(response.statusCode).to.equal 200
        expect(response.body.length).to.equal 2
        expect(response.body[0].name).to.equal 'bar'
        expect(response.body[0].parentName).to.be.undefined
        expect(response.body[1].name).to.equal 'foo'
        expect(response.body[1].total).to.equal 1

  describe 'aggregate by multiple fields', ->
    {model} = {}
    before fibrous ->
      ParentModel.sync.remove()
      Model.sync.remove()
      model1 = Model.sync.create
        name: 'Joe'
        lastName: 'Smith'
      model2 = Model.sync.create
        name: 'Joe'
        lastName: 'Smith'
      model3 = Model.sync.create
        name: 'Joe'
        lastName: 'Schmoe'

      response = request.sync.get
        url: 'http://127.0.0.1:4000/resource_multiple_aggregate',
        json: true

    it 'returns only the specified fields in the dynamic search', fibrous ->
      expect(response.statusCode).to.equal 200
      expect(response.body.length).to.equal 2
      expect(response.body[1].lastName).to.equal 'Smith'
      expect(response.body[1].total).to.equal 2
      expect(response.body[0].lastName).to.equal 'Schmoe'
      expect(response.body[0].total).to.equal 1

    it 'returns an id from all the combined aggregated values', ->
      expect(response.body[1]._id).to.equal('Joe|Smith')
