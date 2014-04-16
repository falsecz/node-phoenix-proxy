protocol = require './protocol'

RequestType = protocol.QueryRequest.Query.Type


module.exports = class Bulk
	constructor: (@proxy) ->
		@bulk = []


	query: (q, params, opts) ->
		@_addQuery RequestType.QUERY, q, params, opts


	update: (q, params, opts) ->
		@_addQuery RequestType.UPDATE, q, params, opts


	execute: (opts, cb) ->
		unless cb
			cb = opts
			opts = {}

		@proxy._baseQuery @bulk, opts, cb


	_addQuery: (type, q, params, opts) ->
		params ?= []
		opts ?= {}

		@bulk.push
			type: type
			sql: q
			params: params


