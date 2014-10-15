Model = require './model'
MongooseResource = require '../..'
express = require 'express'

modelResource = new MongooseResource Model, {
  'name'
  'productName': 'product.name'
  'product.price': 'product.value'
  # 'product.newId': 'product.id'
}

module.exports = app = express()

# app.get '/', (req, res, next) ->
#   console.log 'modelResource.query()', modelResource.query()
#   res.send([])
app.get '/', modelResource.query()
# app.post '/', modelResource.post()
app.get '/:modelId', modelResource.get('modelId')
# app.put '/:modelId', modelResource.put('modelId')
