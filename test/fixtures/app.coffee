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
app.use '/resource_config', require './resource_config'
app.use '/resource_custom_key', require './resource_custom_key'

module.exports = app
