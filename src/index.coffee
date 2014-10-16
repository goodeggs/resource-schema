dot = require 'dot-component'
_ = require 'underscore'

module.exports = class RestfulResource
  constructor: (@Model, schema) ->
    @schema = @_convertKeysToDotStrings(schema)

  get: (paramId) =>
    (req, res, next) =>
      id = req.params[paramId]
      select = @_extractModelSelectFieldsFromQuery req.query

      modelQuery = @Model.findById(id)
      modelQuery = modelQuery.select(select) if select?
      modelQuery.exec (err, modelFound) =>
        if err
          return res.status(400).send err
        if not modelFound?
          return res.status(404).send "No #{paramId} found with id #{id}"
        res.send @_createResourceFromModel(modelFound)

  query: ->
    (req, res, next) =>
      limit = @_extractLimitFromQuery req.query
      select = @_extractModelSelectFieldsFromQuery req.query
      searchFields = @_selectValidResourceSearchFieldsFromQuery req.query
      dotSearchFields = @_convertKeysToDotStrings searchFields

      modelQuery = @Model.find()
      for resourceField, value of dotSearchFields
        modelField = @schema[resourceField]
        modelQuery = modelQuery.where(modelField).equals value
      modelQuery = modelQuery.select(select) if select?
      modelQuery = modelQuery.limit(limit) if limit?
      modelQuery.exec (err, modelsFound) =>
        res.send 400, err if err
        resources = modelsFound.map (modelFound) =>
          @_createResourceFromModel(modelFound)
        res.send resources

  save: ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body
      model = new @Model(newModelData)
      model.save (err, modelSaved) =>
        res.send 400, err if err
        resource = @_createResourceFromModel modelSaved
        res.status(201).send resource

  update: (paramId) ->
    (req, res, next) =>
      id = req.params[paramId]
      newModelData = @_createModelFromResource req.body
      # if using mongoose timestamps plugin:
      # since we are not updating an instance of mongoose, we need to manually add the updatedAt timestamp
      newModelData.updatedAt = new Date() if newModelData.updatedAt
      @Model.findByIdAndUpdate id, newModelData, (err, modelUpdated) =>
        res.send 400, err if err
        res.send 404, 'resource not found' if !modelUpdated
        resource = @_createResourceFromModel modelUpdated
        res.status(200).send resource

  send: (req, res) =>
    res.body ?= {}
    res.send res.body

  _createResourceFromModel: (model) =>
    resource = {}
    for resourceField, modelField of @schema
      value = dot.get model, modelField
      dot.set(resource, resourceField, value) if value
    resource

  _createModelFromResource: (resource) =>
    model = {}
    for resourceField, modelField of @schema
      value = dot.get resource, resourceField
      dot.set(model, modelField, value) if value
    model

  _extractLimitFromQuery: (query) =>
    limit = query.$limit ? 100
    delete query.$limit
    limit

  _extractModelSelectFieldsFromQuery: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFields()
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
    [resourceFields, modelFields] = @_getResourceAndModelFields()
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

  _getResourceAndModelFields: =>
    resourceFields = Object.keys @schema
    modelFields = resourceFields.map (resourceField) => @schema[resourceField]
    [resourceFields, modelFields]
