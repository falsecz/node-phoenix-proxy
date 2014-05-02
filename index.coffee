reconnect = require 'reconnect-net'
{EventEmitter} = require 'events'
ByteBuffer = require 'bytebuffer'
dataConvert = require './lib/data-convert'
Bulk = require './lib/bulk'
protocol = require './lib/protocol'

RequestType = protocol.QueryRequest.Query.Type
DataType = protocol.DataType
QueryResponse = protocol.QueryResponse

class Service
	constructor: (service, impl) ->
		r = protocol.lookup service
		client = new r.clazz impl
		r.children.forEach (child) =>
			@[child.name] = (req, done) ->
				clazz = child.resolvedRequestType.clazz
				req = new clazz req if req not instanceof clazz
				client[child.name].call client, req, done


class PhoenixProxy extends Service
	constructor: (impl) ->
		super 'PhoenixProxy', impl


class Proxy extends EventEmitter
	constructor: (host, port) ->
		@_calls = {}
		@_callId = 1
		@_awaitBytes = 0
		@_connection = null
		@_buffer = new Buffer 0

		@_rc = reconnect (socket) =>
			# console.log "Connected"
			@_connection = socket
			@_rc.emit 'connected', socket

			socket.on 'data', @_processData

		@_rc.connect port, host
		@_rc.on 'disconnect', (err) =>
			if err
				err = new Error "Disconnected #{host}:#{port} #{err}"
				@.emit 'error', err

			call.callback new Error "Connection closed" for id, call of @_calls
			@_calls = {}
			@_callId = 1

		@_pp = new PhoenixProxy (method, req, done) =>
			c = @_getConnection (err, c) ->
				return done err if err

				b = req.toBuffer()

				b1 = new Buffer 4
				b1.writeInt32BE b.length, 0
				c.write b1
				c.write b


	bulk: () =>
		new Bulk @


	_completeArgs = (params, opts, done) ->
		if typeof params is 'function'
			done = params
			opts = {}
			params = []
		else if typeof opts is 'function'
			done = opts
			opts = {}
		{params, opts, done}

	query: (q, params, opts, done) =>
		{params, opts, done} = _completeArgs params, opts, done
		b = @bulk()
		b.query q, params, opts
		b.execute (err, results) ->
			done err, results?[0]

	queryOne: (q, params, opts, done) =>
		{params, opts, done} = _completeArgs params, opts, done
		@query q, params, opts, (err, rows) ->
			done err, rows?[0]

	update: (q, params, opts, done) =>
		{params, opts, done} = _completeArgs params, opts, done
		b = @bulk()
		b.update q, params, opts
		b.execute (err, results) ->
			done err, results?[0]

	_getConnection: (done) =>
		if @_rc.connected
			return done null, @_connection

		@_rc.once 'connected', () =>
			done null, @_connection


	_processData: (data) =>
		data = new Buffer(0) unless data

		@_buffer = Buffer.concat [@_buffer, data]
		return if @_awaitBytes is 0 and @_buffer.length < 4

		unless @_awaitBytes
			@_awaitBytes = @_buffer.readUInt32BE 0
			@_buffer = @_buffer.slice 4

		return if @_awaitBytes and @_awaitBytes > @_buffer.length

		@_processMessage @_buffer.slice 0, @_awaitBytes
		@_buffer = @_buffer.slice @_awaitBytes
		@_awaitBytes = 0

		@_processData() if @_buffer.length > 0


	_processMessage: (msg) =>
		o = QueryResponse.decode msg
		call = @_calls[o.call_id]

		return console.log "Call " + o.call_id unless call
		return call.callback o.exception if o.exception

		err = null
		decodeMapping = (index, value, mapping) ->
			b = value.toBuffer()
			t = mapping[index].type
			return null unless b?.length

			unless dataConvert[t]
				err = "Invalid type #{t}"
				return null

			return dataConvert[t].decode b
			value


		mappingKey = (index, mapping) ->
			mapping[index].name.toLowerCase()

		results = o.results.map (result) ->
			rows = result.rows.map (row) ->
				r = {}
				for value, idx in row.bytes
					r[mappingKey idx, result.mapping] = decodeMapping idx, value, result.mapping
				r
			rows

		call.callback err, results


	_baseQuery: (queries, opts, done) =>
		opts.timeout ?= 30000

		cid = @_callId++

		req =
			call_id: cid
			queries: []

		for query in queries
			pbParams = null
			if query.params.length
				pbParams = query.params.map (param) ->
					t = Object.keys(param)[0].toUpperCase()
					throw new Error "Invalid type #{t}" unless dataConvert[t]

					bytes = new Buffer 0
					bytes = dataConvert[t].encode param[Object.keys(param)[0]] if param[Object.keys(param)[0]]?

					type: DataType[t]
					bytes: bytes

			req.queries.push
				sql: query.sql
				type: query.type
				params: pbParams

		@_pp.query req, () ->
			console.log arguments

		@_calls[cid] = {}

		@_calls[cid].callback = (err, data) =>
			clearTimeout @_calls[cid].timeout
			delete @_calls[cid]
			# data = data[0] if data and queries.length is 1
			done.apply done, arguments

		@_calls[cid].timeout = setTimeout () =>
			delete @_calls[cid]
			done new Error "Connection timed out"
		, opts.timeout


module.exports = (url) ->
	murl = require 'url'
	{hostname, port} =  murl.parse url
	new Proxy hostname, port


