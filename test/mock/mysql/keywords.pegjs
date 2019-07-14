// just a comment
{
  // keyword
  const test5 = 'test1';
  const test6 = 'expr';
}

// 			Keywords:
create_table "CREATE TABLE" = "CREATE"i _ "TEMPORARY"i? _"TABLE"i
if_not_exist "IF NOT EXISTS" = "IF"i _ "NOT"i _ "EXISTS"i
alter_table "ALTER TABLE" = "ALTER"i _ "TABLE"i
create_index "CREATE INDEX" 
	= "CREATE"i _ type:name _ "INDEX"i {return type}
  / "CREATE"i _ "INDEX"i {return 'INDEX'}
primary_key = "PRIMARY"i _ "KEY"i
foreign_key = "FOREIGN"i _ "KEY"i
references = "REFERENCES"i
unique = "UNIQUE"i
references_options = "RESTRICT"i/"CASCADE"i/"SET"i _ "NULL"i/"NO"i _ "ACTION"i/"SET"i _ "DEFAULT"i
index_type "index type" = "USING"i _ type:("BTREE"i/"HASH"i) { return type.toUpperCase() }
name "valid name"
  = c:(character)+ { return c.join("") }
  / quote c:[^`]+ quote { return c.join("") }
table_name "valid table name"
  = (name _ "." _)* name:name { return name }
type "type" = c:type_name { return c }
	/  c:name { return { type_name: c } }
type_name = type_name:name _ args:("(" _ expression _ ")")? {
  args = args ? args[2] : null;

	if (type_name.toLowerCase() !== 'enum') {
		type_name = args ? type_name + '(' + args + ')' : type_name;
	}
	
	return {
		type_name,
		args
	}
}

@import './base-rules.pegjs';
@import '../mysql-test1/expression.pegjs'