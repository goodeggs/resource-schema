Model = require './model'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema(Model)

module.exports = app = express()

app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
