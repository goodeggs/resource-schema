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
    set: (resource) -> resource.name.toLowerCase()

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
    resolve:
      parentNameByChildId: ({models}, done) ->
        getParentNameByChildId({models}, done)
    get: (model, {parentNameByChildId}) ->
      parentNameByChildId[model._id]

  'parentId':
    get: (model, {parentIdByChildId}) ->
      parentIdByChildId[model._id]

  'nested':
    'dynamicValue':
      get: -> 2
}

resource = new ResourceSchema Model, schema, {
  resolve:
    parentIdByChildId: ({models}, done) -> getParentIdByChildId({models}, done)
}

getParentNameByChildId = ({models}, done) ->
  models = [models] if not Array.isArray models
  ids = _(models).pluck('_id')

  ParentModel.find {modelIds: $in: ids}, (err, parentModels) ->
    return done(err) if err
    parentNameByChildId = {}
    for parentModel in parentModels
      for modelId in parentModel.modelIds
        parentNameByChildId[modelId.toString()] = parentModel.name
    done null, parentNameByChildId

getParentIdByChildId = ({models}, done) ->
  models = [models] if not Array.isArray models
  ids = _(models).pluck('_id')

  ParentModel.find {modelIds: $in: ids}, (err, parentModels) ->
    return done(err) if err
    parentIdByChildId = {}
    for parentModel in parentModels
      for modelId in parentModel.modelIds
        parentIdByChildId[modelId.toString()] = parentModel._id.toString()
    done null, parentIdByChildId

module.exports = app = express()


app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/', resource.put(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
app.delete '/:_id', resource.delete('_id'), resource.send
