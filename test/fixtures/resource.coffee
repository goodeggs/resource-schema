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
    set: (modelsToSave, {req, res, resources}, done) ->
      for model in modelsToSave
        model.name = model.name.toLowerCase()
      done null, modelsToSave
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
    get: (resourcesToReturn, {req, res, next, models}, done) ->
      resourcesToReturn.forEach (resource) ->
        resource.weeklyProductCount = 10
      done null, resourcesToReturn
  'parentName':
    find: (searchValue, {req, res, next}, done) ->
      ParentModel.findOne {name: searchValue}, (err, parentModel) ->
        done null, { _id: $in: parentModel.modelIds }

    get: (resourcesToReturn, {req, res, models}, done) ->
      getParentModelsByChildId models, (err, parentModelsByChildId) ->
        resourcesToReturn.forEach (resource) ->
          resource.parentName = parentModelsByChildId[resource._id]?.name
        done null, resourcesToReturn

  'secondGet':
    get: (resourcesToReturn, {req, res, models}, done) ->
      resourcesToReturn.forEach (foundResource) ->
        foundResource.secondGet = 'test'
      done null, resourcesToReturn
}

resource = new ResourceSchema Model, schema,

getParentModelsByChildId = (models, done) ->
  modelIds = _(models).pluck('_id')
  parentModels = ParentModel.find {modelIds: $in: modelIds}, (err, parentModels) ->
    parentModelsByChildId = {}
    for parentModel in parentModels
      for modelId in parentModel.modelIds
        parentModelsByChildId[modelId.toString()] = parentModel
    done null, parentModelsByChildId

module.exports = app = express()


app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
app.delete '/:_id', resource.delete('_id'), resource.send
