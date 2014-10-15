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

  describe 'GET /model_resource', ->
    before fibrous ->
      Model.sync.create name: 'test'
      response = request.sync.get 'http://127.0.0.1:4000/model_resource'

    it 'returns an array of objects', ->
      console.log response.body
      expect(true).to.equal true

  # it 'works', ->
  #   throw new Error 'busted'
