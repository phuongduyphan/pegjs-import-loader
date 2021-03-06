{
	const tables = [];
	const refs = [];
	const enums = [];

  // intput:
  // ` 
  //      'created'
  //                   ,            
  //         'pending',          'done'
  //  `
  //  => `'created', 'pending', 'done'`
  const removeReduntdantSpNewline = (str) => {
    const arr = str.split(/[\s\r\n]*,[\s\r\n]*/);
    // need to trim spaces and newlines of the first and last element
    const arrAfterTrim = arr.map(ele => {
      return ele.replace(/^[\s]+|[\s]+$|[\r\n]|\s(?=\s)/g, '');
    });
    return arrAfterTrim.join(', ');
  }
}

Rule = (Expr)* {
  return {tables, refs, enums};
}

Expr = 
	t:TableSyntax { tables.push(t) }
	/AlterSyntax
	/IndexSyntax
	/IgnoreSyntax
	/__
    
// 				TableSyntax: support "CREATE TABLE" syntax.
// Try to support as mush as possible syntax in MySQL offical documents.
// https://dev.mysql.com/doc/refman/8.0/en/create-table.html
// Return: table object: {name, fields, [,indexes]}
TableSyntax 
	= create_table (__ if_not_exist)? __ name:table_name _ 
    "(" _ body:TableBody _ ")" _ TableOptions? _ semicolon endline?
{
	const fields = body.fields;
	const indexes = body.indexes;
	// push inline_ref to refs
	fields.forEach((field)=>{
		(field.inline_ref || []).forEach(ref => {
			const endpoints = [
				{
					tableName: name,
					fieldName: field.name,
					relation: "*", //set by default
				},
				ref,
			]
			refs.push({endpoints});
		})
		
		// process enum: rename enum and push to array `enums`
		if (field.type.type_name.toLowerCase() === 'enum') {
			let enumValuesArr = field.type.args.split(/[\s\r\n\n]*,[\s\r\n\n]*/);
			const values = [];

			enumValuesArr.forEach(ele => {
				const newValue = ele.replace(/'|"|`/g, "").trim();
				const enumValue = {
					name: newValue
				}
				values.push(enumValue);
			});

			const _enum = {
				name: `${name}_${field.name}_enum`,
				values
			};
			enums.push(_enum);
			field.type.type_name = _enum.name;
		}

    })
    // return statement
    return indexes ? 
    	{name, fields, indexes} 
      : {name, fields}
}

// TableBody: this is the part between parenthesis.
// TableBody contains many lines, so we will classify Line and process.
// Output: covert all lines into object {fields, indexes}, which is the table body.
TableBody = _ lines:Line* _ {
	// classify lines into pk, fk, unique, index and fields
		const pks = lines.filter(l => l.type === "pk").map(l => l.pk).flat();
	const fks = lines.filter(l => l.type === "fk").map(l => l.fk).flat();
	const indexes = lines.filter(l => l.type === "index").map(l => l.index).flat();
	const fields = lines.filter(l => l.type === "field").map(l => l.field);
	const refs = [];
	// set Primary Key
	pks.forEach(key => fields.find(f => f.name === key).PK = true);
					
	// Set inline_ref for fields
	fks.map(key => {
		const field = fields.find(f => f.name === key[0].fieldName);
		if(!field.inline_ref) {
			field.inline_ref = [];
		}
		field.inline_ref.push(key[1]);
	})
	
	return {fields, indexes}
}

// Line: is create_definition in MySQL documents.
Line "fields" = pk:PKSyntax _ (comma/&")"/&(endline")")) {return { type: "pk", pk } }
	/ fk:FKSyntax _ (comma/&")"/&(endline")")) {return { type: "fk", fk } }
	/ index:IndexInLineSyntax _ (comma/&")"/&(endline")")) { return { type:"index", index }}
	/ field:Field _ (comma/&")"/&(endline")")) {return { type: "field", field } }
	/ CheckConstraintSyntax _ (comma/&")"/&(endline")"))
	/ __
    
// PKSyntax: Support "PRIMARY KEY (field[, field]*)"
// return: list of field
PKSyntax = _ primary_key _ "(" _ names:ListOfNames _ ")"
{return names}

// FKSyntax: Support "FOREIGN KEY (field[, field]*) REFERENCES `table`(field[, field]*)"
FKSyntax = _ ("CONSTRAINT"i _ name)? _ foreign_key _ 
	"(" _ fields:ListOfNames _ ")" _
	references _ table2:table_name _ "(" _ fields2:ListOfNames _ ")" _
	("ON"i _ ("DELETE"i/"UPDATE"i) _ references_options)?
{
	const arr = [];
	fields.forEach((field, index) => {
	arr.push(
		[{
			tableName: null,
			fieldName: field,
			relation: "1",
		}, {
			tableName: table2,
			fieldName: fields2[index],
			relation:"1",
		}]
	)})
  return arr
}

// UniqueSyntax: Support "UNIQUE(field[, field]*)"
UniqueSyntax 
	= _ ("CONSTRAINT"i _ name _)? "UNIQUE"i _ ("KEY"i _)? "(" name:ListOfNames ")" { return name }

// IndexInLineSyntax: Support "[UNIQUE] (INDEX/KEY) `indexName`(`field` (ASC/DESC)?)"
// "KEY is normally a synonym for INDEX".
IndexInLineSyntax = _ unique:index_in_line
	_ name:name? _ type1:index_type?
	"(" _ column:IndexInLineValues _")" IndexOption? type2:index_type?
{
	const index = { column };
	if(name) {
		index.name = name;
	}
	if(unique) {
		index.unique = true;
	}
	const type = type2 || type1;
	if(type)
		index.type = type;
	return index;
}
index_in_line // keyword
	= unique:"UNIQUE"i? _ ("INDEX"i/"KEY"i) {return unique}
	/ "UNIQUE"i _ ("INDEX"i/"KEY"i)? {return "unique"}
IndexInLineValues = first:IndexInLineValue rest:(comma _ IndexInLineValue)*
{
	return [first, ...rest.map(r => r[2])].join(",");
}
IndexInLineValue = column:type_name _ ("ASC"/"DESC")? {return column.type_name}

// Field
Field = _ name:name _ type:type _ fieldSettings:FieldSettings? _ 
{
	let field = {name, type};
	if (fieldSettings) {
		Object.assign(field, fieldSettings);
	}
	return field
}
FieldSettings = fieldSettingsArray:FieldSetting*
{
	const fieldSettings = {};
	fieldSettingsArray.forEach(field => {
		if(field === "null")
			fieldSettings["not_null"] = false;
		else if(field.type === "default")
			fieldSettings.dbdefault = field.value;
		else if(field.type === "comment")
			fieldSettings.note = field.value;
		else if (field !== "not_supported") {
			fieldSettings[field] = true;
		}
	})
	return fieldSettings;
} 
FieldSetting "field setting"
	= _ a:"NOT"i _ "NULL"i _{return "not_null"}
	/ _ a:"NULL"i _ { return "null" }
	/ _ a:primary_key _ { return "PK" }
	/ _ a:unique _ { return "unique" }
	/ _ a:"AUTO_INCREMENT"i _ { return "increment" }
	/ _ a:"UNSIGNED"i _ { return "unsigned"}
	/ _ (
      _ "COMMENT"i _ StringLiteral _ 
    / _ "COLLATE"i _ name _ 
    / _ "COLUMN_FORMAT"i _ StringLiteral _ 
    / _ "STORAGE"i _ StringLiteral _ 
    / _ "CHECK"i _ "(" expression")" _ 
    / _ "GENERATED_ALWAYS"i? _ "AS"i _ "(" expression ")"
    / _ "VIRTUAL"i _
    / _ "STORED"i 
    ) { return "not_supported" }
	/ _ v:Default {return {type: "default", value: v} }
	/ _ v:Comment { return {type: "comment", value: v }}

// Default: Support "DEFAULT (value|expr)" syntax
Default
  = "DEFAULT"i _ val: DefaultVal {return val}
DefaultVal = val:StringLiteral { return { value: val, type: 'string' }}
  / val: NumberLiteral { return { value: val, type: 'number' }}
  / val:("TRUE"i / "FALSE"i /"NULL"i) { return { value: val, type: 'boolean' }}
  / val:factor { 
    let str = val;
    if (val && val.length > 2 && val[0] === '(' && val[val.length - 1] === ')') {
      str = val.slice(1, -1);
    }
    return {
      value: str,
      type: 'expression'
    };
  }

// End of FieldSetting


// TableOptions: is a list of TableOption
TableOptions = first:TableOption _ rest:(comma? _ TableOption)*
{
	let options = first;
  rest.forEach(r => Object.assign(options, r[2]));
  return options;
}
// TableOptions: is field `table
TableOption "table option"
	= "AUTO_INCREMENT"i _ ("=" _)? auto_increment:NumberLiteral { return { auto_increment } }
	/ "AVG_ROW_LENGTH"i _ ("=" _)? avg_row_length:NumberLiteral { return { avg_row_length } }
	/ ("DEFAULT"i _)? ("CHARACTER"i _ "SET"i/"CHARSET"i) _ ("=" _)? charset_name:name { return { charset_name }}
	/ ("DEFAULT"i _)? "COLLATE"i _ ("=" _)? collation_name:name { return { collation_name }}
	/ "COMPRESSION"i _ ("=" _)? compression:('ZLIB'i/'LZ4'i/'NONE'i) { return { compression: compression.toUpperCase()}}
	/ "CONNECTION"i _ ("=" _)? connect_string:'connect_string' { return { connect_string } }
	/ "ENCRYPTION"i _ ("=" _)? encryption:('Y'i/'N'i) { return {encryption: encryption.toUpperCase()}}
	/ "ENGINE"i _ ("=" _)? engine:name { return { engine } }
	/ "INSERT_METHOD"i _ ("=" _)? insert_method:("NO"i/"FIRST"i/"LAST"i) {return {insert_method: insert_method.toUpperCase()}}
	/ "MAX_ROWS"i _ ("=" _)? max_rows:NumberLiteral { return { max_rows } }
	/ "MIN_ROWS"i _ ("=" _)? min_rows:NumberLiteral { return { min_rows } }
	/ "TABLESPACE"i tablespace:name ("STORAGE" _ ("DISK"i/"MEMORY"i))? { return { tablespace } }
	/ comment: Comment { return { comment } }

// CheckConstraintSyntax: Support "[CONSTRAINT [symbol]] CHECK (expr) [[NOT] ENFORCED]"
// We do not process this syntax.
CheckConstraintSyntax = _ ("CONSTRAINT"i name _)? "CHECK"i _ expression _ ("NOT"i? _ "ENFORCE"i)?
// 			End of TableSyntax

// 			AlterSyntax: support "ALTER TABLE" syntax
// We will support ADD_COLUMN, ADD_FOREIGN_KEY, ADD_INDEX
// https://dev.mysql.com/doc/refman/8.0/en/alter-table.html
AlterSyntax = alter_table _ table:name _ 
	options:(AddOptions/ChangeOptions/DropOptions) _
  semicolon
{
	const fks = options.filter(o => o.type === "add_fk").map(o => o.fks).flat();
	fks.forEach(fk => {fk[0].tableName = table});
	const endpoints = fks.map(fk => ({endpoints: [...fk]}))
	refs.push(...endpoints)
}

AddOptions = "ADD"i _ 
	( ("CONSTRAINT"i __ name)? _ fks:FKSyntax { return {type:"add_fk", fks} }
	/ ("COLUMN"i)? _ col_name:name _ col_type:type { return {type:"add_column", field:{col_name, col_type}}}
	/ ("INDEX"i/"KEY"i) _ index_name:name _ column:IndexColumn { return { type: "add_index", index: {column} } }
	/ ("CONSTRAINT"i __ name)? "UNIQUE"i ("INDEX"i/"KEY"i)
	)

ChangeOptions = "CHANGE"i [^;]

DropOptions = "DROP"i [^;]
// 			End of AlterSyntax

// 			IndexSyntax: support "CREATE INDEX" syntax
IndexSyntax = constraint:create_index _ indexName:name _
	"ON"i _ tableName:name _ indexType:index_type? _
	column: IndexColumn _
	option:IndexOption? semicolon
{
	const index = {column};
	const typeInOption = option && option.type === "index_type" ? option.value : null;
    
	if(indexName)
		index.name = indexName;
	
	if(constraint.toLowerCase() === "unique")
		index.unique = true;

	const type = typeInOption || indexType;
	if(type) 
		index.type = type;

	const table = tables.find(table => table.name === tableName);
	if(table.indexes) {
		table.indexes.push(index);
	} else {
		table.indexes = [index];
	}
}

IndexColumn
	= "(" _ e:expression _ ")" {return e}
IndexColumnValue 
	= name:name {return `\`${name}\``}
  / expression
IndexOption
  = "KEY_BLOCK_SIZE"i _ ("=" _)? type
	/ "WITH"i _ "PARSER"i _ parser_name:name
	/ "COMMENT"i _ "string"
	/ ("VISIBLE"i / "INVISIBLE"i)
	/ type: index_type { return { type: "index_type", value: type } }
// 			End of IndexSyntax


// 			IgnoreSyntax: these are syntax that dbdiagram does not to process
IgnoreSyntax 
	= (InsertSyntax
	/ SetSyntax
	/ CreateSchemaSyntax
	/ DropSyntax
	/ UseSyntax
	/ BeginSyntax
	/ CommitSyntax
	/ RollbackSyntax
	) semicolon newline?

// InsertSyntax: "INSERTO INTO" syntax
InsertSyntax = _ "INSERT"i (!(")" _ ";") .)* ")"

// SetSyntax: "SET" syntax
SetSyntax = _ "SET"i [^;]*

// CreateSchemaSyntax: "CREATE SCHEMA" syntax
CreateSchemaSyntax = _ "CREATE"i _ ("SCHEMA"i/"DATABASE"i) [^;]*

// DropSyntax: "DROP" syntax
DropSyntax = _ "DROP"i [^;]*

// UseSyntax: "USE" syntax
UseSyntax = _ "USE"i [^;]*

// BeginSyntax: "BEGIN TRANSACTION" syntax
BeginSyntax = _ "BEGIN"i [^;]*

// CommitSyntax: "COMMIT" syntax
CommitSyntax = _ "COMMIT"i [^;]*

// RollbackSyntax: "ROLLBACK" syntax
RollbackSyntax = _ "ROLLBACK"i [^;]*
// 			End of IgnoreSyntax


//			Useful Expression
// ListOfNames: support list of names in PK, FK and Unique
// Ex: Unique(`abc`, `def`)
// Output: ["abc", "def"]
ListOfNames = first:name rest:(comma _ name)*
{return [first, ...rest.map(n => n[2])]}

// Comment Syntax: Support "COMMENT 'this is a comment'"
Comment 
	= "COMMENT" _ ("=" _)? comment: "'" c:[^']* "'" {return c.join('')}
	/ "COMMENT" _ ("=" _)? comment: "\"" c:[^"]* "\"" {return c.join('')}
// 			End of Useful Expression

@import '././keywords.pegjs'
@import '.././././mysql-test1/.././mysql-test1/./expression.pegjs'
@import 'base-rules.pegjs'