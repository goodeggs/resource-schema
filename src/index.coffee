dot = require 'dot-component'
mongoose = require 'mongoose'
fibrous = require 'fibrous'

module.exports = class RestfulResource
  constructor: (@Model, @schema) ->

  get: (paramId) =>
    fibrous (req, res, next) =>
      id = req.params[paramId]
      select = @_extractSelectFromQuery req.query
      try
        modelQuery = @Model.findById(id)
        modelQuery = modelQuery.select(select) if select?
        modelFound = modelQuery.sync.exec()
      catch e
        res.send 400, e.stack
      if not modelFound?
        res.send 404, "No #{paramId} found with id #{id}"
      res.body = @_createResourceFromModelInstance(modelFound)

  query: =>
    fibrous (req, res, next) =>
      limit = @_exctractLimitFromQuery req.query
      select = @_extractSelectFromQuery req.query
      searchFields = @_selectValidSearchFieldsFromQuery req.query

      try
        modelQuery = @Model.find()
        for resourceField, modelField of @schema
          value = dot.get searchFields, resourceField
          if value
            value = new mongoose.Types.ObjectId(value) if @_isObjectId(value)
            modelQuery = modelQuery.where(modelField).equals value

        modelQuery = modelQuery.select(select) if select?
        modelQuery = modelQuery.limit(limit) if limit?
        modelsFound = modelQuery.sync.exec()
      catch e
        res.send 400, e.stack

      resources = []
      for modelFound in (modelsFound or [])
        resources.push @_createResourceFromModelInstance(modelFound)

      res.body = resources

  send: fibrous (req, res) =>
    res.body ?= {}
    res.send res.body

  _createResourceFromModelInstance: (modelInstance) =>
    resourceInstance = {}
    for resourceField, modelField of @schema
      value = dot.get modelInstance, modelField
      dot.set resourceInstance, resourceField, value
    resourceInstance

  _exctractLimitFromQuery: (query) =>
    limit = query.limit ? 100
    delete query.limit
    limit

  _extractSelectFromQuery: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFieldsFromSchema()
    select = query.select
    if select
      select = _(select.split(' ')).intersection(resourceFields).join(' ')
    else
      select = resourceFields.join(' ')
    delete query.select
    select

  _selectValidSearchFieldsFromQuery: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFieldsFromSchema()
    validFields = {}
    for field, value of query
      validFields[field] = value if resourceFields[field]
    validFields

  _getResourceAndModelFieldsFromSchema: =>
    resourceFields = Object.keys @schema
    modelFields = resourceFields.map (resourceField) => @schema[resourceField]
    [resourceFields, modelFields]

  _isObjectId: (string) =>
    /^[0-9a-fA-F]{24}$/.test string
