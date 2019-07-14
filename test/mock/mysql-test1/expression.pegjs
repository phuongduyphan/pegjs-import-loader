{
  // expr
  const test1 = 'test1';
  const test2 = 'expr';
}

expression "expression" = factors:factor* {
	return removeReduntdantSpNewline(factors.flat(10).join(""));
}
factor = factors:(character+ _ "(" expression ")"
    / "(" expression ")"
    / (exprCharNoCommaSpace+ &(_/","/");"/endline");")) / exprChar+ &.) {
    	return factors.flat(10).join("");
    }   
exprChar = [\',.a-z0-9_+-\`]i
    / sp
    / newline
    / tab
exprCharNoCommaSpace = [\'.a-z0-9_+-]i

@import '../mysql/base-rules.pegjs'