reconnect = require 'reconnect-net'
ProtoBuf = require("protobufjs")
ByteBuffer = require 'protobufjs/node_modules/bytebuffer'

builder = ProtoBuf.loadProtoFile("#{__dirname}/Phoenix.proto")



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

#
# impl =
# 	(host, port) ->
#
#
		#
		# 	if state is 'connecting'
		#
		# 	socket = net.connect port, host
		# 	socket.on 'connect', () ->
		# 		console.log 'connected'
		# 		done null, socket
		#
		# 	socket.on 'error', (err) ->
		# 		console.log 'error:', host, port, err.message
		# 		state = 'closed'
		# 		socket = null
		#
		# 	socket.on 'end', (err) ->
		# 		console.log 'closed:', host, port, err.message
		# 		state = 'closed'
		# 		socket = null


		# c = net.connect '1234', () ->
		# 	c.on 'data', (data) ->
		# 		console.log "CTU:", data
		#
		#
		# 	b = req.toBuffer()
		# 	console.log "Zapisuju " +  b.length
		#
		# 	b1 = new Buffer 4
		# 	b1.writeInt32BE b.length, 0
		# 	c.write b1
		# 	c.write b
		#
			# c.write
		# console.log arguments


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
			# console.log data.toString()
			data = new Buffer(0) unless data

			buffer = Buffer.concat [buffer, data]
			# expecting Int
			return if awaitBytes is 0 and buffer.length < 4

			unless awaitBytes
				awaitBytes = buffer.readUInt32BE 0
				buffer = buffer.slice 4
				console.log "ocekavam", awaitBytes

			return if awaitBytes and awaitBytes > buffer.length

			processMessage buffer.slice 0, awaitBytes
			buffer = buffer.slice awaitBytes
			awaitBytes = 0

			processData() if buffer.length > 0



		socket.on 'data', processData

	processMessage  = (msg) ->
		o = builder.result.QueryResponse.decode msg
		console.log o.call_id
		console.log o

	rc.connect port, host
	rc.on 'disconnect', (err) ->
		return console.log 'disconnected', err.message if err
		console.log 'disconnected', err?.message
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





	query: (q, opts, done) ->
		unless done
			done = opts
			opts = {}
		opts.timeout ?= 30

		cid = callId++
		pp.query
			call_id: cid
			query: q
		, () ->
			console.log arguments

		calls[cid] = {}
		calls[cid].callback = done





module.exports = (url) ->
	murl = require 'url'
	{hostname, port} =  murl.parse url
	proxy hostname, port


