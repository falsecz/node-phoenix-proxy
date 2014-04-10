cliTable = require 'cli-table'
repl = require "repl"

c = process.argv[2]
return console.log "Missing host:port" unless c

proxy = require './'

console.log "Connecting #{c}"
pp = proxy "phoenix://#{c}"

evaluate = (cmd, context, filename, callback) ->

	command = cmd.substr 1, cmd.length - 2
	callback null if command.length < 2

	sendQuery command, callback

sendQuery = (q, done) ->
	pp.query q, () ->
		console.log arguments
		done()

local = repl.start
  prompt: "phoenix> "
  input: process.stdin
  output: process.stdout
	eval: evaluate

local.eval = evaluate
