express = require 'express'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'

app = express()

app.use bodyParser.json()
app.use bodyParser.urlencoded()
app.use cookieParser()

app.use '/model_resource', require './model_resource'

module.exports = app
