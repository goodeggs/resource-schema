ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schema =
  _id: '_id'
  'product.price': 'product.price'

queryParams =
  'minPrice':
    type: Number
    filter: (minPrice, resources) ->
      minPrice = parseInt minPrice
      resources = resources.filter (resource) ->
        resource.product.price >= minPrice
      resources

resource = new ResourceSchema Model, schema, {queryParams}

module.exports = app = express()

app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
