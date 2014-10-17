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

app.get '/', resource.query()
app.post '/', resource.save()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.get('modelId')
