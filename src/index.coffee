dot = require 'dot-component'
_ = require 'underscore'
q = require 'q'

###
normalized schema:
{
  normalField: {
    $model: Model
    $field: 'test.name'
  },
  dynamicField: {
    $model: Model
    $find: ->
    $get: ->
    $set: ->
  }
}
###

module.exports = class RestfulResource
  constructor: (@Model, schema) ->
    if schema
      @schema = @_normalizeSchema(schema)
    else
      @schema = @_getSchemaFromModel(@Model)

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

        @_createResourceFromModelPromise(modelFound).then (resource) ->
          res.send resource

  query: ->
    (req, res, next) =>
      limit = @_extractLimitFromQuery req.query
      select = @_extractModelSelectFieldsFromQuery req.query
      resourceSearchFields = @_selectValidResourceSearchFieldsFromQuery req.query
      dotSearchFields = @_convertKeysToDotStrings resourceSearchFields

      queryPromises = []
      modelQuery = @Model.find()
      for resourceField, value of dotSearchFields
        if modelField = @schema[resourceField].$field
          modelQuery = modelQuery.where(modelField).equals value
        else if @schema[resourceField].$find and resourceSearchFields[resourceField]
          modelFinder = @schema[resourceField].$find
          searchValue = resourceSearchFields[resourceField]
          deferred = q.defer()
          modelFinder(searchValue, modelQuery, deferred.makeNodeResolver())
          queryPromises.push(deferred.promise)

      q.all(queryPromises).then =>
        modelQuery.select(select) if select?
        modelQuery.limit(limit) if limit?
        modelQuery.exec (err, modelsFound) =>
          res.send 400, err if err
          resourcePromises = modelsFound.map (modelFound) =>
            @_createResourceFromModelPromise(modelFound, resourceSearchFields)
          q.all(resourcePromises).then (resources) =>
            res.send resources

  save: ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body
      model = new @Model(newModelData)
      model.save (err, modelSaved) =>
        res.send 400, err if err
        @_createResourceFromModelPromise(modelSaved).then (resource) ->
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
        @_createResourceFromModelPromise(modelUpdated).then (resource) ->
          res.status(200).send resource

  send: (req, res) =>
    res.body ?= {}
    res.send res.body

  _createResourceFromModelPromise: (model, queryParams) =>
    deferred = q.defer()
    resource = {}
    waitingCount = 0
    for resourceField, config of @schema
      if config.$field
        value = dot.get model, config.$field
        dot.set(resource, resourceField, value) if value
      else if config.$get and typeof config.$get is 'function'
        waitingCount++
        fieldGetter = config.$get
        fieldGetter model, queryParams, (err, value) ->
          dot.set(resource, resourceField, value) if value
          waitingCount--
          deferred.resolve(resource) if waitingCount is 0
    deferred.resolve(resource) if waitingCount is 0
    return deferred.promise

  _createModelFromResource: (resource) =>
    model = {}
    for resourceField, config of @schema
      if config.$field
        value = dot.get resource, resourceField
        dot.set(model, config.$field, value) if value
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
      modelSelectFields = resourceSelectFields.map (resourceSelectField) => @schema[resourceSelectField].$field
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
    resevedKeywords = ['$find', '$get', '$set', '$model', '$field']
    dotKeys = {}
    dotStringify = (obj, current) ->
      for key, value of obj
        newKey = if current then current + "." + key else key
        if key in resevedKeywords
          dotKeys[current] = {}
          dotKeys[current][key] = value
        else if value and typeof value is "object"
          dotStringify(value, newKey)
        else
          dotKeys[newKey] = value
    dotStringify(obj)
    return dotKeys

  _getResourceAndModelFields: =>
    resourceFields = Object.keys @schema
    modelFields = resourceFields.map (resourceField) => @schema[resourceField].$field
    [resourceFields, modelFields]

  _getSchemaFromModel: (Model) =>
    # Paths already in dot notation
    schemaKeys = Object.keys Model.schema.paths
    schemaKeys.splice schemaKeys.indexOf('__v'), 1
    schema = {}
    for schemaKey in schemaKeys
      schema[schemaKey] =
        $model: Model
        $field: schemaKey
    schema

  _normalizeSchema: (schema) =>
    schema = @_convertKeysToDotStrings(schema)
    normalizedSchema = {}
    for key, config of schema
      if typeof config is 'string'
        if @Model
          normalizedSchema[key] =
            $model: @Model
            $field: config
        else
          throw new Error "No model provided for field #{key}, and no default model provided"
      else
        normalizedSchema[key] = config
    normalizedSchema
