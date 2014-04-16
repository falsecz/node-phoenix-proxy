ProtoBuf = require("protobufjs")
builder = ProtoBuf.loadProtoFile("#{__dirname}/../Phoenix.proto")
module.exports = builder.build()
module.exports.lookup = builder.lookup.bind builder