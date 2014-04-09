net = require 'net'
ProtoBuf = require("protobufjs")
ByteBuffer = require 'protobufjs/node_modules/bytebuffer'

builder = ProtoBuf.loadProtoFile("#{__dirname}/Phoenix.proto")
# consol	e.log builder



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

impl = (method, req, done) ->
	c = net.connect '1234', () ->
		c.on 'data', (data) ->
			console.log "CTU:", data


		b = req.toBuffer()
		console.log "Zapisuju " +  b.length

		b1 = new Buffer 4
		b1.writeInt32BE b.length, 0
		c.write b1
		c.write b

		# c.write
	# console.log arguments

pp = new PhoenixProxy impl

pp.query
	call_id: 1
	query: "SELECT * FROM a"
, () ->
	console.log arguments