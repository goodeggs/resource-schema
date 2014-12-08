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
  'product.price': 'product.price'

schemaConfig =
  queryParams:
    'startDate':
      type: String
      validate: (value) ->
        /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/.test(value)
      find: (value, {}) -> { 'day': $gte: value }
    'containsDays':
      type: String
      isArray: true
      match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
      find: (days, {}) -> { 'day': $in: days }

  defaultQuery:
    day: $gte: '2014-09-19'

  defaultLimit: 6

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

app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
