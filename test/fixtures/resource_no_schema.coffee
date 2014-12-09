Model = require './model'
ResourceSchema = require '../..'
express = require 'express'
mongoose = require 'mongoose'

queryParams =
  ids:
    isArray: yes
    type: mongoose.Types.ObjectId
    find: (ids) -> _id: $in: ids

resource = new ResourceSchema(Model, null, {queryParams})

module.exports = app = express()

app.get '/', resource.get(), resource.send
app.post '/', resource.post(), resource.send
app.put '/:_id', resource.put('_id'), resource.send
app.get '/:_id', resource.get('_id'), resource.send
