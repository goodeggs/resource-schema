mongoose = require 'mongoose'

suiteHelpers =
  withModel: (args...) ->
    if typeof args[0] is 'string'
      name = args[0]
      schemaFn = args[1]
    else
      name = 'Model'
      schemaFn = args[0]

    beforeEach (done) ->
      @mongooseConnection ?= mongoose.createConnection 'mongodb://localhost/test'
      schema = schemaFn.call @
      model = @mongooseConnection.model name, schema
      @models ?= {}
      @models[name] = model
      @model ?= model
      model.remove done # kill all lingering instances of model

    afterEach ->
      return unless @mongooseConnection
      @mongooseConnection.models = {}
      @mongooseConnection.modelSchemas = {}

  withServer: (appFn) ->
    beforeEach (done) ->
      app = appFn.call @
      @server = app.listen 83029, done

    afterEach (done) ->
      return process.nextTick done unless @server
      @server.close done

class module.exports.suite extends GLOBAL.describe
  constructor: (name, callback) ->
    super name, ->
      callback suiteHelpers
