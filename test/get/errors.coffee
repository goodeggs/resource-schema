{suite} = require '../support/helpers'
mongoose = require 'mongoose'
express = require 'express'
fibrous = require 'fibrous'
request = require 'request'
{expect} = require 'chai'
ResourceSchema = require '../../src'
sinon = require 'sinon'

suite "error handling", ({withModel, withServer}) ->
  withModel ->
    mongoose.Schema()

  withServer ->
    resource = new ResourceSchema @model
    app = express()
    app.get '/:_id', resource.get('_id'), resource.send
    app

  it 'returns a 404 if client supplies a valid objectId but no object is found', fibrous ->
    id = mongoose.Types.ObjectId()
    response = request.sync.get
      url: "http://127.0.0.1:83029/#{id}"
      json: true

    expect(response.statusCode).to.equal 404
    expect(response.body).to.deep.equal "No _id found with id #{id}"

  it 'returns a 400 if client supplies an invalid ObjectId', fibrous ->
    response = request.sync.get
      url: 'http://127.0.0.1:83029/badId',
      json: true

    expect(response.statusCode).to.equal 400
    expect(response.body).to.have.property 'message', "Cast to ObjectId failed for value \"badId\" at path \"_id\""

  it 'returns a 500 if there are issues querying the database', fibrous ->
    sinon.stub(@model, 'findOne').throws()
    response = request.sync.get
      url: "http://127.0.0.1:83029/#{mongoose.Types.ObjectId()}"
      json: true
    @model.findOne.restore()

    expect(response.statusCode).to.equal 500
