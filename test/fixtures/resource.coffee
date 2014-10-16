Model = require './model'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema Model, {
  '_id'
  'name'
  'product.price'
  productName: 'product.name'
  normal: nesting: 'normal.nesting'
}

module.exports = app = express()

app.get '/', resource.query()
app.post '/', resource.save()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.get('modelId')
