dot = require 'dot-component'
_ = require 'underscore'
q = require 'q'
clone = require 'clone'
deepExtend = require './deep_extend'
mongoose = require 'mongoose'
Boom = require 'boom'

RESERVED_KEYWORDS = require './reserved_keywords'

module.exports = class ResourceSchema
  constructor: (@Model, schema, @options = {}) ->
    @schema =
      if schema
        @_normalizeSchema(schema)
      else
        @_generateSchemaFromModel(@Model)

    @resourceFields = Object.keys(@schema)
    @defaultResourceFields = @resourceFields.filter((field) => not @schema[field].optional)

  ###
  Generate middleware to handle GET requests for resource
  ###
  get: (paramId) ->
    if (paramId)
      @_getOne(paramId)
    else
      @_getMany

  _getOne: (paramId) =>
    (req, res, next) =>
      requestContext = {req, res, next}
      return if not @_enforceValidity(req.query, requestContext)

      select = @_getModelSelectFields req.query

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue
      try
        query = @_convertTypes(query)
      catch err
        return next Boom.wrap err

      modelQuery = @Model.findOne(query)
      modelQuery.select(select) if select?
      modelQuery.lean()
      modelQuery.exec (err, model) =>
        return next Boom.wrap(err) if err
        return next Boom.notFound("No resources found with #{paramId} of #{idValue}") if not model?
        @_sendResource(model, requestContext)

  _getMany: (req, res, next) =>
    requestContext = {req, res, next}
    return if not @_enforceValidity(req.query, requestContext)

    @_getMongoQuery(req.query, requestContext).then (mongoQuery) =>
      d = q.defer()
      # normal (non aggregate) resource
      if not @options.groupBy
        modelQuery = @Model.find(mongoQuery)
        modelQuery.select(@_getModelSelectFields req.query)
        modelQuery.lean()

      # aggregate resource
      if @options.groupBy
        modelQuery = @Model.aggregate()
        modelQuery.match(mongoQuery)
        modelQuery.group(@_getGroupQuery())

      limit = @_getLimit req.query
      modelQuery.limit(limit) if limit
      modelQuery.exec(d.makeNodeResolver())
      d.promise
    .then (models) =>
      @_sendResources(models, requestContext)
    .catch (err) =>
      next Boom.wrap(err)

  ###
  Generate middleware to handle POST requests for resource
  ###
  post: ->
    (req, res, next) =>
      requestContext = {req, res, next}
      resource = req.body
      return next Boom.badRequest "POST must have a req.body" if not resource?
      return if not @_enforceValidity(req.query, requestContext)

      if Array.isArray req.body
        @_postMany(req, res, next)
      else
        @_postOne(req, res, next)

  _postOne: (req, res, next) ->
    requestContext = {req, res, next}
    resource = req.body
    return if not @_enforceValidity(resource, requestContext)

    @_extendQueryWithImplicitOptionalFields([resource], requestContext)

    model = @_createModelFromResource resource
    resourceByModelId = {}
    resourceByModelId[model._id.toString()] = resource

    @_buildContext(requestContext, [resource], [model]).then =>
      d = q.defer()
      @_applySetters(resourceByModelId, [model], requestContext)
      model = new @Model(model)
      model.save(d.makeNodeResolver())
      d.promise
    .then (modelSaved) =>
      res.status(201)
      @_sendResource(model, requestContext)
    .catch (err) ->
      next Boom.wrap(err)

  _postMany: (req, res, next) ->
    requestContext = {req, res, next}
    resources = req.body

    for resource in resources
      return if not @_enforceValidity(resource, requestContext)

    @_extendQueryWithImplicitOptionalFields(resources, requestContext)

    resourceByModelId = {}
    models = resources.map (resource) =>
      model = @_createModelFromResource(resource)
      resourceByModelId[model._id.toString()] = resource
      model

    @_buildContext(requestContext, resources, models).then =>
      d = q.defer()
      @_applySetters(resourceByModelId, models, requestContext)
      # use node resolver b/c q does not pass splat arguments
      @Model.create models, (err, modelsSaved...) ->
        d.reject(Boom.wrap err) if err
        d.resolve(modelsSaved)
      d.promise
    .then (modelsSaved) =>
      res.status(201)
      @_sendResources(modelsSaved, requestContext)
    .catch (err) =>
      next Boom.wrap(err)

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
      requestContext = {req, res, next}
      resource = req.body
      return next Boom.badRequest "PUT must have a req.body" if not resource?
      return if not @_enforceValidity(req.query, requestContext)
      return if not @_enforceValidity(req.body, requestContext)

      @_extendQueryWithImplicitOptionalFields([resource], requestContext)

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      model = @_createModelFromResource resource
      model[paramId] = idValue

      resourceByModelId = {}
      resourceByModelId[model._id.toString()] = resource
      @_buildContext(requestContext, [resource], [model]).then =>
        d = q.defer()
        @_applySetters(resourceByModelId, [model], requestContext)
        delete model._id
        @Model.findOneAndUpdate(query, model, {upsert: true}).lean().exec(d.makeNodeResolver())
        d.promise
      .then (model) =>
        return next Boom.notFound() if not model?
        res.status(200)
        @_sendResource(model, requestContext)
      .catch (err) =>
        next Boom.wrap(err)

  _putMany: (req, res, next) =>
    requestContext = {req, res, next}
    resources = req.body
    return next Boom.badRequest "PUT must have a req.body" if not resources?
    return if not @_enforceValidity(req.query, requestContext)
    return if not @_enforceValidity(req.body, requestContext)
    for resource in resources
      return if not @_enforceValidity(resource, requestContext)

    @_extendQueryWithImplicitOptionalFields(resources, requestContext)

    resourceByModelId = {}
    models = resources.map (resource) =>
      model = @_createModelFromResource(resource)
      resourceByModelId[model._id.toString()] = resource
      model

    @_buildContext(requestContext, resources, models).then =>
      @_applySetters(resourceByModelId, models, requestContext)
      savePromises = models.map (model) =>
        d = q.defer()
        modelId = model._id
        throw Boom.badRequest('_id required to update') if not modelId
        delete model._id
        @Model.findByIdAndUpdate(modelId, model, {upsert: true}).lean().exec(d.makeNodeResolver())
        d.promise
      q.all(savePromises)
    .then (updatedModels) =>
      @_sendResources(updatedModels, requestContext)
    .catch (err) ->
      next Boom.wrap(err)

  ###
  Generate middleware to handle DELETE requests for resource
  ###
  delete: (paramId) ->
    (req, res, next) =>
      requestContext = {req, res, next}
      return if not @_enforceValidity(req.query, requestContext)

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue

      @Model.findOneAndRemove(query).exec (err, removedInstance) =>
        return next Boom.wrap(err) if err
        return next Boom.notFound("Resource with id #{idValue} not found from #{@Model.modelName} collection") if not removedInstance?
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
  returns a promise with the query inside it
  ###
  _getMongoQuery: (requestQuery, {req, res, next}) =>
    modelQuery = clone(@options.defaultQuery) or {}
    queryPromises = []

    try
      resourceQuery = @_getResourceQuery requestQuery
    catch err
      deferred = q.defer()
      deferred.reject Boom.wrap err
      return deferred.promise

    for resourceField, value of resourceQuery
      # apply sync finders
      if typeof @schema[resourceField].find is 'function'
        try
          query = @schema[resourceField].find value, {req, res, next}
        catch err
          deferred = q.defer()
          deferred.reject Boom.wrap err
          return deferred.promise
        deepExtend(modelQuery, query)

      # apply async finders
      else if typeof @schema[resourceField].findAsync is 'function'
        do =>
          d = q.defer()
          @schema[resourceField].findAsync value, {req, res, next}, (err, query) =>
            return d.reject Boom.wrap err if err
            deepExtend(modelQuery, query)
            d.resolve()
          queryPromises.push(d.promise)

      # apply model queries
      else if @schema[resourceField].field
        modelQuery[@schema[resourceField].field] = value

    q.all(queryPromises).then -> modelQuery

  _createModelFromResource: (resource, addId) =>
    return if not resource?
    model = {}
    for resourceField, config of @schema
      if config.field
        value = dot.get resource, resourceField
        dot.set(model, config.field, value) if value isnt undefined
    model._id ?= new mongoose.Types.ObjectId()
    model

  _createResourceFromModel: (model, requestContext) =>
    {req} = requestContext
    resource = {}

    resourceSelectFields = @_getResourceSelectFields(req.query)

    #set _id for aggregate resources
    if @options.groupBy?.length
      resource._id = model._id

    #set all other fields
    for resourceField, config of @schema
      # TODO set default select to all fields?
      fieldIsSelected = resourceField in resourceSelectFields
      if fieldIsSelected
        if config.field
          value = dot.get model, config.field
          dot.set(resource, resourceField, value)
        if config.get and typeof config.get is 'object'
          value = model[resourceField]
          dot.set(resource, resourceField, value)
    resource

  ###
  Wait for all setters to update models
  ###
  _applySetters: (resourceByModelId, models, requestContext) =>
    models.forEach (model) =>
      for resourceField, config of @schema
        continue if typeof config.set isnt 'function'
        if not @schema[resourceField].field
          throw new Error "Need to define 'field' for '#{resourceField}' in order to call 'set'"
        setValue = config.set(resourceByModelId[model._id.toString()], requestContext)
        continue if setValue is undefined
        dot.set(model, @schema[resourceField].field, setValue)

  ###
  Wait for all getters to update resources
  ###
  _applyGetters: (resourceByModelId, models, requestContext) =>
    selectedResourceFields = @_getResourceSelectFields(requestContext.req.query)
    for model in models
      resource = resourceByModelId[model._id.toString()]
      for resourceField, config of @schema
        continue if resourceField not in selectedResourceFields
        continue if typeof config.get isnt 'function'
        dot.set resource, resourceField, config.get(model, requestContext)

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
    query.$limit or @options.defaultLimit or 0

  ###
  Get resource fields that will be returned with this request. Reject everything
  that is added or not selected in the query parameters.

  @param [Object] query - query params from client
  @return [Array] resource fields
  ###
  _getResourceSelectFields: (query) =>
    $select = @_getSelectFields(query)

    fields =
      if $select.length
        $select
      else
        @defaultResourceFields

    _(fields).union(@_getAddFields(query))

  ###
  Get all valid $add fields from the query. The add fields are used to
  select optional fields from schema
  @param [Object] query - query params from client
  @returns [Array] valid keys to add from schema
  ###
  _getAddFields: (query) =>
    addFields =
      if typeof query.$add is 'string'
        query.$add.split(' ')
      else if Array.isArray query.$add
        query.$add
      else
        []

    _(addFields).intersection(@resourceFields)

  ###
  Get all valid $select fields from the query. The sekect fields are used to
  similar to mongoose select
  @param [Object] query - query params from client
  @returns [Array] valid keys to add from schema
  ###
  _getSelectFields: (query) =>
    selectFields =
      if typeof query.$select is 'string'
        query.$select.split(' ')
      else if Array.isArray query.$select
        query.$select
      else
        []

    _(selectFields).intersection(@resourceFields)

  ###
  Convert select fields in query, to fields that can be used for
  @param [Object] query - query params from client
  @returns [String] space separated string of model select fields
  ###
  _getModelSelectFields: (query) =>
    resourceSelectFields = @_getResourceSelectFields(query)
    modelSelectFields = resourceSelectFields.map (resourceSelectField) => @schema[resourceSelectField].field
    _.compact(modelSelectFields).join(' ')

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
  _getResourceQuery: (query) =>
    query = @_convertKeysToDotStrings query
    validFields = {}
    for field, value of query
      if field in @resourceFields
        dot.set validFields, field, value
    queryFields = @_convertKeysToDotStrings validFields
    @_convertTypes(queryFields)
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
      instance = Model.schema.paths[schemaKey].instance
      type = switch instance
        when 'Buffer' then mongoose.Types.Buffer
        when 'Boolean' then Boolean
        when 'Date' then Date
        when 'Number' then Number
        when 'ObjectID' then mongoose.Types.ObjectId
        when 'String' then String
      schema[schemaKey] =
        field: schemaKey
        type: type

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
  Enforce validity of object with validate and match on schema
  ###
  _enforceValidity: (obj, {req, res, next}) ->
    validateValue = (key, value) =>
      if @schema[key]?.validate
        if not @schema[key].validate(value)
          throw Boom.badRequest "'#{key}' is invalid"
      if @schema[key]?.match
        if not @schema[key].match.test(value)
          throw Boom.badRequest "'#{key}' is invalid"
      true

    normalizedObj = @_convertKeysToDotStrings(obj)
    try
      for key, value of normalizedObj
        if Array.isArray(value)
          validateValue(key, v) for v in value
        else
          validateValue(key, value)
    catch e
      next e
      return false
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

  @throws a Boom http exception if any of the supplied values are invalid
  ###
  _convertTypes: (obj) ->
    badRequest = (type, key, value) =>
      Boom.badRequest "'#{value}' is an invalid #{type} for field '#{key}'"

    convert = (key, value) =>
      switch @schema[key].type
        when String
          return value
        when Number
          number = parseFloat(value)
          throw badRequest('Number', key, value) if isNaN(number)
          return number
        when Boolean
          if (value is 'true') or (value is true)
            return true
          else if (value is 'false') or (value is true)
            return false
          else
            throw badRequest('Boolean', key, value)
        when Date
          date = new Date(value)
          throw badRequest('Date', key, value) if isNaN(date.getTime())
          return date
        when mongoose.Types.ObjectId
          try
            return new mongoose.Types.ObjectId(value)
          catch
            throw badRequest('ObjectId', key, value)
        # other stuff
        else
          newValue = new @schema[key].type(value)
          return newValue

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
    resourceQuery = @_getResourceQuery req.query
    for resourceField, value of resourceQuery
      if typeof @schema[resourceField].filter is 'function'
        resources = @schema[resourceField].filter value, resources, {req, res, next, models}
    resources

  ###
  Apply all resolvers. Data will be added to requestContext, and can be used inside getters and setters.
  @returns a promise containing requestContext
  ###
  _buildContext: (requestContext, resources, models) ->
    {req, res, next} = requestContext
    resolvePromises = []
    requestContext.resources = resources
    requestContext.models = models
    selectedResourceFields = @_getResourceSelectFields(req.query)

    # options resolvers
    for resolveVar, resolveMethod of @options.resolve
      continue if typeof resolveMethod isnt 'function'
      continue if requestContext[resolveVar]
      do (resolveVar, resolveMethod) =>
        d = q.defer()
        resolveMethod requestContext, (err, result) ->
          if err
            d.reject Boom.wrap(err)
          else
            requestContext[resolveVar] = result
            d.resolve()

        resolvePromises.push d.promise

    # schema resolvers
    for resourceField, config of @schema
      continue if resourceField not in selectedResourceFields
      continue if typeof config.resolve isnt 'object'

      for resolveVar, resolveMethod of config.resolve
        continue if typeof resolveMethod isnt 'function'
        continue if requestContext[resolveVar]
        do (resolveVar, resolveMethod) =>
          d = q.defer()
          resolveMethod requestContext, (err, result) ->
            if err
              d.reject Boom.wrap(err)
            else
              requestContext[resolveVar] = result
              d.resolve()

          resolvePromises.push d.promise

    q.all(resolvePromises).then -> requestContext

  _sendResource: (model, requestContext) ->
    {req, res, next} = requestContext
    resource = @_createResourceFromModel(model, requestContext)
    resourceByModelId = {}
    resourceByModelId[model._id.toString()] = resource
    builtContext = @_buildContext(requestContext, [resource], [model])
    builtContext.then =>
      @_applyGetters(resourceByModelId, [model], requestContext)
      res.body = resource
      next()
    builtContext.catch (err) ->
      next Boom.wrap err

  _sendResources: (models, requestContext) ->
    {req, res, next} = requestContext

    resourceByModelId = {}
    resources = models.map (model) =>
      if not mongoose.Types.ObjectId.isValid(model._id.toString())
        model._id = _(model._id).values().join('|')
      resource = @_createResourceFromModel(model, requestContext)
      resourceByModelId[model._id.toString()] = resource
      resource

    @_buildContext(requestContext, resources, models)
      .then =>
        @_applyGetters(resourceByModelId, models, requestContext)
        @_applyFilters(resources, requestContext)
      .then (resources) =>
        res.body = resources
        next()
      .catch (err) ->
        next Boom.wrap err

  ###
  When doing PUT or POST requests, if an optional field is on the resource, attach
  it to the $add query. The resource should be returned in the same format it was posted.
  ###
  _extendQueryWithImplicitOptionalFields: (resources, requestContext) ->
    {req} = requestContext
    req.query.$add = @_getAddFields(req.query)
    resource = resources[0]
    for own resourceField, config of @schema when config.optional
      if dot.get(resource, resourceField) isnt undefined
        req.query.$add.push(resourceField)
