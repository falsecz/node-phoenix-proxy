moment = require 'moment'
reconnect = require 'reconnect-net'
ProtoBuf = require("protobufjs")
{EventEmitter} = require 'events'
ByteBuffer = require 'protobufjs/node_modules/bytebuffer'

builder = ProtoBuf.loadProtoFile("#{__dirname}/Phoenix.proto")

ColumnMapping = builder.result.ColumnMapping
RequestType = builder.result.QueryRequest.Type
# console.log ColumnMapping
class Service
	constructor: (service, impl) ->
		r = builder.lookup service
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
			return console.log 'Disconnected', err.message if err
			console.log 'Disconnected'

			for id, call of @_calls
				call.callback new Error "Connection closed"

			@_calls = {}
			@_callId = 1

		@_pp = new PhoenixProxy (method, req, done) =>
			c = @_getConnection (err, c) ->
				return done err if err

				#console.log 'mam conn'
				b = req.toBuffer()
				#console.log "Zapisuju " +  b.length

				b1 = new Buffer 4
				b1.writeInt32BE b.length, 0
				c.write b1
				c.write b


	query: (q, opts, done) =>
		@_baseQuery RequestType.QUERY, q, opts, done


	update: (q, opts, done) =>
		@_baseQuery RequestType.UPDATE, q, opts, done


	_getConnection: (done) =>
		if @_rc.connected
			return done null, @_connection

		@_rc.once 'connected', () =>
			done null, @_connection


	_processData: (data) =>
		#console.log data
		data = new Buffer(0) unless data

		@_buffer = Buffer.concat [@_buffer, data]
		return if @_awaitBytes is 0 and @_buffer.length < 4

		unless @_awaitBytes
			@_awaitBytes = @_buffer.readUInt32BE 0
			@_buffer = @_buffer.slice 4
			#console.log "ocekavam", @_awaitBytes

		return if @_awaitBytes and @_awaitBytes > @_buffer.length

		@_processMessage @_buffer.slice 0, @_awaitBytes
		@_buffer = @_buffer.slice @_awaitBytes
		@_awaitBytes = 0

		@_processData() if @_buffer.length > 0


	_processMessage: (msg) =>
		# console.log msg.length, msg
		# console.log msg.toString()

		o = builder.result.QueryResponse.decode msg
		call = @_calls[o.call_id]

		return console.log "Call " + o.call_id unless call
		return call.callback o.exception if o.exception

		decodeMapping = (index, value) ->
			b = value.toBuffer()
			type = o.mapping[index].type
			return null unless b.length

			if type is ColumnMapping.Type.INTEGER
				return b.readInt32BE(0)

			if type is ColumnMapping.Type.VARCHAR
				return b.toString()

			if type is ColumnMapping.Type.BINARY
				return b

			if type is ColumnMapping.Type.DOUBLE
				x = ByteBuffer.wrap(b).readDouble 0
				return x.toString()

			if type is ColumnMapping.Type.FLOAT
				x = ByteBuffer.wrap(b).readFloat 0
				return x.toString()

			if type is ColumnMapping.Type.BIGINT
				x = b

				high = x.readInt32BE 4
				low = x.readInt32BE 0
				x = ByteBuffer.Long.fromBits high, low, yes
				return x.toString()

			if type is ColumnMapping.Type.BOOLEAN
				return b.readInt8(0) is 1

			if type is ColumnMapping.Type.TIMESTAMP
				x = b
				high = x.readInt32BE 4
				low = x.readInt32BE 0
				x = ByteBuffer.Long.fromBits high, low, yes

				return moment.utc(parseInt x).toDate()

			if type is ColumnMapping.Type.DATE
				x = b
				high = x.readInt32BE 4
				low = x.readInt32BE 0
				x = ByteBuffer.Long.fromBits high, low, yes

				return moment.utc(parseInt x)

			if type is ColumnMapping.Type.TINYINT
				return b.readInt8(0)

			if type is ColumnMapping.Type.SMALLINT
				return b.readInt16BE(0)

			if type is ColumnMapping.Type.DECIMAL
				x = ByteBuffer.wrap(b).readDouble 0
				return x.toString()

			if type is ColumnMapping.Type.TIME
				x = b
				high = x.readInt32BE 4
				low = x.readInt32BE 0
				x = ByteBuffer.Long.fromBits high, low, yes

				return moment.utc(parseInt x).format('HH:mm:ss')

			if type is ColumnMapping.Type.CHAR
				return b.toString()

			if type is ColumnMapping.Type.VARBINARY
				return b

			value

		mappingKey = (index) ->
			o.mapping[index].name.toLowerCase()

		rows = o.rows.map (row) ->
			r = {}
			for value, idx in row.bytes
				r[mappingKey idx] = decodeMapping idx, value
			r

		call.callback null, rows


	_baseQuery: (type, q, opts, done) =>
		unless done
			done = opts
			opts = {}

		opts.timeout ?= 30000

		cid = @_callId++
		@_pp.query
			call_id: cid
			query: q
			type: type
		, () ->
			console.log arguments

		@_calls[cid] = {}

		@_calls[cid].callback = () =>
			clearTimeout @_calls[cid].timeout
			delete @_calls[cid]
			done.apply done, arguments

		@_calls[cid].timeout = setTimeout () =>
			delete @_calls[cid]
			done new Error "Connection timed out"
		, opts.timeout


module.exports = (url) ->
	murl = require 'url'
	{hostname, port} =  murl.parse url
	new Proxy hostname, port


