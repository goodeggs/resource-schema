ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema Model,
  _id: 'name'
  name: 'name'
  total: $get: $sum: 1
  productName: 'product.name'

module.exports = app = express()

app.get '/', resource.index()
app.post '/', resource.create()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.show('modelId')
