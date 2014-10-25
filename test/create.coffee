sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model.coffee'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

MongooseResource = require '..'

{response, model} = {}

describe '.create()', ->
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
