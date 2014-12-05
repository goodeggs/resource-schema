ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schemaOptions =
  groupBy: ['name']

schema =
  name: 'name'
  total:
    get: $sum: 1
  parentName:
    find: fibrous (searchValue) ->
      parentModel = ParentModel.sync.findOne(name: searchValue)
      return {_id: $in: parentModel.modelIds}

resource = new ResourceSchema Model, schema, schemaOptions

module.exports = app = express()

app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
