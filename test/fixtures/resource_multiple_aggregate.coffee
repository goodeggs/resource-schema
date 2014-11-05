ParentModel = require './parent_model'
Model = require './model'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schemaOptions =
  groupBy: ['name', 'lastName']

schema =
  name: 'name'
  lastName: 'lastName'
  total: $get: $sum: 1

resource = new ResourceSchema Model, schema, schemaOptions

module.exports = app = express()

app.get '/', resource.index(), resource.send
app.post '/', resource.create(), resource.send
app.put '/:modelId', resource.update('modelId'), resource.send
app.get '/:modelId', resource.show('modelId'), resource.send
