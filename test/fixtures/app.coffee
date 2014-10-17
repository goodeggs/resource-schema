express = require 'express'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'

app = express()

app.use bodyParser.json()
app.use bodyParser.urlencoded()
app.use cookieParser()

app.use '/resource', require './resource'
app.use '/resource_no_schema', require './resource_no_schema'
app.use '/resource_dynamic_get', require './resource_dynamic_get'

module.exports = app
