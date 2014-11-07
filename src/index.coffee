dot = require 'dot-component'
_ = require 'underscore'
q = require 'q'

RESERVED_KEYWORDS = ['$find', '$get', '$set', '$field', '$optional']

###
normalized schema:
{
  normalField: {
    $optional: true
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
  Generate middleware to handle GET requests for resource
  ###
  get: (paramId) ->
    if (paramId)
      return @_getOne(paramId)
    else
      return @_getAll

  _getAll: (req, res, next) =>
    sendResources = (err, modelsFound) =>
      resources = modelsFound.map (modelFound) =>
        @_createResourceFromModel(modelFound, req.query.$select)

      @_resolveResourceGetPromises(resources, modelsFound, req.query).then =>
        res.body = resources
        next()

    limit = @_getLimit req.query
    modelSelect = @_getModelSelectFields req.query
    @_getQueryConfigPromise(req.query).then (queryConfig) =>
      if @options.groupBy
        modelQuery = @Model.aggregate()
        modelQuery.match(queryConfig)
        modelQuery.group(@_getGroupQuery())

      if not @options.groupBy
        modelQuery = @Model.find(queryConfig)
        modelQuery.select(modelSelect)
        modelQuery.lean()

      modelQuery.limit(limit) if limit?
      modelQuery.exec sendResources

  _getOne: (paramId) =>
    (req, res, next) =>
      select = @_getModelSelectFields req.query

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      modelQuery = @Model.findOne(query)
      modelQuery.select(select) if select?
      modelQuery.lean()
      modelQuery.exec (err, modelFound) =>
        if err
          return res.status(400).send err
        if not modelFound?
          return res.status(404).send "No #{paramId} found with id #{idValue}"

        resource = @_createResourceFromModel(modelFound, req.query.$select)
        @_resolveResourceGetPromises([resource], [modelFound], req.query).then =>
          res.body = resource
          next()

  ###
  Generate middleware to handle POST requests for resource
  ###
  post: ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body
      model = new @Model(newModelData)
      model.save (err, modelSaved) =>
        res.send 400, err if err
        resource = @_createResourceFromModel(modelSaved, req.query.$select)
        res.status(201)
        res.body = resource
        next()

  ###
  Generate middleware to handle PUT requests for resource
  ###
  put: (paramId) ->
    (req, res, next) =>
      newModelData = @_createModelFromResource req.body

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      # if using mongoose timestamps plugin:
      # since we are not updating an instance of mongoose, we need to manually add the updatedAt timestamp
      # newModelData.updatedAt = new Date() if newModelData.updatedAt
      @Model.findOne(query).lean().exec (err, modelFound) =>
        @_resolveResourceSetPromises(req.body, modelFound, {}).then =>
          @Model.findOneAndUpdate(query, newModelData, {upsert: true}).lean().exec (err, modelUpdated) =>
            res.send 400, err if err
            res.send 404, 'resource not found' if !modelUpdated
            resource = @_createResourceFromModel(modelUpdated, req.query.$select)
            res.status(200)
            res.body = resource
            next()

  ###
  Generate middleware to handle DELETE requests for resource
  ###
  delete: (paramId) ->
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
    modelQuery = _.clone(@options.defaultQuery) or {}
    deferred = q.defer()
    queryPromises = []
    resourceSearchFields = @_selectValidResourceSearchFields requestQuery
    querySearchFields = @_selectValidQuerySearchFields requestQuery

    if resourceSearchFields
      for resourceField, value of resourceSearchFields
        if @schema[resourceField].$find
          d = q.defer()
          @schema[resourceField].$find value, (err, query) ->
            _(modelQuery).extend(query)
            d.resolve()
          queryPromises.push(d.promise)
        else if @schema[resourceField].$field
          modelQuery[@schema[resourceField].$field] = value

    if querySearchFields
      for queryField, value of querySearchFields
        d = q.defer()
        @options.queryParams[queryField] value, (err, query) ->
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
        dot.set(model, config.$field, value) if value isnt undefined
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
          dot.set(resource, resourceField, value)
        # TODO: helper for this
        if config.$get and typeof config.$get is 'object'
          value = model[resourceField]
          dot.set(resource, resourceField, value)
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
    query.$limit or @options.defaultLimit or 100

  ###
  Get value to use for limiting query results
  @param [Object] query - query params from client
  ###
  _getResourceSelectFields: (query) =>
    [resourceFields] = @_getResourceAndModelFields()
    select = query.$select

    resourceSelectFields =
      if select
        select = select.split(' ') if typeof select is 'string'
        _(select).intersection resourceFields
      else
        _(resourceFields).reject (resourceField) => @schema[resourceField].$optional

    _.union(resourceSelectFields, @_getAddFields(query))

  ###
  Get all valid $add fields from the query. Used to select $optional fields from schema
  @param [Object] query - query params from client
  @returns [Array] valid keys to add from schema
  ###
  _getAddFields: (query) =>
    [resourceFields] = @_getResourceAndModelFields()

    addFields =
      if typeof query.$add is 'string'
        query.$add.split(' ')
      else if Array.isArray query.$add
        query.$add
      else
        []

    _(addFields).intersection(resourceFields)

  ###
  Convert select fields in query, to fields that can be used for
  @param [Object] query - query params from client
  ###
  _getModelSelectFields: (query) =>
    [resourceFields, modelFields] = @_getResourceAndModelFields()
    select = query.$select
    addFields = @_getAddFields(query)

    modelSelectFields =
      if select
        select = select.split(' ') if typeof select is 'string'
        resourceSelectFields = _(select).intersection resourceFields
        resourceSelectFields.map (resourceSelectField) => @schema[resourceSelectField].$field
      else
        resourceFields.map (resourceField) =>
          if @schema[resourceField].$field and (not @schema[resourceField].$optional or resourceField in addFields)
            @schema[resourceField].$field

    _(modelSelectFields).compact().join(' ')

  ###
  Select valid properties from query that can be used for filtering resources
  @param [Object] query - query params from client
  @returns [Object] valid query fields and their values
  ###
  _selectValidQuerySearchFields: (query) =>
    return {} if not @options.queryParams
    queryDotString = @_convertKeysToDotStrings query
    queryParamFields = Object.keys @options.queryParams
    validFields = {}
    for field, value of queryDotString
      if field in queryParamFields
        dot.set validFields, field, value
    @_convertKeysToDotStrings validFields

  ###
  Select valid properties from query that can be used for filtering resources in the schema
  @param [Object] query - query params from client
  @returns [Object] valid resource search fields and their values
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
  Collapse all nested fields dot format
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
        else if Array.isArray value
          dotKeys[newKey] = value
        else if value and typeof value is "object"
          dotStringify(value, newKey)
        else
          dotKeys[newKey] = value
    dotStringify(obj)
    return dotKeys

  _getResourceAndModelFields: =>
    resourceFields = Object.keys @schema
    modelFields = resourceFields.map (resourceField) => @schema[resourceField].$field
    [_.compact(resourceFields), _.compact(modelFields)]

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
