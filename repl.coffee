Table = require 'cli-table'
repl = require "repl"
require 'colors'

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
	pp.query q, (err, rows) ->
		if err
			if err.message
				return done err.message.red
			else
				console.log err
				return done 'error'


		return done "0 rows" unless rows.length
		console.log rows
		keys = Object.keys rows[0]
		table = new Table
			head: keys

		for row in rows
			o = []
			for key in keys
				v = row[key]
				v = 'NULL'.red unless v?
				o.push v
			table.push o

			console.log o




		done table.toString()

local = repl.start
	prompt: "phoenix> "
	input: process.stdin
	output: process.stdout
	eval: evaluate

local.eval = evaluate
