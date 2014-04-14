pp = require './'
# phoenix = pp 'phoenix://localhost:1234'
# phoenix = pp 'phoenix://10.11.1.132:8989'
# phoenix = pp 'phoenix://127.0.0.1:1234'
#phoenix = pp 'phoenix://app7.us-w2.aws.ccl:5216'
phoenix = pp 'phoenix://10.11.1.132:8989'
async = require 'async'

async.each [0..100], (i, done) ->
	console.log i
	phoenix.query "select * from gplus_posts_v1 limit 1", (err, rows) ->
		console.log "done #{i}", err if err
		return done err if err
		console.log "done #{i}", rows.length
		done()
, (err) ->
return


phoenix.update """upsert into gplus_posts_v1 (page_id, created_time, is_admin_post, sbks_type, id_crc, title) values (7, TO_DATE('2009-01-01 00:00:00'), true, 3,2, '8029s890dassws')""", (err) ->
	console.log err if err
	return if err
	d = new Date
	console.log 'c'
	phoenix.query "select * from gplus_posts_v1 LIMIT 1", (err, rows) ->
		console.log 'd'
		console.log "err", err if err
		console.log i, JSON.stringify(row) for row, i in rows
		console.log "took ", new Date - d
		process.exit 0
