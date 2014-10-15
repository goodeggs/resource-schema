#!/usr/bin/env node
// var debug = require('debug')('angular-architecture-demo');
require('coffee-script/register');
var app = require('../fixtures/app.coffee');

app.set('port', 4000);

var server = app.listen(app.get('port'), function() {
  console.log('Express server listening on port ' + server.address().port);
  debug('Express server listening on port ' + server.address().port);
});
