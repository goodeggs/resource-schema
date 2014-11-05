Model = require './model'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema(Model)

module.exports = app = express()

app.get '/', resource.index(), resource.send
app.post '/', resource.create(), resource.send
app.put '/:_id', resource.update(), resource.send
app.get '/:_id', resource.show(), resource.send
