ParentModel = require './parent_model'
Model = require './model'
fibrous = require 'fibrous'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema Model, {
  '_id'
  'name'
  'product.price'
  'productName': 'product.name'
  normal:
    nesting: 'normal.nesting'
  'parentName':
    $find: fibrous (findValue, modelQuery) ->
      parentModel = ParentModel.sync.findOne(name: findValue)
      modelQuery.find().where('_id').in(parentModel.modelIds)

  # dynamicSetField: set: (savedResourceValue) ->
}

module.exports = app = express()

app.get '/', resource.index()
app.post '/', resource.create()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.show('modelId')
