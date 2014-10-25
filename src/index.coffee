dot = require 'dot-component'
_ = require 'underscore'
q = require 'q'

RESERVED_KEYWORDS = ['$find', '$get', '$set', '$field']

###
normalized schema:
{
  normalField: {
    $field: 'test.name'
  },
  dynamicField: {
    $find: ->
    $get: ->
    $set: ->
  }
}
###

module.exports = class ResourceSchema
  constructor: (@Model, schema) ->
    if schema
      @schema = @_normalizeSchema(schema)
    else
      @schema = @_getSchemaFromModel(@Model)

  index: ->
    (req, res, next) =>
      limit = @_extractLimit req.query
      select = @_extractModelSelectFields req.query
      searchFields = @_selectValidResourceSearchFields req.query

      queryPromises = []
      modelQuery = @Model.find()
      for searchField, value of searchFields
        if @schema[searchField].$field
          modelQuery.where(@schema[searchField].$field).equals value
        else if @schema[searchField].$find
          deferred = q.defer()
          @schema[searchField].$find(value, modelQuery, deferred.makeNodeResolver())
          queryPromises.push(deferred.promise)

      q.all(queryPromises).then =>
        modelQuery.select(select) if select?
        modelQuery.limit(limit) if limit?
        modelQuery.exec (err, modelsFound) =>
          res.send 400, err if err
          resources = modelsFound.map (modelFound) =>
            @_createResourceFromModel(modelFound, searchFields)
          @_resolveResourceGetPromises(resources, modelsFound, req.query).then =>
            res.send resources

  show: (paramId) =>
    (req, res, next) =>
      id = req.params[paramId]
      select = @_extractModelSelectFields req.query

      modelQuery = @Model.findById(id)
      modelQuery.select(select) if select?
      modelQuery.exec (err, modelFound) =>
        if err
          return res.status(400).send err
        if not modelFound?
          return res.status(404).send "No #{paramId} found with id #{id}"

        resource = @_createResourceFromModel(modelFound)
        res.send resource

  create: ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body
      model = new @Model(newModelData)
      model.save (err, modelSaved) =>
        res.send 400, err if err
        resource = @_createResourceFromModel(modelSaved)
        res.status(201).send resource

  update: (paramId) ->
    (req, res, next) =>
      id = req.params[paramId]
      newModelData = @_createModelFromResource req.body
      # if using mongoose timestamps plugin:
      # since we are not updating an instance of mongoose, we need to manually add the updatedAt timestamp
      # newModelData.updatedAt = new Date() if newModelData.updatedAt
      @Model.findById id, (err, modelFound) =>
        @_resolveResourceSetPromises(req.body, modelFound, {}).then =>
        @Model.findByIdAndUpdate id, newModelData, (err, modelUpdated) =>
          res.send 400, err if err
          res.send 404, 'resource not found' if !modelUpdated
          resource = @_createResourceFromModel(modelUpdated)
          res.status(200).send resource

  send: (req, res) =>
    res.body ?= {}
    res.send res.body

  _createResourceFromModel: (model, queryParams) =>
    resource = {}
    waitingCount = 0
    for resourceField, config of @schema
      if config.$field
        value = dot.get model, config.$field
        dot.set(resource, resourceField, value) if value
    resource

  _resolveResourceSetPromises: (resource, model, queryParams) =>
    setPromises = []
    for resourceField, config of @schema
      if config.$set
        d = q.defer()
        config.$set(resource[resourceField], model, queryParams, (err, results) -> d.resolve())
        setPromises.push d.promise
    return q.all setPromises

  _resolveResourceGetPromises: (resources, models, queryParams) =>
    getPromises = []
    for resourceField, config of @schema
      if config.$get
        d = q.defer()
        config.$get(resources, models, queryParams, (err, results) -> d.resolve())
        getPromises.push d.promise
    return q.all getPromises

  _createModelFromResource: (resource) =>
    model = {}
    for resourceField, config of @schema
      if config.$field
        value = dot.get resource, resourceField
        dot.set(model, config.$field, value) if value
    model

  _extractLimit: (query) =>
    limit = query.$limit ? 100
    delete query.$limit
    limit

  _extractModelSelectFields: (query) =>
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

  _selectValidResourceSearchFields: (query) =>
    queryDotString = @_convertKeysToDotStrings query
    [resourceFields, modelFields] = @_getResourceAndModelFields()
    validFields = {}
    for field, value of queryDotString
      if field in resourceFields
        dot.set validFields, field, value
    @_convertKeysToDotStrings validFields

  _convertKeysToDotStrings: (obj) =>
    dotKeys = {}
    dotStringify = (obj, current) ->
      for key, value of obj
        newKey = if current then current + "." + key else key
        if key in RESERVED_KEYWORDS
          dotKeys[current] ?= {}
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
        $field: schemaKey
    schema

  _normalizeSchema: (schema) =>
    schema = @_convertKeysToDotStrings(schema)
    normalizedSchema = {}
    for key, config of schema
      if typeof config is 'string'
        if @Model
          normalizedSchema[key] =
            $field: config
        else
          throw new Error "No model provided for field #{key}, and no default model provided"
      else
        normalizedSchema[key] = config
    normalizedSchema
