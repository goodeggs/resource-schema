Model = require './model'
MongooseResource = require '../..'
express = require 'express'

module.exports = app = express()

modelResource = new MongooseResource Model, {
  'name': 'name'
}

app.get '/', modelResource.query()
# app.post '/', modelResource.post()
app.get '/:modelId', modelResource.get('modelId')
# app.put '/:modelId', modelResource.put('modelId')
