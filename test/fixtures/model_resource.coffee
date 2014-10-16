Model = require './model'
MongooseResource = require '../..'
express = require 'express'

modelResource = new MongooseResource Model, {
  '_id'
  # single field
  'name'
  # nested field
  'product.price'
  # renamed field
  'productName': 'product.name'
}

module.exports = app = express()

app.get '/', modelResource.query()
app.post '/', modelResource.save()
app.put '/:modelId', modelResource.update('modelId')
app.get '/:modelId', modelResource.get('modelId')
