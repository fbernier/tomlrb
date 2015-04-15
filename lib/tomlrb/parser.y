class Tomlrb::GeneratedParser
token IDENTIFIER STRING DATETIME INTEGER FLOAT TRUE FALSE
rule
  expressions
    : expressions expression
    | expression
    ;
  expression
    : table
    | array_of_tables
    | assignment
    | inline_table
    ;
  table
    : '[' identifier ']' { @handler.set_context(val[1]) }
    ;
  inline_table
    : inline_table_start inline_continued
    ;
  inline_table_start
    : '{' { @handler.start_inline }
    ;
  inline_continued
    : '}' { @handler.end_inline }
    | inline_assignment_key inline_assignment_value inline_next
    ;
  inline_next
    : '}' { @handler.end_inline }
    | ',' inline_continued
    ;
  inline_assignment_key
    : identifier { @handler.push(val[0]) }
    ;
  inline_assignment_value
    : '=' value
    ;
  assignment
    : identifier '=' value { @handler.assign(val[0]) }
    ;
  array
    : start_array array_continued
    ;
  array_continued
    : ']' { @handler.end_array }
    | value array_next
    ;
  array_next
    : ']' { @handler.end_array }
    | ',' array_continued
    ;
  start_array
    : '[' { @handler.start_array }
    ;
  end_array
    : ']'
    ;
  array_of_tables
    : '[' '[' identifier ']' ']' { @handler.set_context(val[2], is_array_of_tables: true) }
    ;
  value
    : scalar { @handler.push(val[0]) }
    | array
    | inline_table
    ;
  scalar
    : string
    | literal
    ;
  literal
    | FLOAT { result = val[0].to_f }
    | INTEGER { result = val[0].to_i }
    | TRUE   { result = true }
    | FALSE  { result = false }
    | DATETIME { result = Time.parse(val[0]) }
    ;
  string
    : STRING
    ;
  identifier:
    : IDENTIFIER
    ;
