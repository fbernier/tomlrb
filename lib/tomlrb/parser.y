class Tomlrb::GeneratedParser
token IDENTIFIER STRING DATETIME NUMBER TRUE FALSE
rule
  expressions
    : expressions expression
    | expression
    ;

  expression
    : table
    | assignment
    ;

  table
    : '[' identifier ']' { @handler.set_context(val[1]) }
    ;

  array
    : start_array array_continued
    ;

  array_continued : ']' { @handler.end_array }
  | value array_next;
  array_next : ']' { @handler.end_array }
  | ',' array_continued;

  start_array  : '[' { @handler.start_array }
  end_array    : ']'

  assignment
    : identifier '=' value { @handler.assign(val[0]) }
    ;

  value
    : scalar { @handler.push(val[0]) }
    | array
    ;

  scalar
    : string
    | literal
    ;

  literal
    | NUMBER { n = val[0]; result = n.count('.') > 0 ? n.to_f : n.to_i }
    | TRUE   { result = true }
    | FALSE  { result = false }
    | DATETIME
    ;

  string
    : STRING
    ;

  identifier:
    : IDENTIFIER
    ;
