mongoose = require 'mongoose'

schema = new mongoose.Schema
  key: type: String, unique: true, required: true
  name: type: String

module.exports = mongoose.model 'ModelCustomKey', schema
