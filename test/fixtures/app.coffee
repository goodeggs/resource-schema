express = require 'express'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'

app = express()

app.use bodyParser.json()
app.use bodyParser.urlencoded()
app.use cookieParser()

app.use '/resource', require './resource'
app.use '/resource_no_schema', require './resource_no_schema'
app.use '/resource_aggregate', require './resource_aggregate'
app.use '/resource_multiple_aggregate', require './resource_multiple_aggregate'

module.exports = app
