ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schema = {
  '_id'
  'name'
  'product.price'
  'productName': 'product.name'
  'normal':
    'nesting': 'normal.nesting'
  'parentName':
    $find: fibrous (searchValue) ->
      parentModel = ParentModel.sync.findOne(name: searchValue)
      return {_id: $in: parentModel.modelIds}
    $get: fibrous (resourcesToReturn, models, queryParams) ->
      parentModelsByChildId = getParentModelsByChildId.sync(models)
      resourcesToReturn.forEach (foundResource) ->
        foundResource.parentName = parentModelsByChildId[foundResource._id].name
    $set: fibrous (newValue, model, queryParams) ->
      parentModel = ParentModel.sync.findOne(modelIds: $in: [model._id])
      parentModel.name = newValue
      parentModel.sync.save()
  'secondGet':
    $get: fibrous (resourcesToReturn, models, queryParams) ->
      resourcesToReturn.forEach (foundResource) ->
        foundResource.secondGet = 'test'
}

resource = new ResourceSchema Model, schema,


getParentModelsByChildId = fibrous (models) ->
  modelIds = _(models).pluck('_id')
  parentModels = ParentModel.sync.find(modelIds: $in: modelIds)
  parentModelsByChildId = {}
  for parentModel in parentModels
    for modelId in parentModel.modelIds
      parentModelsByChildId[modelId.toString()] = parentModel
  parentModelsByChildId

module.exports = app = express()

app.get '/', resource.index(), resource.send
app.post '/', resource.create(), resource.send
app.put '/:_id', resource.update(), resource.send
app.get '/:_id', resource.show(), resource.send
app.delete '/:_id', resource.destroy(), resource.send
