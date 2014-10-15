mongoose = require 'mongoose'

schema = new mongoose.Schema
  name: type: String
  product:
    id: type: mongoose.Schema.ObjectId
    name: type: String
    value: type: Number

module.exports = mongoose.model 'Model', schema
