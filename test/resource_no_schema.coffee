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

describe 'resource without schema', ->

  describe '.get()', ->
    describe 'no search fields', ->
      before fibrous ->
        Model.sync.remove()
        Model.sync.create name: 'test1'
        Model.sync.create name: 'test2'
        response = request.sync.get
          url: 'http://127.0.0.1:4000/resource_no_schema',
          json: true

      it 'returns all of the objects', ->
        expect(response.body.length).to.equal 2
        expect(response.body[0].name).to.equal 'test1'
        expect(response.body[1].name).to.equal 'test2'


    describe "with query params", ->
      before fibrous ->
        Model.sync.remove()
        @models = [0...3].map (i) -> Model.sync.create(name: "test#{i}")._id
        response = request.sync.get
          url: "http://127.0.0.1:4000/resource_no_schema?ids=#{@models[0]}&ids=#{@models[1]}",
          json: true

      it "returns the objects that we queried", fibrous ->
        expect(response.body).to.have.length 2
        expect(response.body[0]).to.have.property '_id', @models[0].toString()
        expect(response.body[1]).to.have.property '_id', @models[1].toString()
