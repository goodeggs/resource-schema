ParentModel = require './parent_model'
Model = require './model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema Model,
  _id: '_id'
  name: 'name'
  'product.price': 'product.price'
  productName: 'product.name'
  normal:
    nesting: 'normal.nesting'
  parentName:
    $find: fibrous (searchValue, modelQuery) ->
      parentModel = ParentModel.sync.findOne(name: searchValue)
      modelQuery.find().where('_id').in(parentModel.modelIds)
    $get: fibrous (foundResources, foundModels, queryParams) ->
      foundResourceIds = _(foundResources).pluck('_id')
      parentModels = ParentModel.sync.find(modelIds: $in: foundResourceIds)
      parentModelsByChildId = {}
      for parentModel in parentModels
        for modelId in parentModel.modelIds
          parentModelsByChildId[modelId.toString()] = parentModel
      foundResources.forEach (foundResource) ->
        foundResource.parentName = parentModelsByChildId[foundResource._id].name

module.exports = app = express()

app.get '/', resource.index()
app.post '/', resource.create()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.show('modelId')
