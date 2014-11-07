mongoose = require 'mongoose'

schema = new mongoose.Schema
  name: type: String
  lastName: type: String
  day: type: String
  product:
    id: type: mongoose.Schema.ObjectId
    name: type: String
    price: type: Number
  normal:
    nesting: type: String
  productCount: type: Number

module.exports = mongoose.model 'Model', schema
