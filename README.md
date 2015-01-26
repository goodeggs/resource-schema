# Resource Schema

[![NPM version](https://badge.fury.io/js/resource-schema.png)](http://badge.fury.io/js/resource-schema)
[![Build Status](https://travis-ci.org/goodeggs/mongoose-resource.png)](https://travis-ci.org/goodeggs/resource-schema)

Define schemas for RESTful resources from mongoose models, and generate express middleware to GET, POST, PUT, and DELETE to those resources.

## Table of Contents

- [Why ResourceSchema?](#why-resourceschema)
- [Install](#install)
- [Creating a Resource](#creating-a-resource)
- [Defining a Schema](#defining-a-schema)
- [options](#options)
- [Generating Middleware](#generating-middleware)
- [Query Parameters](#query-parameters)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Why ResourceSchema?

ResourceSchema allows you to define complex RESTful resources in a simple and declarative way.

```javascript
Product = require './models/product'

var schema = {
  '_id': '_id',

  // Get resource field 'name' from model field 'name'
  // Convert the name to lowercase whenever saved
  'name': {
    field: 'name',
    set: function (productResource) { return productResource.name.toLowerCase(); }
  },

  // make sure the day matches the specified format before saving
  'day': {
    field: 'day',
    match: /[0-9]{4}-[0-9]{2}-[0-9]{2}/
  },

  // Model field 'active' renamed to resource field 'isActive'
  'isActive': 'active',

  // Dynamically get field 'code' whenever the resource is requested:
  'code': {
    get: function (productModel) { productModel.letter + productModel.number }
  },

  // Dynamically get totalQuantitySold whenever the resource is requested.
  // Resolve 'totalQuantitySoldByProductId' before applying the getter.
  'totalQuantitySold': {
    resolve: {
      totalQuantitySoldByProductId: function ({models}, done) {
        getTotalQuantitySoldById(models, done)
      }
    },
    get: function (productModel, {totalQuantitySoldByProductId}) {
      totalQuantitySoldByProductId[productModel._id]
    }
  }

  // field soldOn allows you to query for products sold on the specified days
  // e.g. api/products?soldOn=2014-10-01&soldOn=2014-10-05
  'soldOn': {
    type: String,
    isArray: true,
    match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/,
    find: function (days) { return { 'day': $in: days } }
  },

  // field fromLastWeek allows you to query for products sold in the last week
  // e.g. api/products?fromLastWeek=true
  'fromLastWeek': {
    type: Boolean,
    find: (days) -> { 'day': $gt: '2014-10-12' }
  }
};

var resource = new ResourceSchema(Product, schema);

// generate express middleware that automatically handles GET, POST, PUT, and DELETE requests:
app.get('/products', resource.get(), resource.send);
app.post('/products', resource.post(), resource.send);
app.put('products/:_id', resource.put('_id'), resource.send);
app.get('products/:_id', resource.get('_id'), resource.send);
app.delete('products/:_id', resource.delete('_id'), resource.send);
```
This abstracts away a lot of the boilerplate such as building queries, validating values, and handling errors, and allows you to focus on higher-level resource design.

Additionally, this provides a layer of abstraction which helps decouple your server models from your client.

## Install
```
npm install resource-schema --save
```
## Creating a Resource

### new ResourceSchema(model, [schema], [options])

- **model** - mongoose model to generate the resource from
- **[schema]** - optional object to configure custom resource fields. If no schema is provided, the resource schema is automatically generated from the model schema.
- **[options]** - optional object to configure schema options, like document limits and default mongoose queries.

## Defining a Schema

The schema allows define the shape of your resource. If you do not provide a schema, the resource will look exactly like the model.

We can define the schema using these properties:

- **field** - string that maps a resource field to a mongoose model field.
- **get** - function that dynamically gets the value whenever a resource is requested.
- **set** - function that dynamically sets the value whenever a resource is PUT or POSTed
- **resolve** - TODO
- **find** - function that dynamically builds a mongoose query whenever querying by this field
- **findAsync** - TODO asynchronous version of find
- **optional** - do not include this field in the resource unless specifically requested with the $add query parameter
- **validate** - function that validates the field before saving or updating
- **match** - regexp to validate field before saving
- **type** - convert the type of the field before saving/querying. This is especially for converting query parameters, which default to a string.
- **isArray** - convert value to array before saving/querying. This is especially for converting query parameters, which will not be an array of only querying by on value.


### field: String
Maps a resource field to a mongoose model field.

``` javascript
schema = {
  'name': { field: 'name' }
}
```
We can also define this with a shorthand notation:
``` javascript
schema = {
  'name': 'name'
}
```
Or even simpler with coffeescript:
``` javascript
schema = {
  'name'
}
```

Note, this can be used to rename a model field to a new field on the resource:
``` javascript
schema = {
  'category.name': 'categoryName'
}
// => {
//  category: {
//    name: 'value'
//  }
// }
```

### get: function(model, context)

- **model** - corresponding mongoose model for requested resource
- **context** - object containing req, res, next, and resolved values (see "resolve" for details)

Dynamically get the value whenever a resource is requested.

``` javascript
var schema = {
  'fullName': {
    get: function (resource, context) {
      resource.firtName + ' ' + resource.lastName
    }
  }
}
```

### set: function(resource, context)

- **resource** - resource saved by client
- **context** - object containing req, res, next, and resolved values (see "resolve" for details)

Function that dynamically sets the value whenever a resource is saved or updated.

``` javascript
var schema = {
  'name': {
    set: function (resource, context) {
      return resource.name.toLowerCase()
    }
  }
}
```

### find: function(value, context)

- **value** - value of query parameter from client
- **context** - object containing req, res, next, and resolved values (see "resolve" for details)

Function that dynamically builds a mongoose query whenever querying by this field. Return an object that will extend the mongoose query.

``` javascript
var schema = {
  'soldOn': {
    find: function (days, context) {
      return { 'day': $in: days }
    }
  }
}
```

### optional: Boolean

If true, do not include this field in the resource unless specifically requested with the $add query parameter

``` javascript
// GET /api/products?$add=name

var schema = {
  'name': {
    optional: true
    field: 'name'
  }
}

```

### validate: function(value)

- **value** - value of query parameter from client, or value on object

Return a 400 invalid request if the provided value does not pass the validation test.

``` javascript
var schema = {
  'date': {
    validate: function(value) {
      return /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/.test(value)
    }
  }
}
```

### match: RegExp

Return a 400 invalid request if the provided value does match the given regular expression.

``` javascript
var schema = {
  'date': {
    match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
  }
}
```

### type: Object

Convert the type of the value.

Valid types include

- String
- Date
- Number
- Boolean
- and any other "newable" class

``` javascript
schema = {
  'active': {
    type: Boolean
  }
}
```
This is especially useful for query parameters, which are a string by default

### isArray: Boolean

Convert value to array before saving/querying. This is especially for converting query parameters, which will not be an array if only querying by on value.

``` javascript
schema = {
  'daysToSelect': {
    isArray: true
    find: function(days, context) { ... }
  }
}
```

## options

Options allow you to make configurations for the entire resource.

### filter: function(models)

- **models** - all models found from the query

Filter limits resources returned from every GET request.

``` javascript
new ResourceSchema(Model, schema, {
  filter: function(models) {
    models.filter(function(model) {
      return model.isActive
    })
  }
})

```
### defaultLimit: Number

Limit the number of returned documents for GET requests. Defaults to 1000.

``` javascript
new ResourceSchema(Model, schema, {
  defaultLimit: 100
})

```

### defaultQuery: Object

Set the default query for this resource. All other query parameters will extend this query.

``` javascript
new ResourceSchema(Product, schema, {
  defaultQuery: {
    active: true,
    createdAt: $gt: '2013-01-01'
  }
})

```

### queryParams: Object

Define query parameters for this resource. Note, you could define these directly on the schema, but some people prefer to separate query parameters from all other fields.

```javascript
new ResourceSchema(Product, schema, {
  queryParams: {
    'soldOn': {
      type: String,
      isArray: true,
      match: /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/,
      find: function(days) {
        return { 'day': $in: days }
      }
    },
    'fromLastWeek': {
      type: Boolean,
      find: function(days) {
        return { 'day': $gt: '2014-10-12' }
      }
    }
  }
})

```

## Generating Middleware

Once define a new resource, call .get(), .post(), .put(), or .delete() to generate the appropriate middleware to handle the request.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.get('/products', resource.get(), function(req, res, next) {
  # resources on res.body
});
```
The middleware will attach the resources to res.body, which can be used by other middleware, or sent immediately back to the client.

### get()

Handle bulk GET requests. Results can by filtered by query parameters. Limits response to 1000 resources by default.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.get('/products', resource.get(), function(req, res, next) {
  // resources on res.body
});

// GET /products?name=magicbox
```

### get(idField)

- **idField** - field to use as resource identifier. Note, this must match the field name defined on the resource and the name on req.params.

Handle GET requests for single resource.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.get('/products/:_id', resource.get('_id'), function(req, res, next) {
  // resources on res.body
});

// GET /products/1234
// => {
//  _id: 1234
//  name: 'banana bread'
// }
```

### post()

Handle POST requests. Can take a single resource or an array of resources.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.post('/products', resource.post(), function(req, res, next) {
  // resources on res.body
});

// POST /products
// {
//  _id: 1234
//  name: 'banana bread'
// }
//
// or
//
// POST /products
// [
//  {
//    _id: 1234
//    name: 'banana bread'
//  },
//  {
//    _id: 4567
//    name: 'apples'
//  }
// ]
```

### put(idField)

- **idField** - field to use as resource identifier. Note, this must match the field name defined on the resource and the name on req.params.

Generate middleware to handle PUT requests to a resource. This does an upsert, so if the resource does not exist, it will create one.

This will handle bulk PUT requests as well, automatically reading the idField and upserting for each resource.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.put('/products/:_id', resource.put('_id'), function(req, res, next) {
  // resources on res.body
});

// PUT /products/1234
// {
//  _id: 1234
//  name: 'banana bread'
// }
//
// or
//
// PUT /products
// [
//  {
//    _id: 1234
//    name: 'banana bread'
//  },
//  {
//    _id: 4567
//    name: 'apples'
//  }
// ]
```

### delete(idField)

- **idField** - field to use as resource identifier. Note, this must match the field name defined on the resource and the name on req.params.

Generate middleware to handle DELETE requests to a single resource.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.delete('/products/:_id', resource.delete('_id'), function(req, res, next) {
  // resources on res.body
});

// DELETE /products/1234
```

### send

Convenience method for sending the resources on res.body back to the client.

``` javascript
var resource = new ResourceSchema(Model, schema, options);
app.get('/products', resource.get(), resource.send);
```

## Query Parameters

ResourceSchema allows you to use a variety of query parameters to interact with your resources.

### $select

Select fields to return on the resource. Similar to mongoose select.

```
GET /products?$select=name&$select=active
GET /products?$select[]=name&$select[]=active
GET /products?$select=name active
```

### $limit

Limit the number of resources to return in the response

```
GET /products?$limit=10
```

### $add

Add an optional field to the resource. See optional schema field for more details.

```
GET /products?$add=quantitySold
```

### querying resource fields

Query by any resource field with a field, find, or filter attribute.

```
GET /products?name=strawberry
GET /products?categrory[name]=fruit
```
Note that you can query nested fields with Express' [bracket] notation.


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
