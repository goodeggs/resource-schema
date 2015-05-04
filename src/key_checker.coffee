###
Intelligently check if a reserved key (such as 'find' or 'get') is part of the
schema or part of the field definition
@param {String} key - key to check
@param {*} value - value of that key in the schema
@returns {Boolean}
###
exports.isReserved = (key, value) ->
  !!_isReserved[key]?(value)

validator =
  isFunction: (value) ->
    typeof value is 'function'
  isString: (value) ->
    typeof value is 'string'
  isBoolean: (value) ->
    typeof value is 'boolean'
  isRegExp: (value) ->
    value instanceof RegExp

_isReserved =
  'find': validator.isFunction
  'findAsync': validator.isFunction
  'get': validator.isFunction
  'set': validator.isFunction
  'filter': validator.isFunction
  'field': validator.isString
  'resolve': (value) ->
    if typeof value is 'object'
      for k, v of value
        return false if _isReserved[k]?(v)
    true
  'optional': validator.isBoolean
  'validate': validator.isFunction
  'match': validator.isRegExp
  'type': validator.isFunction
  'isArray': validator.isBoolean


