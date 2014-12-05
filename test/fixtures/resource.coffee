ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schema = {
  '_id'
  'name':
    field: 'name'
    set: fibrous (modelsToSave, {req, res, resources}) ->
      for model in modelsToSave
        model.name = model.name.toLowerCase()
  'active'
  'product.price'
  'productName': 'product.name'
  'normal':
    'nesting': 'normal.nesting'
  'productCount':
    optional: true
    field: 'productCount'
  'weeklyProductCount':
    optional: true
    get: fibrous (resourcesToReturn, {req, res, models}) ->
      resourcesToReturn.forEach (resource) ->
        resource.weeklyProductCount = 10
  'parentName':
    find: fibrous (searchValue, {req, res}) ->
      parentModel = ParentModel.sync.findOne(name: searchValue)
      return {_id: $in: parentModel.modelIds}
    get: fibrous (resourcesToReturn, {req, res, models}) ->
      parentModelsByChildId = getParentModelsByChildId.sync(models)
      resourcesToReturn.forEach (resource) ->
        resource.parentName = parentModelsByChildId[resource._id]?.name

  'secondGet':
    get: fibrous (resourcesToReturn, {req, res, models}) ->
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


app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
app.delete '/:_id', resource.delete('_id'), resource.send
