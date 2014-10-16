Model = require './model'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema Model, {
  '_id'
  # single field
  'name'
  # nested field
  'product.price'
  # renamed field
  'productName': 'product.name'
}

module.exports = app = express()

app.get '/', resource.query()
app.post '/', resource.save()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.get('modelId')
