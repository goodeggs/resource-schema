Model = require './model'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema(Model)

module.exports = app = express()

app.get '/', resource.index(), resource.send
app.post '/', resource.create(), resource.send
app.put '/:modelId', resource.update('modelId'), resource.send
app.get '/:modelId', resource.show('modelId'), resource.send
