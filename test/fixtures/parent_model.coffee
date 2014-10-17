mongoose = require 'mongoose'

schema = new mongoose.Schema
  name: String
  modelIds: [type: mongoose.Schema.ObjectId, ref: 'Model']

module.exports = mongoose.model 'ParentModel', schema
