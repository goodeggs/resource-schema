sinon = require 'sinon'
fibrous = require 'fibrous'
mongoose = require 'mongoose'
Model = require '../fixtures/model.coffee'
expect = require('chai').expect
request = require 'request'
require '../support/bootstrap'

MongooseResource = require '../..'

{response, model} = {}

describe 'POST many', ->
  before fibrous ->
    Model.sync.remove()

    response = request.sync.post
      url: "http://127.0.0.1:4000/resource"
      json: [
        { name: 'apples' }
        { name: 'pears' }
        { name: 'oranges' }
      ]

  it 'returns the saved resources', ->
    expect(response.statusCode).to.equal 201
    expect(response.body.length).to.equal 3
    expect(response.body[0].name).to.equal 'apples'
    expect(response.body[0]._id).to.be.ok
    expect(response.body[1].name).to.equal 'pears'
    expect(response.body[1]._id).to.be.ok
    expect(response.body[2].name).to.equal 'oranges'
    expect(response.body[2]._id).to.be.ok

  it 'saves the models to the DB', fibrous ->
    modelsFound = Model.sync.find()
    expect(modelsFound.length).to.equal 3
    expect(modelsFound[0].name).to.equal 'apples'
    expect(modelsFound[1].name).to.equal 'pears'
    expect(modelsFound[2].name).to.equal 'oranges'
