// just a comment
// many comments
// abc
{
  // base_rules
  const test3 = 'test1';
  const test4 = 'expr';
}

character "letter, number or underscore" = [a-z0-9_]i
sp = " "
quote = "`"/"\""
comma = ","
tab = "\t"
semicolon = ";"
endline "endline" = sp* newline
newline "newline" = "\r\n" / "\n"
// Ignored
_ "space" = (comment/sp/tab/newline)*
__ "space" = (comment/sp/tab/newline)+
comment "comment" = "--" [^\n]* / "/*" (!"*/" .)* "*/" semicolon?
// Copied from https://github.com/pegjs/pegjs/issues/292
StringLiteral "string"
  = '"' chars:DoubleStringCharacter* '"' {
      return chars.join('') ;
    }
  / "'" chars:SingleStringCharacter* "'" {
      return chars.join('') ;
    }
DoubleStringCharacter
  = '\\' '"' { return '"'; }
  / !'"' SourceCharacter { return text(); }
SingleStringCharacter
  = '\\' "'" { return "'"; }
  / !"'" SourceCharacter { return text(); }
SourceCharacter
  = .
NumberLiteral
	= float
	/ integer
float 
  = left:[0-9]+ "." right:[0-9]+ { return parseFloat(left.join("") + "." +   right.join("")); }
integer 
	= digits:[0-9]+ { return parseInt(digits.join(""), 10); }