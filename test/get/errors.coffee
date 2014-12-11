{suite, given} = require '../support/helpers'
mongoose = require 'mongoose'
express = require 'express'
fibrous = require 'fibrous'
{expect} = require 'chai'
ResourceSchema = require '../../src'
sinon = require 'sinon'

suite "GET request error handling", ({withModel, withServer}) ->

  withModel ->
    mongoose.Schema
      number: Number

  beforeEach ->
    @resource = new ResourceSchema @model

  given 'a "show"-style endpoint', ->

    withServer ->
      app = express()
      app.get '/byId/:_id', @resource.get('_id'), @resource.send
      app.get '/byNumber/:number', @resource.get('number'), @resource.send
      app.use (err, req, res, next) ->
        res.status err.status or 500
        res.send err.message
      app

    it 'returns a 404 if client supplies a valid objectId but no object is found', fibrous ->
      id = mongoose.Types.ObjectId()
      response = @request.sync.get "/byId/#{id}"

      expect(response.statusCode).to.equal 404
      expect(response.body).to.deep.equal "No resources found with _id of #{id}"

    it 'returns a 400 if client supplies an invalid ObjectId', fibrous ->
      response = @request.sync.get '/byId/badId'

      expect(response.statusCode).to.equal 400
      expect(response.body).to.equal "Cast to ObjectId failed for value \"badId\" at path \"_id\""

    it 'returns a 400 if client supplies an invalid query parameter', fibrous ->
      response = @request.sync.get '/byNumber/foo'

      expect(response.statusCode).to.equal 400
      expect(response.body).to.equal "Cast to number failed for value \"foo\" at path \"number\""

    it 'returns a 500 if there are issues querying the database', fibrous ->
      sinon.stub(@model, 'findOne').throws()
      response = @request.sync.get "/byId/#{mongoose.Types.ObjectId()}"
      @model.findOne.restore()

      expect(response.statusCode).to.equal 500

  given 'a "query"-style endpoint', ->

    withServer ->
      app = express()
      app.get '/', @resource.get(), @resource.send
      app.use (err, req, res, next) ->
        res.status err.status or 500
        res.send err.message
      app

    it 'returns a 400 if client supplies an invalid objectId', fibrous ->
      response = @request.sync.get uri:
        pathname: '/'
        query: _id: 'borkbork'

      expect(response.statusCode).to.equal 400
      expect(response.body).to.deep.equal "Cast to ObjectId failed for value \"borkbork\" at path \"_id\""

    it 'returns a 400 if client supplies an invalid query parameter', fibrous ->
      response = @request.sync.get uri:
        pathname: '/'
        query: number: 'notnumber'
      expect(response.statusCode).to.equal 400
      expect(response.body).to.deep.equal "Cast to number failed for value \"notnumber\" at path \"number\""
