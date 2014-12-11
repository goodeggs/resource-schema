# Resource Schema

[![NPM version](https://badge.fury.io/js/resource-schema.png)](http://badge.fury.io/js/resource-schema)
[![Build Status](https://travis-ci.org/goodeggs/mongoose-resource.png)](https://travis-ci.org/goodeggs/resource-schema)

Define schemas for RESTful resources from mongoose models, and generate express middleware to GET, POST, PUT, and DELETE to those resources.

## Table of Contents

[Why ResourceSchema]()

## Why ResourceSchema?

ResourceSchema allows you to define complex RESTful resources in a simple and declarative way.

## Example

```coffeescript
schema = {
  '_id': '_id'

  # Get resource field 'name' from model field 'name'
  # Convert the name to lowercase whenever saved
  'name':
    field: 'name'
    set: (productResource) -> productResource.name.toLowerCase()

  # make sure the day matches the specified format before saving
  'day':
    field: 'day'
    match: /[0-9]{4}-[0-9]{2}-[0-9]{2}/

  # Model field 'active' renamed to resource field 'isActive'
  'isActive': 'active'

  # Dynamically get field 'code' whenever the resource is requested:
  'code':
    get: (model) -> model.letter + model.number

  # Dynamically get totalQuantitySold whenever the resource is requested.
  # Resolve 'totalQuantitySoldByProductId' before applying the getter.
  'totalQuantitySold':
    resolve:
      totalQuantitySoldByProductId: ({models}, done) ->
        getTotalQuantitySoldById(models, done)
    get: (productModel, {totalQuantitySoldByProductId}) ->
      totalQuantitySoldByProductId[productModel._id]
}

queryParams =
  # query for products sold on the specified days
  # e.g. api/products?soldOn=2014-10-01&soldOn=2014-10-05
  'soldOn':
    type: String
    isArray: true
    match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
    find: (days) -> { 'day': $in: days }

  # query for products sold in the last week
  # e.g. api/products?fromLastWeek=true
  'fromLastWeek':
    type: Boolean
    find: (days) -> { 'day': $gt: '2014-10-12' }

resource = ResourceSchema(Product, schema, {queryParams})

# generate express middleware that automatically handles GET, POST, PUT, and DELETE requests:
app.get '/products', resource.get(), resource.send
app.post '/products', resource.post(), resource.send
app.put 'products/:_id', resource.put('_id'), resource.send
app.get 'products/:_id', resource.get('_id'), resource.send
app.delete 'products/:_id', resource.delete('_id'), resource.send
```
This abstracts away a lot of the boilerplate such as building queries, validating values, and handling errors, and allows you to focus on higher-level resource design.

## Generating Middleware

Once you have defined a new resource, call get, post, put, or delete to generate the appropriate middleware to handle the request.

``` coffeescript
resource = new ResourceSchema(Model, schema, options)
app.get '/products', resource.get(), (req, res, next) ->
  # resources are on res.body
```
the middleware will attach the resources to res.body, which can then be used by other pieces of middleware, or  sent immediately back to the client

### resource.get()

Generate middleware to handle GET requests for multiple resources.

### resource.post()

Generate middleware to handle POST requests to a resource.

### resource.put()

Generate middleware to handle PUT requests to a resource.

### resource.delete()

Generate middleware to handle DELETE requests to a resource.

### resource.send

Convenience method for sending the resource back to the client.

``` coffeescript
resource = new ResourceSchema(Model, schema, options)
app.get '/products', resource.get(), resource.send
```

## Defining a schema

### field: [String]
Maps a mongoose model field to a resource field.

``` coffeescript
schema = {
  'name': { $field: 'name' }
}
```
We can also define this with a shorthand notation:
``` coffeescript
schema = {
  'name': 'name'
}
```
Or even simpler with coffeescript:
``` coffeescript
schema = {
  'name'
}
```
Note, this can be used to rename a model field to a new name on the resource:
``` coffeescript
schema = {
  'category.name': 'categoryName'
}
# => {
#  category: {
#    name: 'value'
#  }
# }
```

### get: (resource, context) ->

Dynamically get the value whenever a resource is requested. Note, you need to explicitly set the value on each resource

``` coffeescript
schema =
  'fullName':
    get: (resource, {req, res, next}) ->
      resource.firtName + ' ' + resource.lastName
```

### set: (model, context) ->

Dynamically set the value whenever a resource is saved or updated

``` coffeescript
schema = {
  'name': {
    set: (model, {req, res, next}) ->
      model.name.toLowerCase()
  }
}
```

### find: (queryValue, context) ->

Dynamically find resources with the provided query value. Return an object that will extend the mongoose query. $find is used to define query parameters.

``` coffeescript
schema = {
  'soldOn': {
    find: (days, {req, res, next}) ->
      { 'day': $in: days }
  }
}
```

### optional: [Boolean]

If true, do not include the value in the resource unless specifically requested by the client with the '$add' query parameter

``` coffeescript
# GET /api/products?$add=name

schema = {
  'name': {
    optional: true
    field: 'name'
  }
}

```

### validate: (value) ->

Return a 400 invalid request if the provided value does not pass the validation test.

``` coffeescript
schema = {
  'date': {
    validate: (value) ->
      /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/.test(value)
  }
}
```

### match: [RegExp]

Return a 400 invalid request if the provided value does match the given regular expression.

``` coffeescript
schema = {
  'date': {
    match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
  }
}
```

### type: [Object]

Convert the type of the value.

Valid types include

- String
- Date
- Number
- Boolean
- and any other "newable" class

``` coffeescript
schema = {
  'active': {
    type: Boolean
  }
}
```
This is especially useful for query parameters, which are a string by default

### isArray: [Boolean]

Ensure that the query parameter is an Array.

``` coffeescript
schema = {
  'daysToSelect': {
    isArray: Boolean
    find: (days, context, done) -> ...
  }
}
```

## options

### options.defaultLimit

Set the default number of the resources that will be sent for GET requests.

``` coffeescript
new ResourceSchema(Product, schema, {
  defaultLimit: 100
})

```

### options.defaultQuery

Set the default query for this resource. All other query parameters will extend this query.

``` coffeescript
new ResourceSchema(Product, schema, {
  defaultQuery: {
    active: true
    createdAt: $gt: '2013-01-01'
  }
})

```

### options.queryParams

Define query parameters for this resource using the $find method. Note that these query parameters can be defined directly on the schema, but you can define them here if you prefer (since query parameters are often not part of the resource being returned).

```coffeescript
queryParams =
  'soldOn':
    type: String
    isArray: true
    match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
    find: (days) -> { 'day': $in: days }
  'fromLastWeek':
    type: Boolean
    find: (days) -> { 'day': $gt: '2014-10-12' }
```

## Querying the resources

ResourceSchema automatically adds several utilities for interacting with your resources.

### Querying by resource field

Query by any resource field with a $field or a $find attribute.

```
GET /products?name=strawberry
GET /products?categrory[name]=fruit
```
Note that you can query nested fields with Express' [bracket] notation.

### $select

Select fields to return on the resource. Similar to mongoose select.

```
GET /products?$select=name&$select=active
GET /products?$select[]=name&$select[]=active
GET /products?$select=name%20active
```

### $limit

Limit the number of resources to return in the response

```
GET /products?$limit=10
```

### $add

Add an $optional field to the response. See $optional schema fields for more details.

```
GET /products?$add=quantitySold
```

## Working with nested attributes in schemas

List just the nested attributes you care about:

``` coffee
'user.name'
'user.email'
```

Or include the root attribute to include all nested attributes:

``` coffee
'user'
```

You can even add optional attributes:

``` coffee
'user'
'user.note':
  optional: true
```

## Contributing

```
$ git clone https://github.com/goodeggs/resource-schema && cd resource-schema
$ npm install
$ npm test
```

## Code of Conduct

[Code of Conduct](https://github.com/goodeggs/resource-schema/blob/master/CODE_OF_CONDUCT.md)
for contributing to or participating in this project.

## License

[MIT](https://github.com/goodeggs/resource-schema/blob/master/LICENSE.md)
