dot = require 'dot-component'
mongoose = require 'mongoose'
_ = require 'underscore'
fibrous = require 'fibrous'

module.exports = class RestfulResource
  constructor: (@Model, @schema) ->

  get: (paramId) =>
    fibrous (req, res, next) =>
      id = req.params[paramId]
      select = @_extractModelSelectFieldsFromQuery req.query
      try
        modelQuery = @Model.findById(id)
        modelQuery = modelQuery.select(select) if select?
        modelFound = modelQuery.sync.exec()
      catch e
        res.send 400, e.stack
      if not modelFound?
        res.send 404, "No #{paramId} found with id #{id}"
      res.send @_createResourceFromModelInstance(modelFound)

  query: ->
    fibrous (req, res, next) =>
      limit = @_extractLimitFromQuery req.query
      select = @_extractModelSelectFieldsFromQuery req.query
      searchFields = @_selectValidResourceSearchFieldsFromQuery req.query
      dotSearchFields = @_convertKeysToDotStrings searchFields

      try
        modelQuery = @Model.find()
        for resourceField, value of dotSearchFields
          modelField = @schema[resourceField]
          modelQuery = modelQuery.where(modelField).equals value
        modelQuery = modelQuery.select(select) if select?
        modelQuery = modelQuery.limit(limit) if limit?
        modelsFound = modelQuery.sync.exec()
      catch e
        res.send 400, e.stack

      resources = modelsFound.map (modelFound) =>
        @_createResourceFromModelInstance(modelFound)

      res.send resources

  send: (req, res) =>
    res.body ?= {}
    res.send res.body

  _createResourceFromModelInstance: (modelInstance) =>
    resourceInstance = {}
    for resourceField, modelField of @schema
      value = dot.get modelInstance, modelField
      dot.set(resourceInstance, resourceField, value) if value
    resourceInstance

  _extractLimitFromQuery: (query) =>
    limit = query.$limit ? 100
    delete query.$limit
    limit

  _extractModelSelectFieldsFromQuery: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFieldsFromSchema()
    select = query.$select
    if select
      select = select.split(' ') if typeof select is 'string'
      resourceSelectFields = _(select).intersection resourceFields
      modelSelectFields = resourceSelectFields.map (resourceSelectField) => @schema[resourceSelectField]
      modelSelectFields = modelSelectFields.join(' ')
    else
      modelSelectFields = modelFields.join(' ')
    delete query.$select
    modelSelectFields

  _selectValidResourceSearchFieldsFromQuery: (query) =>
    queryDotString = @_convertKeysToDotStrings query
    [resourceFields, modelFields] = @_getResourceAndModelFieldsFromSchema()
    validFields = {}
    for field, value of queryDotString
      if field in resourceFields
        dot.set validFields, field, value
    validFields

  _convertKeysToDotStrings: (obj) =>
    dotKeys = {}
    dotStringify = (obj, current) ->
      for key, value of obj
        newKey = if current then current + "." + key else key
        if value and typeof value is "object"
          dotStringify(value, newKey)
        else
          dotKeys[newKey] = value
    dotStringify(obj)
    return dotKeys

  _getResourceAndModelFieldsFromSchema: =>
    resourceFields = Object.keys @schema
    modelFields = resourceFields.map (resourceField) => @schema[resourceField]
    [resourceFields, modelFields]

  _isObjectId: (string) =>
    /^[0-9a-fA-F]{24}$/.test string
