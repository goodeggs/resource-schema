dot = require 'dot-component'
_ = require 'underscore'
q = require 'q'
deepExtend = require './deep_extend'

# peer dependency
try
  ObjectId = require('mongoose').Types.ObjectId
catch err
  throw new Error "Missing peer dependency 'mongoose'"

boom = require 'boom'

keyChecker = require './key_checker'

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

      idValue = req.params[paramId]
      query = {}
      query[paramId] = idValue
      try
        @_convertTypes(query)
      catch err
        return next boom.wrap err

      modelQuery = @Model.findOne(query)
      modelQuery.exec().then (model) =>
        return next boom.notFound("No resources found with #{paramId} of #{idValue}") if not model?
        @_sendResource(model, requestContext)
      .then null, (err) =>
        @_handleRequestError(err, requestContext)

  _getMany: (req, res, next) =>
    requestContext = {req, res, next}
    return if not @_enforceValidity(req.query, requestContext)

    @_getMongoQuery(requestContext).then (mongoQuery) =>
      # normal (non aggregate) resource
      modelQuery = @Model.find(mongoQuery)

      limit = @_getLimit req.query
      modelQuery.limit(limit) if limit
      modelQuery.exec()
    .then (models) =>
      @_sendResources(models, requestContext)
    .then null, (err) =>
      @_handleRequestError(err, requestContext)

  ###
  Generate middleware to handle POST requests for resource
  ###
  post: ->
    (req, res, next) =>
      requestContext = {req, res, next}
      resource = req.body
      return next boom.badRequest "POST must have a req.body" if not resource?
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
      @_applySetters(resourceByModelId, [model], requestContext)
      model = new @Model(model)
      deferred = q.defer()
      model.save (err, modelSaved) ->
        if err?
          deferred.reject(boom.wrap err)
        else
          deferred.resolve(modelSaved)
      deferred.promise
    .then (modelSaved) =>
      res.status(201)
      @_sendResource(modelSaved, requestContext)
    .then null, (err) =>
      @_handleRequestError(err, requestContext)

  _postMany: (req, res, next) ->
    requestContext = {req, res, next}
    resources = req.body

    if not resources.length
      res.body = []
      return next()

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
      # must create custom promise here b/c $q does not pass splat arguments
      @Model.create models, (err, modelsSaved...) ->
        # so that we are compatible with api of both mongoose 3.8.x and 4.0.x...
        modelsSaved = if Array.isArray(modelsSaved[0]) then modelsSaved[0] else modelsSaved

        if err?
          d.reject(boom.wrap err)
        else
          d.resolve(modelsSaved)
      d.promise
    .then (modelsSaved) =>
      res.status(201)
      @_sendResources(modelsSaved, requestContext)
    .then null, (err) =>
      @_handleRequestError(err, requestContext)

  ###
  Generate middleware to handle PUT requests for resource
  ###
  put: (paramId) ->
    if paramId
      @_putOne(paramId)
    else
      @_putMany

  _upsertOne: (query, updatedModel) ->
    deferred = q.defer()

    @Model.findOne query, (err, modelFound) =>
      if err?
        deferred.reject(boom.wrap err)

      model = if modelFound
        delete updatedModel._id

        # Unset any arrays to work around mongoose sub document validation bugs
        _.keys(updatedModel)
          .filter((key) -> updatedModel[key] instanceof Array)
          .forEach((key) -> modelFound[key] = undefined)

        _.extend(modelFound, updatedModel)
      else
        new @Model(updatedModel)

      model.save (err, modelSaved) ->
        if err?
          deferred.reject(boom.wrap err)
        else
          deferred.resolve(modelSaved)

    deferred.promise

  _putOne: (paramId) ->
    (req, res, next) =>
      requestContext = {req, res, next}
      resource = req.body
      return next boom.badRequest "PUT must have a req.body" if not resource?
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
        @_applySetters(resourceByModelId, [model], requestContext)
        @_upsertOne(query, model)
      .then (model) =>
        return next boom.notFound() if not model?
        model = model.toObject()
        res.status(200)
        @_sendResource(model, requestContext)
      .then null, (err) =>
        @_handleRequestError(err, requestContext)

  _putMany: (req, res, next) =>
    requestContext = {req, res, next}
    resources = req.body
    return next boom.badRequest "PUT must have a req.body" if not resources?
    if not resources.length
      res.body = []
      return next()
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
        modelId = model._id
        delete model._id
        throw boom.badRequest('_id required to update') if not modelId
        @_upsertOne({_id: modelId}, model)
      q.all(savePromises)
    .then (updatedModels) =>
      updatedModels = _(updatedModels).invoke 'toObject'
      @_sendResources(updatedModels, requestContext)
    .then null, (err) ->
      @_handleRequestError(err, requestContext)

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
        return next boom.wrap(err) if err
        return next boom.notFound("Resource with id #{idValue} not found from #{@Model.modelName} collection") if not removedInstance?
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
  Build the model query object from the query parameters.
  @returns [Promise]
  ###
  _getMongoQuery: (requestContext) =>
    {req, res, next} = requestContext
    requestQuery = req.query

    modelQuery = @options.find?(requestContext) or {}
    queryPromises = []

    try
      resourceQuery = @_getResourceQuery requestQuery
    catch err
      deferred = q.defer()
      deferred.reject boom.wrap err
      return deferred.promise

    for resourceField, value of resourceQuery
      # apply sync finders
      if typeof @schema[resourceField].find is 'function'
        try
          query = @schema[resourceField].find value, {req, res, next}
        catch err
          deferred = q.defer()
          deferred.reject boom.wrap err
          return deferred.promise
        deepExtend(modelQuery, query)

      # apply async finders
      else if typeof @schema[resourceField].findAsync is 'function'
        do =>
          d = q.defer()
          @schema[resourceField].findAsync value, {req, res, next}, (err, query) =>
            return d.reject boom.wrap err if err
            deepExtend(modelQuery, query)
            d.resolve()
          queryPromises.push(d.promise)

      # apply model queries
      else if @schema[resourceField].field
        if Array.isArray(value)
          modelQuery[@schema[resourceField].field] = { $in: value }
        else
          modelQuery[@schema[resourceField].field] = value

    q.all(queryPromises).then -> modelQuery

  ###
  @param [Object] resource - resource to convert
  @returns [Object] model created from resource
  ###
  _createModelFromResource: (resource) =>
    return if not resource?
    model = {}
    for resourceField, config of @schema
      if config.field
        value = dot.get resource, resourceField
        dot.set(model, config.field, value) if value isnt undefined
    model._id ?= new ObjectId()
    model

  ###
  @param [Object] model - model to convert
  @returns [Object] resource created from model
  ###
  _createResourceFromModel: (model, requestContext) =>
    {req} = requestContext
    resource = {}

    resourceSelectFields = @_getResourceSelectFields(req.query)

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
  Get value to use for limiting query results. Defaults to 10000
  @param [Object] query - query params from client
  @returns [Number] Max number of resources to return in response
  ###
  _getLimit: (query) =>
    query.$limit or @options.limit or 1000

  ###
  Get resource fields that will be returned with this request. Reject everything
  that not added or selected

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
  @returns [Array] valid add fields
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
  Get all valid $select fields from the query. Select fields are used to select
  specific resource fields to return.
  @param [Object] query - query params from client
  @returns [Array] valid select fields
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
  Get model select fields used when querying the models.
  @param [Object] query - query params from client
  @returns [String] space separated string of model select fields
  ###
  _getModelSelectFields: (query) =>
    resourceSelectFields = @_getResourceSelectFields(query)
    modelSelectFields = resourceSelectFields.map (resourceSelectField) => @schema[resourceSelectField].field
    _.compact(modelSelectFields).join(' ')

  ###
  Get resource query object from the query parameters. This query object comes from
  all the non reserved query parameters (e.g. ?name=joe, or ?product[price]=15, not ?$limit=5)
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
  Collapse all nested fields to dot format. Ignore Reserved Keywords on schema.
  @param {Object} obj - object to convert to dot strings
  @param {Function} [shouldIgnore] - optional function to check if you should ignore the key for dot stringifying
  @example {a: {b: 1}} -> {'a.b': 1}
  ###
  _convertKeysToDotStrings: (obj, shouldIgnore) =>
    shouldIgnore ?= -> false
    dotKeys = {}
    dotStringify = (obj, current) ->
      for key, value of obj
        newKey = if current then current + "." + key else key
        if shouldIgnore(key, value)
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
  @returns [Object] new schema
  ###
  _generateSchemaFromModel: (Model) =>
    # Paths already in dot notation
    schemaKeys = Object.keys Model.schema.paths
    if schemaKeys.indexOf('__v') >= 0
      schemaKeys.splice schemaKeys.indexOf('__v'), 1
    schema = {}
    for schemaKey in schemaKeys
      instance = Model.schema.paths[schemaKey].instance
      type = switch instance
        when 'Boolean' then Boolean
        when 'Date' then Date
        when 'Number' then Number
        when 'ObjectID' then ObjectId
        when 'String' then String
      schema[schemaKey] =
        field: schemaKey
        type: type

    _(schema).extend(@_normalizeQueryParams())

    schema

  ###
  Convert resource schema to standard format for easier manipulation
  - converts all keys to dot strings
  - Adds 'field' key, if using shorthand syntax
  @example
    'test': { 'property': 'test' }
    => 'test.property': { field: 'test' }
  ###
  _normalizeSchema: (schema) =>
    schema = @_convertKeysToDotStrings(schema, keyChecker.isReserved)
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
          throw boom.badRequest "'#{key}' is invalid"
      if @schema[key]?.match
        if not @schema[key].match.test(value)
          throw boom.badRequest "'#{key}' is invalid"
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
  - ObjectId and other newable objects

  @throws a boom http exception if any of the supplied values are invalid
  ###
  _convertTypes: (obj) ->
    badRequest = (type, key, value) =>
      boom.badRequest "'#{value}' is an invalid #{type} for field '#{key}'"

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
        when ObjectId
          try
            return new ObjectId(value)
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

    obj

  ###
  Filter down resources with all filter queryParams
  ###
  _applyFilters: (resources, {req, res, next, models}) ->
    resourceQuery = @_getResourceQuery req.query
    for resourceField, value of resourceQuery
      if typeof @schema[resourceField].filter is 'function'
        resources = @schema[resourceField].filter value, resources, {req, res, next, models}
    if typeof @options.filter is 'function'
      resources = @options.filter resources, {req, res, next, models}
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
            d.reject boom.wrap(err)
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
              d.reject boom.wrap(err)
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
    @_buildContext(requestContext, [resource], [model]).then =>
      @_applyGetters(resourceByModelId, [model], requestContext)
      res.body = resource
      next()
    .then null, (err) ->
      next boom.wrap err

  _sendResources: (models, requestContext) ->
    {req, res, next} = requestContext

    resourceByModelId = {}
    resources = models.map (model) =>
      resource = @_createResourceFromModel(model, requestContext)
      resourceByModelId[model._id.toString()] = resource
      resource

    @_buildContext(requestContext, resources, models).then =>
      @_applyGetters(resourceByModelId, models, requestContext)
      @_applyFilters(resources, requestContext)
    .then (resources) =>
      res.body = resources
      next()
    .then null, (err) ->
      next boom.wrap err

  ###
  When doing PUT or POST requests, if optional fields are on the resource, attach
  it to the $add query. The resource should be returned in the same format it was posted.
  ###
  _extendQueryWithImplicitOptionalFields: (resources, requestContext) ->
    {req} = requestContext
    req.query.$add = @_getAddFields(req.query)
    resource = resources[0]
    for own resourceField, config of @schema when config.optional
      if dot.get(resource, resourceField) isnt undefined
        req.query.$add.push(resourceField)

  _handleRequestError: (err, requestContext) ->
    {req, res, next} = requestContext
    return next boom.badRequest(err.message) if err.name in ['CastError', 'ValidationError']
    next boom.wrap(err)
