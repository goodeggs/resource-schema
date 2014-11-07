ParentModel = require './parent_model'
ModelCustomKey = require './model_custom_key'
ParentModel = require './parent_model'
fibrous = require 'fibrous'
_ = require 'underscore'
ResourceSchema = require '../..'
express = require 'express'

schema = {
  'key'
  'name'
}

resource = new ResourceSchema ModelCustomKey, schema

module.exports = app = express()

app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:key', resource.put('key'), resource.send
app.get '/:key', resource.get('key'), resource.send
app.delete '/:key', resource.delete('key'), resource.send
