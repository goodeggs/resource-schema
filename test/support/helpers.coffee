mongoose = require 'mongoose'
express = require 'express'
url = require 'url'
namespacedRequest = require 'namespaced-request'
Boom = require 'boom'
bodyParser = require 'body-parser'
cookieParser = require 'cookie-parser'

port = process.env.PORT || 93280

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
      schema = schemaFn.call @, mongoose
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
      app = express()
      app.use bodyParser.json()
      app.use bodyParser.urlencoded()
      app.use cookieParser()
      app = appFn.call @, app
      app.use (err, req, res, next) -> # add standard error-catching middleware
        console.log {err}
        throw err unless err.isBoom
        console.error err.output.payload
        res.status err.output.statusCode
        res.send err.output.payload
      @server = app.listen port, done
      @request = namespacedRequest "http://127.0.0.1:#{port}"

    afterEach (done) ->
      return process.nextTick done unless @server
      @server.close done

class module.exports.suite extends GLOBAL.describe
  constructor: (name, callback) ->
    super name, ->
      callback suiteHelpers

class module.exports.given extends GLOBAL.describe
  constructor: (name, callback) ->
    super "given #{name}", callback
