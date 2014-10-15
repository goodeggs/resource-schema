mongoose = require 'mongoose'

schema = new mongoose.Schema
  name: String

module.exports = mongoose.model 'Model', schema
