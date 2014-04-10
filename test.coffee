pp = require './'
# phoenix = pp 'phoenix://localhost:1234'
phoenix = pp 'phoenix://10.11.1.132:8989'


phoenix.query "SELECT * FROM sdsd", () ->
	console.log "query result:", arguments

#
# phoenix.query "SELECT * FROM sdsd", () ->
# 	console.log arguments