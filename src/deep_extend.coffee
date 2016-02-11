###
Extends in such a way that we can merge query configuration objects without
clobbering any queries for the same property - when in doubt, `AND` the queries.
# e.g. {'day': $gt: '2014-10-1'}, {day: $lt: '2014-11-1'} =>
# {'day': $and: [{$gt: '2014-10-1'}, {$lt: '2014-11-1'}]}
###

module.exports = (obj, obj2) ->
  for key, config of obj2
    if obj[key]?
      if key isnt '$and'
        obj.$and = [
          {"#{key}": config}
          {"#{key}": obj[key]}
        ]
        delete obj[key]
      else
        # Special case for $and: don't want to push its value onto itself! Just merge the arrays.
        obj.$and.push config...
    else
      obj[key] = config
  obj
