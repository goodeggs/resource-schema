Model = require './model'
ResourceSchema = require '../..'
express = require 'express'

resource = new ResourceSchema(Model)

module.exports = app = express()

app.get '/', resource.query()
app.post '/', resource.create()
app.put '/:modelId', resource.update('modelId')
app.get '/:modelId', resource.show('modelId')
