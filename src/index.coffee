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
  constructor: (@Model, schema, @options = {}) ->
    if schema
      @schema = @_normalizeSchema(schema)
    else
      @schema = @_getSchemaFromModel(@Model)

  ###
  Generate middleware to handle GET requests to resource
  ###
  index: ->
    (req, res, next) =>
      sendResources = (modelsFound) =>
        resources = modelsFound.map (modelFound) =>
          @_createResourceFromModel(modelFound, req.query.$select)
        @_resolveResourceGetPromises(resources, modelsFound, req.query).then =>
          res.body = resources
          next()

      limit = @_getLimit req.query
      modelSelect = @_getModelSelectFields req.query
      @_getQueryConfigPromise(req.query).then (queryConfig) =>
        console.log {queryConfig}
        if @options.groupBy
          modelQuery = @Model.aggregate()
          modelQuery.match(queryConfig)
          modelQuery.group(@_getGroupQuery())

        if not @options.groupBy
          modelQuery = @Model.find(queryConfig)
          modelQuery.select(modelSelect) if select? # reduce query if possible

        modelQuery.limit(limit) if limit?
        modelQuery.exec().then sendResources

  ###
  Generate middleware for GET requests to resource instance
  ###
  show: (paramId='_id') =>
    (req, res, next) =>
      select = @_getModelSelectFields req.query

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      modelQuery = @Model.findOne(query)
      modelQuery.select(select) if select?
      modelQuery.exec (err, modelFound) =>
        if err
          return res.status(400).send err
        if not modelFound?
          return res.status(404).send "No #{paramId} found with id #{idValue}"

        resource = @_createResourceFromModel(modelFound)
        @_resolveResourceGetPromises([resource], [modelFound], req.query).then =>
          res.body = resource
          next()

  ###
  Generate middleware to handle POST requests to resource
  ###
  create: ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body
      model = new @Model(newModelData)
      model.save (err, modelSaved) =>
        res.send 400, err if err
        resource = @_createResourceFromModel(modelSaved)
        res.status(201)
        res.body = resource
        next()

  ###
  Generate middleware to handle PUT requests to resource
  ###
  update: (paramId='_id') ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      # if using mongoose timestamps plugin:
      # since we are not updating an instance of mongoose, we need to manually add the updatedAt timestamp
      # newModelData.updatedAt = new Date() if newModelData.updatedAt
      @Model.findOne query, (err, modelFound) =>
        @_resolveResourceSetPromises(req.body, modelFound, {}).then =>
        @Model.findOneAndUpdate query, newModelData, (err, modelUpdated) =>
          res.send 400, err if err
          res.send 404, 'resource not found' if !modelUpdated
          resource = @_createResourceFromModel(modelUpdated)
          res.status(200)
          res.body = resource
          next()

  ###
  Generate middleware to handle DELETE requests to resource
  ###
  destroy: (paramId='_id') ->
    (req, res, next) =>
      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      @Model.findOneAndRemove query, (err, removedInstance) =>
        res.send 400, err if err

        if !removedInstance?
          res.send(404, "Resource with id #{idValue} not found from #{@Model.modelName} collection")

        res.status(204)
        res.body = "Resource with id #{idValue} successfully deleted from #{@Model.modelName} collection"
        next()

  ###
  Convenience middleware for sending the resource to the client after it has been saved to res.body
  ###
  send: (req, res) =>
    res.body ?= {}
    res.send res.body

  ###
  Wait for all $find, and queryParams to resolve, and build the model query with the results
  ###
  _getQueryConfigPromise: (requestQuery) =>
    modelQuery = @options.defaultQuery or {}
    deferred = q.defer()
    queryPromises = []
    resourceSearchFields = @_selectValidResourceSearchFields requestQuery

    for resourceField, value of resourceSearchFields
      if @schema[resourceField].$field
        modelQuery[@schema[resourceField].$field] = value
      else if @schema[resourceField].$find
        d = q.defer()
        @schema[resourceField].$find value, (err, query) ->
          _(modelQuery).extend(query)
          d.resolve()
        queryPromises.push(d.promise)

    q.all(queryPromises).then ->
      deferred.resolve(modelQuery)

    deferred.promise

  _createModelFromResource: (resource) =>
    model = {}
    for resourceField, config of @schema
      if config.$field
        value = dot.get resource, resourceField
        dot.set(model, config.$field, value) if value
    model

  _createResourceFromModel: (model, resourceSelectFields) =>
    resource = {}

    resourceSelectFields = resourceSelectFields.split(' ') if typeof resourceSelectFields is 'string'
    #set _id
    if @options.groupBy?.length
      delete model._id
      aggregateValues = @options.groupBy.map (aggregateField) ->
        dot.get model, aggregateField
      resource._id = aggregateValues.join('|')

    #set all other fields
    for resourceField, config of @schema
      # TODO set default select to all fields?
      if fieldIsSelectable = !resourceSelectFields? or resourceField in resourceSelectFields
        if config.$field
          value = dot.get model, config.$field
          dot.set(resource, resourceField, value) if value
        # TODO: helper for this
        if config.$get and typeof config.$get is 'object'
          value = model[resourceField]
          dot.set(resource, resourceField, value) if value
    resource

  ###
  Wait for all $set queries to update models
  ###
  _resolveResourceSetPromises: (resource, model, queryParams) =>
    setPromises = []
    for resourceField, config of @schema
      if config.$set
        d = q.defer()
        config.$set(resource[resourceField], model, queryParams, (err, results) -> d.resolve())
        setPromises.push d.promise
    return q.all setPromises

  ###
  Wait for all $get queries to update resources
  ###
  _resolveResourceGetPromises: (resources, models, query) =>
    getPromises = []
    resourceSelectFields = @_getResourceSelectFields(query)
    for resourceField, config of @schema
      if config.$get and typeof config.$get is 'function' and resourceField in resourceSelectFields
        do ->
          d = q.defer()
          config.$get resources, models, query, (err, results) ->
            console.log err if err
            d.resolve()
          getPromises.push d.promise
    return q.all getPromises

  ###
  Get $group config used for aggregating the model
  ###
  _getGroupQuery: =>
    groupQuery = {}
    #set _id
    groupQuery._id = {}
    for aggregateField in @options.groupBy
      groupQuery._id[aggregateField.replace('.', '')] = '$' + aggregateField

    #set all other fields
    for field, config of @schema
      if config.$field
        groupQuery[field] = $first: '$' + config.$field
      else if config.$get and typeof config.$get is 'object'
        groupQuery[field] = config.$get
    groupQuery

  ###
  Get value to use for limiting query results
  @param [Object] query - query params from client
  @returns [Number] Max number of resources to return in response
  ###
  _getLimit: (query) =>
    query.$limit ? @options.defaultLimit

  ###
  Get value to use for limiting query results
  @param [Object] query - query params from client
  ###
  _getResourceSelectFields: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFields()
    select = query.$select
    if select
      select = select.split(' ') if typeof select is 'string'
      resourceSelectFields = _(select).intersection resourceFields
    else
      resourceSelectFields = resourceFields
    return resourceSelectFields

  ###
  Convert select fields in query, to fields that can be used for
  @param [Object] query - query params from client
  ###
  _getModelSelectFields: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFields()
    select = query.$select
    if select
      select = select.split(' ') if typeof select is 'string'
      resourceSelectFields = _(select).intersection resourceFields
      modelSelectFields = resourceSelectFields.map (resourceSelectField) => @schema[resourceSelectField].$field
      modelSelectFields = modelSelectFields.join(' ')
    else
      modelSelectFields = modelFields.join(' ')
    modelSelectFields

  ###
  Select valid properties from query that can be used for filtering resources
  ###
  _selectValidQuerySearchFields: (query) =>
    queryDotString = @_convertKeysToDotStrings query
    queryParamFields = Object.keys @options.queryParams
    validFields = {}
    for field, value of queryDotString
      if field in queryParamFields
        dot.set validFields, field, value
    @_convertKeysToDotStrings validFields

  ###
  Select valid properties from query that can be used for filtering resources in the schema
  ###
  _selectValidResourceSearchFields: (query) =>
    queryDotString = @_convertKeysToDotStrings query
    [resourceFields, modelFields] = @_getResourceAndModelFields()
    validFields = {}
    for field, value of queryDotString
      if field in resourceFields
        dot.set validFields, field, value
    @_convertKeysToDotStrings validFields

  ###
  Collapse all nested dot fields into standard format
  @example {a: {b: 1}} -> {'a.b': 1}
  ###
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

  ###
  Convert resource schema to standard format for easier manipulation
  - converts all keys to dot strings
  - Adds $field, if using implicit model field syntax
  @example
    {
      'test': {
        'property': 'test'
      }
    }
    =>
    {
      'test.property': {
        $field: 'test'
      }
    }
  ###
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
