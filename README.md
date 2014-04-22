node-phoenix-proxy
==================

# Create connection:
```cs
pp = require "node-phoenix-proxy"
phoenix = pp "phoenix://10.11.1.101:9898"

phoenix.on "error", (err) ->
	console.log err.message
```


# Create table:
```cs
query = """
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
phoenix.update query, (err, result) ->
	console.log arguments
```


# Insert new row:
```cs
query = """
	upsert into phoenix_type_test (c1, c2, c3, c4, c5, c6, c7, c8, c10, c11, c12, c13, c14, c15, c16) values
		(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)

params = [
	{integer: 1}
	{varchar: "foo"}
	{binary: new Buffer "bar"}
	{double: 1.1}
	{float: 1.1}
	{bigint: 1}
	{boolean: yes}
	{timestamp: new Date}
	{date: new Date}
	{tinyint: 1}
	{smallint: 1}
	{decimal: 1.1}
	{time: new Date}
	{char: "foo"}
	{varbinary: new Buffer "bar"}
]
"""
phoenix.update query, params, (err, rows) ->
	console.log arguments
```


# Select data:
```cs
phoenix.queryOne "select * from phoenix_type_test where c1 = ?", [integer: 1], () ->
	console.log arguments
```


# Bulk request:
```cs
bulk = phoenix.bulk()
bulk.query "select * from phoenix_type_test where c1 = ?", [integer: 1]
bulk.query "select c1, c2 from phoenix_type_test where c2 = ?", [varchar: "foo"]
bulk.query "select c1, c7 from phoenix_type_test where c7 = ?", [boolean: yes]
bulk.execute (err, rows) ->
	console.log arguments
```

# Known problems:
	- Char doesn't behave like binary does (binary adds x20 to the full length, char doesn't and behavea mores like varchar). So be careful with your where condition on those two types.


