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
    set: (model) -> model.name.toLowerCase()

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
    get: -> 10

  'parentName':
    findAsync: (searchValue, {req, res, next}, done) ->
      ParentModel.findOne {name: searchValue}, (err, parentModel) ->
        done null, { _id: $in: parentModel.modelIds }
    context:
      parentModelsByChildId: ({models}, done) -> getParentModelsByChildId(models, done)
    get: (resource, {parentModelsByChildId}) ->
      parentModelsByChildId[resource._id]?.name

  # TODO: remove, this is no longer helpful
  'secondGet':
    get: -> 'test'
}

resource = new ResourceSchema Model, schema,

getParentModelsByChildId = (models, done) ->
  models = [models] if not Array.isArray models
  ids = _(models).pluck('_id')

  parentModels = ParentModel.find {modelIds: $in: ids}, (err, parentModels) ->
    return done(err) if err
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
