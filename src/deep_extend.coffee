###
Extends two levels deep, so that we can extend query configuration objects without overwritting previous queries for the same property
# deep extend so that we can add multiple queries to any given property
# e.g. {'day': $gt: '2014-10-1'}, {day: $lt: '2014-11-1'} =>
# {'day': $gt: '2014-10-1', $lt: '2014-11-1'}
###

module.exports = (obj, obj2) ->
  for key, config of obj2
    if obj[key]? and typeof config is 'object'
      for newKey, newValue of config
        obj[key][newKey] = newValue
    else
      obj[key] = config
  obj
