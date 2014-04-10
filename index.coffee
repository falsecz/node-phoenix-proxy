moment = require 'moment'
reconnect = require 'reconnect-net'
ProtoBuf = require("protobufjs")
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


proxy = (host, port) ->
	callId = 1
	calls = {}


	connection = null
	rc = reconnect (socket) ->
		console.log "Connected"
		connection = socket
		@emit 'connected', socket

		awaitBytes = 0
		buffer = new Buffer 0

		processData = (data) ->
			# console.log data
			data = new Buffer(0) unless data

			buffer = Buffer.concat [buffer, data]
			return if awaitBytes is 0 and buffer.length < 4

			unless awaitBytes
				awaitBytes = buffer.readUInt32BE 0
				buffer = buffer.slice 4
				# console.log "ocekavam", awaitBytes

			return if awaitBytes and awaitBytes > buffer.length

			processMessage buffer.slice 0, awaitBytes
			buffer = buffer.slice awaitBytes
			awaitBytes = 0

			processData() if buffer.length > 0



		socket.on 'data', processData

	processMessage  = (msg) ->
		# console.log msg.length, msg
		# console.log msg.toString()

		o = builder.result.QueryResponse.decode msg
		call = calls[o.call_id]
		return console.log "Call " + o.call_id unless call
		return call.callback o.exception if o.exception

		# console.log "raw", o
		decodeMapping = (index, value) ->
			type = o.mapping[index].type
			return null unless value.toBuffer().length

			if type is ColumnMapping.Type.VARCHAR
				return value.toBuffer().toString()

			if type is ColumnMapping.Type.BIGINT
				x = value.toBuffer()

				# return value.readInt64(0).toString()
				high = x.readInt32BE 4
				low = x.readInt32BE 0
				x = ByteBuffer.Long.fromBits high, low, yes
				# console.log x.toString()
				# process.exit 1
				return x.toString()

			if type is ColumnMapping.Type.BOOLEAN
				return value.toBuffer().readInt8(0) is 1

			if type is ColumnMapping.Type.TINYINT
				# return value.toBuffer()
				return value.toBuffer().readInt8(0)

			if type is ColumnMapping.Type.DATE
				# console.log value.toBuffer()
				# console.log value.readUint64(0).toString()
				# console.log value.readInt64().toString()
				x = value.toBuffer()
				# x[0] = 128
				# console.log x
				high = x.readInt32BE 4
				low = x.readInt32BE 0
				x = ByteBuffer.Long.fromBits high, low, yes
				# console.log x.toString()
				# process.exit 1
				# return x.toString()

				return moment.utc(parseInt x).toDate()
				# return value.readInt64().toString()


			if type is ColumnMapping.Type.INTEGER
				return value.toBuffer()
				return value.readUint32()

			# o.mapping[index]
			value

		mappingKey = (index) ->
			o.mapping[index].name.toLowerCase()

		rows = o.rows.map (row) ->
			r = {}
			for value, idx in row.bytes
				r[mappingKey idx] = decodeMapping idx, value
			r

		return call.callback null, rows


		# return call.callback o.exception if o.exception


	rc.connect port, host
	rc.on 'disconnect', (err) ->
		return console.log 'Disconnected', err.message if err
		console.log 'Disconnected', err?.message
		callId = 1
		for id, call of calls
			call.callback new Error "Connection closed"
		calls = {}


	getConnection = (done) ->
		if rc.connected
			return done null, connection

		rc.once 'connected', () ->
			done null, connection


	pp = new PhoenixProxy (method, req, done) ->
		c = getConnection (err, c) ->
			return done err if err

			console.log 'mam conn'



			b = req.toBuffer()
			console.log "Zapisuju " +  b.length

			b1 = new Buffer 4
			b1.writeInt32BE b.length, 0
			c.write b1
			c.write b


	baseQuery = (type, q, opts, done) ->
		unless done
			done = opts
			opts = {}
		opts.timeout ?= 30

		cid = callId++
		pp.query
			call_id: cid
			query: q
			type: type
		, () ->
			console.log arguments

		calls[cid] = {}
		calls[cid].callback = done

	query: (q, opts, done) ->
		baseQuery RequestType.QUERY, q, opts, done
	update: (q, opts, done) ->
		baseQuery RequestType.UPDATE, q, opts, done




module.exports = (url) ->
	murl = require 'url'
	{hostname, port} =  murl.parse url
	proxy hostname, port


