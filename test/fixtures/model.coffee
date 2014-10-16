mongoose = require 'mongoose'

schema = new mongoose.Schema
  name: type: String
  normal:
    nesting: type: String
  product:
    id: type: mongoose.Schema.ObjectId
    name: type: String
    price: type: Number

module.exports = mongoose.model 'Model', schema
