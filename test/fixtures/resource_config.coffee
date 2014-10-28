ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schema =
  _id: '_id'
  name: 'name'
  day: 'day'

schemaConfig =
  defaultQuery:
    day: $gte: '2014-10-01'
  defaultLimit: 10

resource = new ResourceSchema Model, schema, schemaConfig

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
app.put '/:modelId', resource.update('modelId'), resource.send
app.get '/:modelId', resource.show('modelId'), resource.send
