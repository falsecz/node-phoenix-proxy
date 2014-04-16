pp = require './'
#phoenix = pp 'phoenix://app7.us-w2.aws.ccl:5216'
#phoenix = pp 'phoenix://10.11.1.132:8989'
phoenix = pp 'phoenix://10.11.1.101:9898'
async = require 'async'
phoenix.on 'error', (err) ->
	console.log err.message

phoenix.query "select c1, c15 from phoenix_type_test where c1 = ?", [integer: 1], () ->
	console.log arguments

return

###
# char doesn't behave like binary does (binary adds x20 to the full length, char doesn't)
###

b = phoenix.bulk()
b.query "select c1, c15 from phoenix_type_test where c1 = ?", [integer: 1]
b.query "select c1, c15 from phoenix_type_test where c1 = ?", [integer: 2]
b.query "select c1, c15 from phoenix_type_test where c15 = ?", [char: 'c']
b.execute (err, rows) ->
	console.log rows
	process.exit 0
return


async.each [0..5], (i, done) ->
	console.log i
	phoenix.query "select * from phoenix_type_test", (err, rows) ->
		console.log "done #{i}", err if err
		return done err if err
		console.log "done #{i}", rows.length
		done()
, (err) ->
	console.log err
	process.exit 0
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



###
q = """
CREATE TABLE phoenix_type_test(
	c1 INTEGER not null,
	c2 VARCHAR,
	c3 BINARY(10),
	c4 DOUBLE,
	c5 FLOAT,
	c6 BIGINT,
	c7 BOOLEAN,
	c8 TIMESTAMP,
	c10 DATE,
	c11 TINYINT,
	c12 SMALLINT,
	c13 DECIMAL,
	c14 TIME,
	c15 CHAR(5),
	c16 VARBINARY,
CONSTRAINT PK PRIMARY KEY (c1))
"""
phoenix.update q, (err, rows) ->
	console.log arguments
	process.exit 0
return

q = """
upsert into phoenix_type_test (c1, c2, c3, c4, c5, c6,c7, c8, c10, c11, c12, c13, c14, c15, c16) values (
	1,
	'varchar',
	HEX_TO_BYTES('12'),
	1.1,
	1.2,
	2,
	true,
	TO_DATE('2014-04-10 11:11:11'),
	TO_DATE('2014-04-11', 'yyyy-MM-dd'),
	3,
	4,
	12345.67,
	TO_DATE('10:10:10', 'HH:mm:ss'),
	'char',
	HEX_TO_BYTES('00')
)
"""
phoenix.update q, (err, rows) ->
	console.log arguments
	process.exit 0
return
###


