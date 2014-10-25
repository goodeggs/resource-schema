ParentModel = require './parent_model'
Model = require './model'
fibrous = require 'fibrous'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema Model, {
  '_id'
  'parentName':
    $get: fibrous (foundModel, queryParams) ->
      parentModel = ParentModel.findOne('modelIds': foundModel._id).sync.exec()
      return parentModel.name
  }

module.exports = app = express()

app.get '/', resource.index()
app.post '/', resource.create()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.show('modelId')
