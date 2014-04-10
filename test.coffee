pp = require './'
# phoenix = pp 'phoenix://localhost:1234'
# phoenix = pp 'phoenix://10.11.1.132:8989'
# phoenix = pp 'phoenix://127.0.0.1:1234'
phoenix = pp 'phoenix://app7.us-w2.aws.ccl:5216'


phoenix.update """upsert into gplus_posts_v1 (page_id, created_time, is_admin_post, sbks_type, id_crc, title) values (5, TO_DATE('2009-01-01 00:00:00'), true, 3,2, '8029s890dassws')""".trim(), (err, rows) ->
	console.log arguments
	return if err
	d = new Date
	phoenix.query "select * from gplus_posts_v1", (err, rows) ->
		console.log "err", err if err
		console.log "ssss"
		console.log rows
		console.log "took ", new Date - d
		# d = new Date
		# phoenix.query "select * from gplus_posts_v1", (err, rows) ->
		# 	console.log "took ", new Date - d
		# # console.log "query result:", arguments

	#
	# phoenix.query "SELECT * FROM sdsd", () ->
	# 	console.log arguments