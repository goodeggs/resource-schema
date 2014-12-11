dot = require 'dot-component'
_ = require 'underscore'
q = require 'q'
clone = require 'clone'
deepExtend = require './deep_extend'
mongoose = require 'mongoose'

RESERVED_KEYWORDS = require './reserved_keywords'

module.exports = class ResourceSchema
  constructor: (@Model, schema, @options = {}) ->
    @schema =
      if schema
        @_normalizeSchema(schema)
      else
        @_generateSchemaFromModel(@Model)

  ###
  Generate middleware to handle GET requests for resource
  ###
  get: (paramId) ->
    if (paramId)
      @_getOne(paramId)
    else
      @_getMany

  _getMany: (req, res, next) =>
    context = {req, res, next}
    return if not @_isValid(req.query, context)

    limit = @_getLimit req.query
    modelSelect = @_getModelSelectFields req.query
    @_getMongoQuery(req.query, context)
    .then (mongoQuery) =>
      # normal (non aggregate) resource
      if not @options.groupBy
        modelQuery = @Model.find(mongoQuery)
        modelQuery.select(modelSelect)
        modelQuery.lean()

      # aggregate resource
      if @options.groupBy
        modelQuery = @Model.aggregate()
        modelQuery.match(mongoQuery)
        modelQuery.group(@_getGroupQuery())

      modelQuery.limit(limit) if limit?
      modelQuery.exec (err, models) =>
        if err then return next err
        @_sendResources(models, context)

  _getOne: (paramId) =>
    (req, res, next) =>
      context = {req, res, next}
      return if not @_isValid(req.query, context)

      select = @_getModelSelectFields req.query

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      modelQuery = @Model.findOne(query)
      modelQuery.select(select) if select?
      modelQuery.lean()
      modelQuery.exec (err, model) =>
        return res.status(400).send(err) if err
        return res.status(404).send("No #{paramId} found with id #{idValue}") if not model?
        @_sendResource(model, context)

  ###
  Generate middleware to handle POST requests for resource
  ###
  post: ->
    (req, res, next) =>
      return if not @_isValid(req.query, context)

      if Array.isArray req.body
        @_postMany(req, res, next)
      else
        @_postOne(req, res, next)

  _postOne: (req, res, next) ->
    context = {req, res, next}
    resource = req.body
    return if not @_isValid(resource, context)
    # TODO: is this necessary here? Mongoose will catch type problems...
    @_convertTypes(resource, context)
    model = @_createModelFromResource resource
    model._id = new mongoose.Types.ObjectId()
    resourceByModelId = {}
    resourceByModelId[model._id.toString()] = resource
    @_applyResolvers(context, [resource], [model])
    .then =>
      @_applySetters(resourceByModelId, [model], context)
      model = new @Model(model)
      model.save (err, modelSaved) =>
        return res.status(400).send(err) if err
        res.status(201)
        @_sendResource(model, context)

  _postMany: (req, res, next) ->
    context = {req, res, next}
    resources = req.body
    for resource in resources
      return if not @_isValid(resource, context)
    resourceByModelId = {}
    models = resources.map (resource) =>
      @_convertTypes(resource, context)
      model = @_createModelFromResource(resource)
      model._id = new mongoose.Types.ObjectId()
      resourceByModelId[model._id.toString()] = resource
      model
    @_applyResolvers(context, resources, models)
    .then =>
      @_applySetters(resourceByModelId, models, context)
      @Model.create models, (err, modelsSaved...) =>
        return res.status(400).send(err) if err
        res.status(201)
        @_sendResources(modelsSaved, context)

  ###
  Generate middleware to handle PUT requests for resource
  ###
  put: (paramId) ->
    if paramId
      @_putOne(paramId)
    else
      @_putMany

  _putOne: (paramId) ->
    (req, res, next) =>
      context = {req, res, next}
      return if not @_isValid(req.query, context)
      return if not @_isValid(req.body, context)
      resource = req.body

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      model = @_createModelFromResource resource
      try
        model._id ?= new mongoose.Types.ObjectId(idValue)
      catch
        model._id ?= new mongoose.Types.ObjectId()

      resourceByModelId = {}
      resourceByModelId[model._id.toString()] = resource

      @_applyResolvers(context, [resource], [model])
      .then =>
        @_applySetters(resourceByModelId, [model], context)
        @Model.findOneAndUpdate(query, model, {upsert: true}).lean().exec (err, model) =>
          return res.send 400, err if err
          return res.send 404, 'resource not found' if !model
          res.status(200)
          @_sendResource(model, context)

  _putMany: (req, res, next) =>
    context = {req, res, next}
    return if not @_isValid(req.query, context)
    return if not @_isValid(req.body, context)
    resources = req.body
    for resource in resources
      return if not @_isValid(resource, context)
    resourceByModelId = {}
    models = resources.map (resource) =>
      @_convertTypes(resource, context)
      model = @_createModelFromResource(resource)
      resourceByModelId[model._id.toString()] = resource
      model

    @_applyResolvers(context, resources, models)
    .then =>
      @_applySetters(resourceByModelId, models, context)
      savePromises = []
      models.forEach (model) =>
        d = q.defer()
        modelId = model._id
        return res.send 400, '_id required to update' if not modelId
        @Model.findByIdAndUpdate(modelId, model, {upsert: true}).lean().exec (err, model) =>
          return res.send 400, err if err
          d.resolve(model)
        savePromises.push d.promise

      q.all(savePromises).then (updatedModels) =>
        @_sendResources(updatedModels, context)

  ###
  Generate middleware to handle DELETE requests for resource
  ###
  delete: (paramId) ->
    (req, res, next) =>
      context = {req, res, next}
      return if not @_isValid(req.query, context)

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      @Model.findOneAndRemove query, (err, removedInstance) =>
        return res.status(400).send(err) if err
        res.status(404).send("Resource with id #{idValue} not found from #{@Model.modelName} collection") if !removedInstance?

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
  Build the model query from the query parameters
  ###
  _getMongoQuery: (requestQuery, {req, res, next}) =>
    modelQuery = clone(@options.defaultQuery) or {}
    deferred = q.defer()
    queryPromises = []
    resourceQuery = @_getResourceQuery requestQuery, {req, res, next}

    for resourceField, value of resourceQuery
      # apply sync finders
      if typeof @schema[resourceField].find is 'function'
        query = @schema[resourceField].find value, {req, res, next}
        deepExtend(modelQuery, query)

      # apply async finders
      else if typeof @schema[resourceField].findAsync is 'function'
        do =>
          d = q.defer()
          @schema[resourceField].findAsync value, {req, res, next}, (err, query) =>
            return res.status(400).send (err.toString()) if err
            deepExtend(modelQuery, query)
            d.resolve()
          queryPromises.push(d.promise)

      # apply model queries
      else if @schema[resourceField].field
        modelQuery[@schema[resourceField].field] = value


    q.all(queryPromises).then ->
      deferred.resolve(modelQuery)

    deferred.promise

  _createModelFromResource: (resource) =>
    model = {}
    for resourceField, config of @schema
      if config.field
        value = dot.get resource, resourceField
        dot.set(model, config.field, value) if value isnt undefined
    model

  _createResourceFromModel: (model, resourceFields) =>
    resource = {}

    resourceFields = resourceFields.split(' ') if typeof resourceFields is 'string'

    #set _id for aggregate resources
    if @options.groupBy?.length
      resource._id = model._id

    #set all other fields
    for resourceField, config of @schema
      # TODO set default select to all fields?
      if fieldIsSelectable = !resourceFields? or resourceField in resourceFields
        if config.field
          value = dot.get model, config.field
          dot.set(resource, resourceField, value)
        if config.get and typeof config.get is 'object'
          value = model[resourceField]
          dot.set(resource, resourceField, value)
    resource

  ###
  Wait for all set queries to update models
  ###
  _applySetters: (resourceByModelId, models, context) =>
    {req, res, next} = context
    models.forEach (model) =>
      for resourceField, config of @schema
        continue if typeof config.set isnt 'function'
        model[@schema[resourceField].field] = config.set(resourceByModelId[model._id], context)

  ###
  Wait for all get queries to update resources
  ###
  _applyGetters: (resourceByModelId, models, context) =>
    {req, res, next, models} = context
    selectedResourceFields = @_getSelectedResourceFields(req.query)
    for model in models
      resource = resourceByModelId[model._id.toString()]
      for resourceField, config of @schema
        continue if resourceField not in selectedResourceFields
        continue if typeof config.get isnt 'function'
        resource[resourceField] = config.get(model, context)

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
      if config.field
        groupQuery[field] = $first: '$' + config.field
      else if config.get and typeof config.get is 'object'
        groupQuery[field] = config.get
    groupQuery

  ###
  Get value to use for limiting query results
  @param [Object] query - query params from client
  @returns [Number] Max number of resources to return in response
  ###
  _getLimit: (query) =>
    query.$limit or @options.defaultLimit

  ###
  Get resource fields that will be returned with this request. Reject everything
  that is added or not selected in the query parameters.

  @param [Object] query - query params from client
  @return [Array] resource fields
  ###
  _getSelectedResourceFields: (query) =>
    [resourceFields] = @_getResourceAndModelFields()
    select = query.$select

    resourceFields =
      if select
        select = select.split(' ') if typeof select is 'string'
        _(select).intersection resourceFields
      else
        _(resourceFields).reject (resourceField) => @schema[resourceField].optional

    _.union(resourceFields, @_getAddFields(query))

  ###
  Get all valid $add fields from the query. The add fields are used to
  select optional fields from schema
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
        resourceFields = _(select).intersection resourceFields
        resourceFields.map (resourceSelectField) => @schema[resourceSelectField].field
      else
        resourceFields.map (resourceField) =>
          if @schema[resourceField].field and (not @schema[resourceField].optional or resourceField in addFields)
            @schema[resourceField].field

    _(modelSelectFields).compact().join(' ')

  ###
  Remove all invalid query parameters (not in schema) and reserved query
  parameters (like $limit and $add).
  @param [Object] query - query params from client
  @returns [Object] valid query params and values
  @example
    GET /products?$limit=10&name=apple&loaded[at]=2014-10-01
    => {
      'name': 'apple'
      'loaded.at': '2014-10-01'
    }
  ###
  _getResourceQuery: (query, {req, res, next}) =>
    query = @_convertKeysToDotStrings query
    [resourceFields, modelFields] = @_getResourceAndModelFields()
    validFields = {}
    for field, value of query
      if field in resourceFields
        dot.set validFields, field, value
    queryFields = @_convertKeysToDotStrings validFields
    @_convertTypes(queryFields, {req, res, next})
    queryFields or {}

  ###
  Collapse all nested fields to dot format. Ignore Reserved Keywords.
  This is used for the schema, the query params, and the incoming resources
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
        # do not dot stringify array
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
    modelFields = resourceFields.map (resourceField) => @schema[resourceField].field
    [_.compact(resourceFields), _.compact(modelFields)]

  ###
  If no schema provided, generate a schema that directly mirrors the mongoose model fields
  @param [Object] Model - Model to generate schema from
  ###
  _generateSchemaFromModel: (Model) =>
    # Paths already in dot notation
    schemaKeys = Object.keys Model.schema.paths
    schemaKeys.splice schemaKeys.indexOf('__v'), 1
    schema = {}
    for schemaKey in schemaKeys
      schema[schemaKey] =
        field: schemaKey

    _(schema).extend(@_normalizeQueryParams())

    schema

  ###
  Convert resource schema to standard format for easier manipulation
  - converts all keys to dot strings
  - Adds field, if using implicit model field syntax
  @example
    {
      'test': {
        'property': 'test'
      }
    }
    =>
    {
      'test.property': {
        field: 'test'
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
            field: config
        else
          throw new Error "No model provided for field #{key}, and no default model provided"
      else
        normalizedSchema[key] = config

    _(normalizedSchema).extend(@_normalizeQueryParams())

    normalizedSchema

  _normalizeQueryParams: =>
    normalizedParams = {}
    if @options.queryParams
      for param, config of @options.queryParams
        if typeof config is 'function'
          normalizedParams[param] = find: config
        else if typeof config is 'object'
          normalizedParams[param] = config
        else
          throw new Error("QueryParam config for #{param} must be either a configuration object or a function")
    normalizedParams

  ###
  Check validity of object with validate and match on schema
  ###
  _isValid: (obj, {req, res, next}) ->
    validateValue = (key, value, res) =>
      if @schema[key]?.validate
        if not @schema[key].validate(value)
          res.status(400).send("'#{key}' is invalid")
          return false
      if @schema[key]?.match
        if not @schema[key].match.test(value)
          res.status(400).send("'#{key}' is invalid")
          return false
      true

    normalizedObj = @_convertKeysToDotStrings(obj)
    for key, value of normalizedObj
      if Array.isArray(value)
        for v in value
          return false if not validateValue(key, v, res)
      else
        return false if not validateValue(key, value, res)
    true

  ###
  By default, all query parameters are sent as strings.
  This method converts those strings to the appropriate types for data manipulation
  Supports:
  - String
  - Date
  - Number
  - Boolean
  - mongoose.Types.ObjectId and other newable objects
  ###
  _convertTypes: (obj, {req, res, next}) ->
    send400 = (type, key, value) =>
      return res.status(400).send("'#{value}' is an invalid Date for field '#{key}'")

    convert = (key, value) =>
      switch @schema[key].type
        when String
          return value
        when Number
          number = parseFloat(value)
          send400('Number', key, value) if isNaN(number)
          return number
        when Boolean
          if (value is 'true') or (value is true)
            return true
          else if (value is 'false') or (value is true)
            return false
          else
            send400('Boolean', key, value)
        when Date
          date = new Date(value)
          send400('Date', key, value) if isNaN(date.getTime())
          return date
        # mongoose.Types.ObjectId, etc.
        else
          try
            newValue = new @schema[key].type(value)
            return newValue
          catch e
            res.status(400).send e.toString()

    for key, value of obj
      continue if not @schema[key]?.type?
      if @schema[key]?.isArray
        obj[key] = [value] if not Array.isArray(value)
        for i, v of obj[key]
          obj[key][i] = convert(key, v)
      else
        obj[key] = convert(key, value)

  ###
  Filter down resources with all filter queryParams
  ###
  _applyFilters: (resources, {req, res, next, models}) ->
    resourceQuery = @_getResourceQuery req.query, {req, res, next}
    for resourceField, value of resourceQuery
      if typeof @schema[resourceField].filter is 'function'
        resources = @schema[resourceField].filter value, resources, {req, res, next, models}
    resources

  ###
  Apply all resolvers. Data will be added to context, and can be used inside getters and setters.
  ###
  _applyResolvers: (context, resources, models) ->
    {req, res, next} = context

    resolvePromises = []
    context.resources = resources
    context.models = models
    selectedResourceFields = @_getSelectedResourceFields(req.query)

    for resourceField, config of @schema
      continue if resourceField not in selectedResourceFields
      continue if typeof config.resolve isnt 'object'

      for resolveVar, resolveMethod of config.resolve
        continue if typeof resolveMethod isnt 'function'
        continue if context[resolveVar]
        do =>
          d = q.defer()
          resolveMethod context, (err, result) ->
            context[resolveVar] = result
            d.resolve()

          resolvePromises.push d.promise

    q.all(resolvePromises)

  _sendResource: (model, context) ->
    {req, res, next} = context
    resource = @_createResourceFromModel(model, req.query.$select)
    resourceByModelId = {}
    resourceByModelId[model._id.toString()] = resource
    @_applyResolvers(context, [resource], [model])
    .then =>
      @_applyGetters(resourceByModelId, [model], context)
      res.body = resource
      next()

  _sendResources: (models, context) ->
    {req, res, next} = context

    resourceByModelId = {}
    resources = models.map (model) =>
      if model._id not instanceof mongoose.Types.ObjectId and typeof model._id is 'object'
        model._id = _(model._id).values().join('|')
      resource = @_createResourceFromModel(model, req.query.$select)
      resourceByModelId[model._id.toString()] = resource
      resource

    @_applyResolvers(context, resources, models)
    .then =>
      @_applyGetters(resourceByModelId, models, context)
      @_applyFilters(resources, context)
    .then (resources) =>
      res.body = resources
      next()
