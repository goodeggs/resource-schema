sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require './fixtures/model.coffee'
expect = require('chai').expect
request = require 'request'
require './support/bootstrap'

MongooseResource = require '..'

{response, model} = {}

describe '.update("paramVariableName")', ->
  before fibrous ->
    Model.sync.remove()
    model = Model.sync.create
      name: 'test'
      product:
        name: 'apples'
        price: 25

    response = request.sync.put
      url: "http://127.0.0.1:4000/resource/#{model._id}"
      json:
        name: 'test'
        productName: 'berries'
        product: price: 25

  it 'returns the updated resource', ->
    expect(response.statusCode).to.equal 200
    expect(response.body.name).to.equal 'test'
    expect(response.body.productName).to.equal 'berries'
    expect(response.body.product.price).to.equal 25
    expect(response.body._id).to.be.ok

  it 'saves to the DB, in the model schema', fibrous ->
    modelsFound = Model.sync.find()
    expect(modelsFound.length).to.equal 1
    expect(modelsFound[0].product.name).to.equal 'berries'
    expect(modelsFound[0].product.price).to.equal 25
    expect(modelsFound[0].name).to.equal 'test'
